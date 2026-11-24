#include "65816_engine.h"

// forward declarations for opcode handler functions
static void inval_op(int amod);
static void opc_asl(int amod);
static void opc_rol(int amod);
static void opc_ror(int amod);
static void opc_lsr(int amod);
static void opc_sta(int amod);
static void opc_stxy(int amod);
static void opc_lda(int amod);
static void opc_ldxy(int amod);
static void opc_rep(int amod);
static void opc_nop(int amod);
static void opc_stp(int amod);
static void opc_sep(int amod);
static void opc_xce(int amod);
static void opc_bxx(int amod);
static void opc_incdec(int amod);
static void opc_inxydexy(int amod);
static void opc_xfer(int amod);
static void opc_logic(int amod);
static void opc_pea(int amod);
static void opc_pei(int amod);
static void opc_push(int amod);
static void opc_pop(int amod);
static void opc_jmpjsr(int amod);
static void opc_return(int amod);
static void opc_adcsbccmp(int amod);
static void opc_bit(int amod);
static void opc_trbtsb(int amod);
static void opc_wdm(int amod);
static void opc_flagop(int amod);
static void opc_wai(int amod);
static void opc_brlper(int amod);

// declarations for opcode table
typedef void (*ptr_to_opc)(int amod); // typedef for opcode pointers
static ptr_to_opc opc[256] = { NULL }; // opcode function pointer table
static int opcamod[256]; // address modes

// registers
union reg {
	unsigned short x;
	struct {
		unsigned char l;
		unsigned char h;
	};
};

static union reg a,x,y,s,d,pc; // A, X, Y, Stack, Direct
static unsigned char p,b,k; // PSR, Data Bank, Program Bank
static unsigned char e; // emulation mode "hidden bit"
static union reg work; // internal work register
static unsigned char wb_b; // writeback bank (fetch/writeback)
static union reg wb_a; // writeback address (fetch/writeback)
static unsigned char im_b; // intermediate bank
static union reg im_a; // intermediate address

// long address calculation
union longaddr {
	unsigned int xx;
	struct {
		unsigned short xl;
		unsigned short xh;
	};
	struct {
		unsigned char l;
		unsigned char h;
		unsigned char xhl;
		unsigned char xhh;
	};
};

static union longaddr la,savela; // for long address calculation
static int boundcross; // flag for page boundary crossings

// utility
static unsigned char traceflag = 0; // trace mode
static unsigned char opcload; // currently executing instruction
static unsigned char *mem = 0;
static long engine_65816_cycles; // clock cycle counter
static int engine_65816_halt; // halts execution when = 1; STP instruction sets this


static unsigned char rmem(unsigned char bank, unsigned short address)
{
	return mem_driver_read((bank * 65536) + address);
}

static void wmem(unsigned char bank, unsigned short address, unsigned char value)
{
	if (traceflag)
		printf("W%02X/%04X=%02X ",bank,address,value);

	mem_driver_write((bank * 65536) + address, value);
}

static int noread = 0; // set while fetching for instructions that only write/jump (no data read)

static unsigned char drmem(unsigned char bank, unsigned short address)
{
	// data read for operand fetch; skipped for stores/jumps to avoid I/O read side effects
	if (noread)
		return 0;
	return rmem(bank,address);
}

// e=1 and DL=0: direct page addressing wraps within the page
static int dpwrap(void)
{
	return (e==1) && (d.l==0);
}

static void inc_pc(int howmuch)
{
	pc.x+=howmuch;
	pc.x%=0x10000;
}

static void writeback(int amod,int size) // write back work register to wb_b/wb_a.x
{
	wmem(wb_b,wb_a.x,work.l);
	if (size==16)
	{
		wb_a.x++;
		switch(amod)
		{
			case ABSOLUTE:
			case ABSOLUTELONG:
			case ABSOLUTEINDEXEDX:
			case ABSOLUTEINDEXEDY:
			case ABSOLUTELONGINDEXEDX:
			case DIRECTINDIRECT:
			case DIRECTINDIRECTLONG:
			case DIRECTINDIRECTINDEXEDY:
			case DIRECTINDIRECTLONGINDEXEDY:
			case DIRECTINDEXEDINDIRECTX:
			case STACKINDIRECTINDEXEDY:
				if (wb_a.x == 0)
					wb_b++; // all of these wrap around banks
				break;
			default:
				break; // everything else stays on the same bank
		}
		wmem(wb_b,wb_a.x,work.h);
	}
}

static void fetch(int amod,int size)
{
	switch(amod) {
		case IMMEDIATE: // #imm
			work.l = rmem(k,pc.x);
			inc_pc(1);
			if (size==16)
			{
				work.h = rmem(k,pc.x);
				inc_pc(1);
			}
			break;
		case ABSOLUTE: // abs
		case ABSOLUTELONG: // abslong
		case ABSOLUTEINDEXEDX: // abs,X
		case ABSOLUTEINDEXEDY: // abs,Y
		case ABSOLUTELONGINDEXEDX: // abslong,X
			wb_a.l = rmem(k,pc.x);
			inc_pc(1);
			wb_a.h = rmem(k,pc.x);
			inc_pc(1);
			if ((amod==ABSOLUTE) || (amod==ABSOLUTEINDEXEDX) || (amod==ABSOLUTEINDEXEDY))
				wb_b = b; // absolute takes the DBR
			if ((amod==ABSOLUTELONG) || (amod==ABSOLUTELONGINDEXEDX))
			{
				wb_b = rmem(k,pc.x);
				inc_pc(1);
			}
			if ((amod==ABSOLUTEINDEXEDX) || (amod==ABSOLUTEINDEXEDY) || (amod==ABSOLUTELONGINDEXEDX))
			{
				la.xhh = 0; // highest byte is always 0 (keep it < 16mb)
				la.xhl = wb_b; // our bank
				la.xl = wb_a.x; // our address
				savela.xx = la.xx; // save our original address
				if (amod==ABSOLUTEINDEXEDY)
					im_a.x = y.x; // get offset from Y
				else
					im_a.x = x.x; // or just X
				if ((e==1) || ((e==0) && ((p & 0x10) == 0x10))) // if 8-bit indexes, then..
					im_a.h = 0; // zero the high byte of our offset
				la.xx += im_a.x; // add our offset, rolling over banks if necessary
				la.xx &= 0x00ffffff; // if we rolled over $ff/ffff then mask off the excess
				wb_b = la.xhl; // put our computed address back in the writeback
				wb_a.x = la.xl;
				if ((savela.xx & 0x00ffff00) != (la.xx & 0x00ffff00))
					boundcross = 1; // if the bank/page doesn't match, a page boundary was crossed
				else
					boundcross = 0;
			}
			work.l = drmem(wb_b,wb_a.x);
			if (size==16)
			{
				im_b = wb_b; // don't destroy the writeback address
				im_a.x = wb_a.x;
				im_a.x++;
				if (im_a.x == 0)
					im_b++; // wrap around to next bank if wb_a is $FFFF
				work.h = drmem(im_b,im_a.x);
			}
			else
				work.h = 0;
			break;
		case DIRECT: // dp
		case DIRECTINDEXEDX: // dp,X
		case DIRECTINDEXEDY: // dp,Y
			wb_b = 0; // direct page is always in bank 0
			wb_a.h = 0;
			wb_a.l = rmem(k,pc.x);
			inc_pc(1);
			wb_a.x += d.x; // D applies in emulation mode too
			if ((amod == DIRECTINDEXEDX) || (amod == DIRECTINDEXEDY))
			{
				if (amod == DIRECTINDEXEDX)
					im_a.x = x.x; // DIRECTINDEXEDX
				else
					im_a.x = y.x; // DIRECTINDEXEDY
				if (dpwrap())
					wb_a.l += im_a.l; // e=1 and DL=0: 8-bit offset wraps within the page
				else if ((e==1) || ((p & 0x10) == 0x10))
					wb_a.x += im_a.l; // 8-bit index, spans pages
				else
					wb_a.x += im_a.x; // 16 bit index, wraps within bank 0
			}
			work.l = drmem(0,wb_a.x);
			if (size==16)
				work.h = drmem(0,wb_a.x + 1); // will wrap to 00/0000 because the argument is a short
			else
				work.h = 0;
			break;
		case DIRECTINDEXEDINDIRECTX: // (dp,X)
			// get location of address on direct page
			im_b = 0; // direct page is always in bank 0
			im_a.h = 0;
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			im_a.x += d.x;
			if (dpwrap())
				im_a.l += x.l; // e=1 and DL=0: wrap within the page
			else if (e==1)
				im_a.x += x.l;
			else
				im_a.x += x.x; // add X to get location of address
			wb_a.l = rmem(0,im_a.x); // get low byte of address
			if (dpwrap())
				im_a.l++; // wrap to beginning of page
			else
				im_a.x++;
			wb_a.h = rmem(0,im_a.x); // get high byte of address
			wb_b = b; // assume DBR
			work.l = drmem(wb_b,wb_a.x); // get byte at address
			if (size == 16)
			{
				im_b = wb_b; // don't destroy the writeback address
				im_a.x = wb_a.x;
				im_a.x++;
				if (im_a.x == 0)
					im_b++; // wrap around to next bank if wb_a is $FFFF
				work.h = drmem(im_b,im_a.x);
			}
			else
				work.h = 0;
			break;
		case DIRECTINDIRECT: // (dp)
		case DIRECTINDIRECTLONG: // [dp]
		case DIRECTINDIRECTINDEXEDY: // (dp),Y
		case DIRECTINDIRECTLONGINDEXEDY: // [dp],Y
			// get location of address on direct page
			im_b = 0; // direct page is always in bank 0
			im_a.h = 0;
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			im_a.x += d.x;
			wb_a.l = rmem(0,im_a.x); // get low byte of address
			if (dpwrap())
				im_a.l++; // e=1 and DL=0: wrap to beginning of page
			else
				im_a.x++;
			wb_a.h = rmem(0,im_a.x); // get high byte of address
			if ((amod == DIRECTINDIRECT) || (amod == DIRECTINDIRECTINDEXEDY))
			{
				wb_b = b; // assume DBR for DIRECTINDIRECT and DIRECTINDIRECTINDEXEDY
			}
			else
			{
				if (dpwrap())
					im_a.l++;
				else
					im_a.x++;
				wb_b = rmem(0,im_a.x); // get third byte of address for DIRECTINDIRECTLONG and DIRECTINDIRECTLONGINDEXEDY
			}
			if ((amod == DIRECTINDIRECTINDEXEDY) || (amod == DIRECTINDIRECTLONGINDEXEDY))
			{
				la.xhh = 0; // highest byte is always 0 (keep it < 16mb)
				la.xhl = wb_b; // our bank
				la.xl = wb_a.x; // our address
				savela.xx = la.xx; // save our original address
				im_a.x = y.x; // get offset from Y
				if ((e==1) || ((e==0) && ((p & 0x10) == 0x10))) // if 8-bit indexes, then..
					im_a.h = 0; // zero the high byte of our offset
				la.xx += im_a.x; // add our offset, rolling over banks if necessary
				la.xx &= 0x00ffffff; // if we rolled over $ff/ffff then mask off the excess
				wb_b = la.xhl; // put our computed address back in the writeback
				wb_a.x = la.xl;
				if ((savela.xx & 0x00ffff00) != (la.xx & 0x00ffff00))
					boundcross = 1; // if the bank/page doesn't match, a page boundary was crossed
				else
					boundcross = 0;
			}
			work.l = drmem(wb_b,wb_a.x);
			if (size == 16)
			{
				im_b = wb_b; // don't destroy the writeback address
				im_a.x = wb_a.x;
				im_a.x++;
				if (im_a.x == 0)
					im_b++; // wrap around to next bank if wb_a is $FFFF
				work.h = drmem(im_b,im_a.x);
			}
			else
				work.h = 0;
			break;
		case STACKRELATIVE: // (sr,S)
		case STACKINDIRECTINDEXEDY: // (sr,S),Y
			// get location on stack
			im_b = 0; // stack is always in bank 0
			im_a.l = rmem(k,pc.x); // get sr offset byte
			im_a.h = 0;
			im_a.x += s.x; // add our sr value (high byte zero) to the stack pointer
			inc_pc(1);
			if (amod == STACKRELATIVE)
			{
				wb_b = 0;
				wb_a.x = im_a.x; // set our writeback to the low byte on stack
				work.l = drmem(wb_b,wb_a.x); // get the byte off the stack
				if (size == 16)
					work.h = drmem(wb_b,wb_a.x + 1); // don't wrap banks
				else
					work.h = 0;
			}
			else // STACKINDIRECTINDEXEDY
			{
				wb_b = b; // assume DBR
				wb_a.l = rmem(im_b,im_a.x); // get low byte of address off stack
				wb_a.h = rmem(im_b,im_a.x + 1); // get high byte, crossing pages but not banks
				la.xhh = 0; // highest byte is always 0 (keep it < 16mb)
				la.xhl = wb_b; // our bank
				la.xl = wb_a.x; // our address
				savela.xx = la.xx; // save our original address
				im_a.x = y.x; // get offset from Y
				if ((e==1) || ((e==0) && ((p & 0x10) == 0x10))) // if 8-bit indexes, then..
					im_a.h = 0; // zero the high byte of our offset
				la.xx += im_a.x; // add our offset, rolling over banks if necessary
				la.xx &= 0x00ffffff; // if we rolled over $ff/ffff then mask off the excess
				wb_b = la.xhl; // put our computed address back in the writeback
				wb_a.x = la.xl;
				if ((savela.xx & 0x00ffff00) != (la.xx & 0x00ffff00))
					boundcross = 1; // if the bank/page doesn't match, a page boundary was crossed
				else
					boundcross = 0;
				work.l = drmem(wb_b,wb_a.x);
				if (size == 16)
				{
					im_b = wb_b; // don't destroy the writeback address
					im_a.x = wb_a.x;
					im_a.x++;
					if (im_a.x == 0)
						im_b++; // wrap around to next bank if wb_a is $FFFF
					work.h = drmem(im_b,im_a.x);
				}
				else
					work.h = 0;
			}
			break;
		case ABSOLUTEINDIRECT:
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			im_a.h = rmem(k,pc.x);
			inc_pc(1);
			wb_a.l = rmem(0,im_a.x);
			wb_a.h = rmem(0,im_a.x + 1);
			wb_b = k; // 16-bit pointer is in bank 0; address it jumps to is located in current program bank
			break;
		case ABSOLUTEINDEXEDINDIRECT:
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			im_a.h = rmem(k,pc.x);
			inc_pc(1);
			if (size == 8) // bump the address by X
				im_a.x += x.l;
			else
				im_a.x += x.x;
			wb_a.l = rmem(k,im_a.x);
			wb_a.h = rmem(k,im_a.x + 1);
			wb_b = k;
			break;
		case ABSOLUTEINDIRECTLONG:
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			im_a.h = rmem(k,pc.x);
			inc_pc(1);
			wb_a.l = rmem(0,im_a.x); // the pointer lives in bank 0
			wb_a.h = rmem(0,im_a.x + 1);
			wb_b = rmem(0,im_a.x + 2);
			break;
		default:
			printf("fatal: undefined addressing mode %d in fetch.\n",amod);
			exit(1);
			break;
	}
}

static void initops(void)
{
	int i;

	// assign all members of the table to inval_op by default
	// and give them an IMPLIED addressing mode
	for (i=0; i<=255; i++)
	{
		opc[i] = &inval_op;
		opcamod[i] = IMPLIED;
	}

	// opcodes and corresponding functions, addressing modes, etc
	// missing: 02,40,44,54 (BRK, COP, RTI, MVN, MVP)
	opc[0x00] = &opc_stp;       opcamod[0x00] = IMPLIED;			// brk halts the processor
	opc[0x01] = &opc_logic;		opcamod[0x01] = DIRECTINDEXEDINDIRECTX;		// ORA (dp,X)
	opc[0x03] = &opc_logic;		opcamod[0x03] = STACKRELATIVE;			// ORA sr,S
	opc[0x04] = &opc_trbtsb;	opcamod[0x04] = DIRECT;				// TSB dp
	opc[0x05] = &opc_logic;		opcamod[0x05] = DIRECT;				// ORA dp
	opc[0x06] = &opc_asl;		opcamod[0x06] = DIRECT;				// ASL dp
	opc[0x07] = &opc_logic;		opcamod[0x07] = DIRECTINDIRECTLONG;		// ORA [dp]
	opc[0x08] = &opc_push;		opcamod[0x08] = IMPLIED;			// PHP
	opc[0x09] = &opc_logic;		opcamod[0x09] = IMMEDIATE;			// ORA #imm
	opc[0x0a] = &opc_asl;		opcamod[0x0a] = ACCUMULATOR;			// ASL
	opc[0x0b] = &opc_push;		opcamod[0x0b] = IMPLIED;			// PHD
	opc[0x0c] = &opc_trbtsb;	opcamod[0x0c] = ABSOLUTE;			// TSB $abs
	opc[0x0d] = &opc_logic;		opcamod[0x0d] = ABSOLUTE;			// ORA $abs
	opc[0x0e] = &opc_asl;		opcamod[0x0e] = ABSOLUTE;			// ASL $abs
	opc[0x0f] = &opc_logic;		opcamod[0x0f] = ABSOLUTELONG;			// ORA $abslong
	opc[0x10] = &opc_bxx;		opcamod[0x10] = BPL;				// BPL rel
	opc[0x11] = &opc_logic;		opcamod[0x11] = DIRECTINDIRECTINDEXEDY;		// ORA (dp),Y
	opc[0x12] = &opc_logic;		opcamod[0x12] = DIRECTINDIRECT;			// ORA (dp)
	opc[0x13] = &opc_logic;		opcamod[0x13] = STACKINDIRECTINDEXEDY;		// ORA (sr,S),Y
	opc[0x14] = &opc_trbtsb;	opcamod[0x14] = DIRECT;				// TRB dp
	opc[0x15] = &opc_logic;		opcamod[0x15] = DIRECTINDEXEDX;			// ORA dp,X
	opc[0x16] = &opc_asl;		opcamod[0x16] = DIRECTINDEXEDX;			// ASL dp,X
	opc[0x17] = &opc_logic;		opcamod[0x17] = DIRECTINDIRECTLONGINDEXEDY;	// ORA [dp],Y
	opc[0x18] = &opc_flagop;		opcamod[0x18] = IMPLIED;			// CLC
	opc[0x19] = &opc_logic;		opcamod[0x19] = ABSOLUTEINDEXEDY;		// ORA $abs,Y
	opc[0x1a] = &opc_incdec;	opcamod[0x1a] = ACCUMULATOR;			// INC
	opc[0x1b] = &opc_xfer;		opcamod[0x1b] = IMPLIED;			// TCS
	opc[0x1c] = &opc_trbtsb;	opcamod[0x1c] = ABSOLUTE;			// TRB $abs
	opc[0x1d] = &opc_logic;		opcamod[0x1d] = ABSOLUTEINDEXEDX;		// ORA $abs,X
	opc[0x1e] = &opc_asl;		opcamod[0x1e] = ABSOLUTEINDEXEDX;		// ASL $abs,X
	opc[0x1f] = &opc_logic;		opcamod[0x1f] = ABSOLUTELONGINDEXEDX;		// ORA $abslong,X
	opc[0x20] = &opc_jmpjsr;	opcamod[0x20] = ABSOLUTE;			// JSR $abs
	opc[0x21] = &opc_logic;		opcamod[0x21] = DIRECTINDEXEDINDIRECTX;		// AND (dp,X)
	opc[0x22] = &opc_jmpjsr;	opcamod[0x22] = ABSOLUTELONG;			// JSL $abslong
	opc[0x23] = &opc_logic;		opcamod[0x23] = STACKRELATIVE;			// AND sr,S
	opc[0x24] = &opc_bit;		opcamod[0x24] = DIRECT;				// BIT dp
	opc[0x25] = &opc_logic;		opcamod[0x25] = DIRECT;				// AND dp
	opc[0x26] = &opc_rol;		opcamod[0x26] = DIRECT;				// ROL dp
	opc[0x27] = &opc_logic;		opcamod[0x27] = DIRECTINDIRECTLONG;		// AND [dp]
	opc[0x28] = &opc_pop;		opcamod[0x28] = IMPLIED;			// PLP
	opc[0x29] = &opc_logic;		opcamod[0x29] = IMMEDIATE;			// AND #imm
	opc[0x2a] = &opc_rol;		opcamod[0x2a] = ACCUMULATOR;			// ROL
	opc[0x2b] = &opc_pop;		opcamod[0x2b] = IMPLIED;			// PLD
	opc[0x2c] = &opc_bit;		opcamod[0x2c] = ABSOLUTE;			// BIT $abs
	opc[0x2d] = &opc_logic;		opcamod[0x2d] = ABSOLUTE;			// AND $abs
	opc[0x2e] = &opc_rol;		opcamod[0x2e] = ABSOLUTE;			// ROL $abs
	opc[0x2f] = &opc_logic;		opcamod[0x2f] = ABSOLUTELONG;			// AND $abslong
	opc[0x30] = &opc_bxx;		opcamod[0x30] = BMI;				// BMI rel
	opc[0x31] = &opc_logic;		opcamod[0x31] = DIRECTINDIRECTINDEXEDY;		// AND (dp),Y
	opc[0x32] = &opc_logic;		opcamod[0x32] = DIRECTINDIRECT;			// AND (dp)
	opc[0x33] = &opc_logic;		opcamod[0x33] = STACKINDIRECTINDEXEDY;		// AND (sr,S),Y
	opc[0x34] = &opc_bit;		opcamod[0x34] = DIRECTINDEXEDX;			// BIT dp,X
	opc[0x35] = &opc_logic;		opcamod[0x35] = DIRECTINDEXEDX;			// AND dp,X
	opc[0x36] = &opc_rol;		opcamod[0x36] = DIRECTINDEXEDX;			// ROL dp,X
	opc[0x37] = &opc_logic;		opcamod[0x37] = DIRECTINDIRECTLONGINDEXEDY;	// AND [dp],Y
	opc[0x38] = &opc_flagop;		opcamod[0x38] = IMPLIED;			// SEC
	opc[0x39] = &opc_logic;		opcamod[0x39] = ABSOLUTEINDEXEDY;		// AND $abs,Y
	opc[0x3a] = &opc_incdec;	opcamod[0x3a] = ACCUMULATOR;			// DEC
	opc[0x3b] = &opc_xfer;		opcamod[0x3b] = IMPLIED;			// TSC
	opc[0x3c] = &opc_bit;		opcamod[0x3c] = ABSOLUTEINDEXEDX;		// BIT $abs,X
	opc[0x3d] = &opc_logic;		opcamod[0x3d] = ABSOLUTEINDEXEDX;		// AND $abs,X
	opc[0x3e] = &opc_rol;		opcamod[0x3e] = ABSOLUTEINDEXEDX;		// ROL $abs,X
	opc[0x3f] = &opc_logic;		opcamod[0x3f] = ABSOLUTELONGINDEXEDX;		// AND $abs,X
	opc[0x41] = &opc_logic;		opcamod[0x41] = DIRECTINDEXEDINDIRECTX;		// EOR (dp,X)
	opc[0x42] = &opc_wdm;		opcamod[0x42] = IMPLIED;			// WDM
	opc[0x43] = &opc_logic;		opcamod[0x43] = STACKRELATIVE;			// EOR sr,S
	opc[0x45] = &opc_logic;		opcamod[0x45] = DIRECT;				// EOR dp
	opc[0x46] = &opc_lsr;		opcamod[0x46] = DIRECT;				// LSR dp
	opc[0x47] = &opc_logic;		opcamod[0x47] = DIRECTINDIRECTLONG;		// EOR [dp]
	opc[0x48] = &opc_push;		opcamod[0x48] = IMPLIED;			// PHA
	opc[0x49] = &opc_logic;		opcamod[0x49] = IMMEDIATE;			// EOR #imm
	opc[0x4a] = &opc_lsr;		opcamod[0x4a] = ACCUMULATOR;			// LSR
	opc[0x4b] = &opc_push;		opcamod[0x4b] = IMPLIED;			// PHK
	opc[0x4c] = &opc_jmpjsr;	opcamod[0x4c] = ABSOLUTE;			// JMP $abs
	opc[0x4d] = &opc_logic;		opcamod[0x4d] = ABSOLUTE;			// EOR $abs
	opc[0x4e] = &opc_lsr;		opcamod[0x4e] = ABSOLUTE;			// LSR $abs
	opc[0x4f] = &opc_logic;		opcamod[0x4f] = ABSOLUTELONG;			// EOR $abslong
	opc[0x50] = &opc_bxx;		opcamod[0x50] = BVC;				// BVC rel
	opc[0x51] = &opc_logic;		opcamod[0x51] = DIRECTINDIRECTINDEXEDY;		// EOR (dp),Y
	opc[0x52] = &opc_logic;		opcamod[0x52] = DIRECTINDIRECT;			// EOR (dp)
	opc[0x53] = &opc_logic;		opcamod[0x53] = STACKINDIRECTINDEXEDY;		// EOR (sr,S),Y
	opc[0x55] = &opc_logic;		opcamod[0x55] = DIRECTINDEXEDX;			// EOR dp,X
	opc[0x56] = &opc_lsr;		opcamod[0x56] = DIRECTINDEXEDX;			// LSR dp,X
	opc[0x57] = &opc_logic;		opcamod[0x57] = DIRECTINDIRECTLONGINDEXEDY;	// EOR [dp],Y
	opc[0x58] = &opc_flagop;		opcamod[0x58] = IMPLIED;			// CLI
	opc[0x59] = &opc_logic;		opcamod[0x59] = ABSOLUTEINDEXEDY;		// EOR $abs,Y
	opc[0x5a] = &opc_push;		opcamod[0x5a] = IMPLIED;			// PHY
	opc[0x5b] = &opc_xfer;		opcamod[0x5b] = IMPLIED;			// TCD
	opc[0x5c] = &opc_jmpjsr;	opcamod[0x5c] = ABSOLUTELONG;			// JML $abslong
	opc[0x5d] = &opc_logic;		opcamod[0x5d] = ABSOLUTEINDEXEDX;		// EOR $abs,X
	opc[0x5e] = &opc_lsr;		opcamod[0x5e] = ABSOLUTEINDEXEDX;		// LSR $abs,X
	opc[0x5f] = &opc_logic;		opcamod[0x5f] = ABSOLUTELONGINDEXEDX;		// EOR $abslong,X
	opc[0x60] = &opc_return;	opcamod[0x60] = IMPLIED;			// RTS
	opc[0x61] = &opc_adcsbccmp;	opcamod[0x61] = DIRECTINDEXEDINDIRECTX;		// ADC (dp,X)
	opc[0x62] = &opc_brlper;	opcamod[0x62] = BRLPER;				// PER $longrel
	opc[0x63] = &opc_adcsbccmp;	opcamod[0x63] = STACKRELATIVE;			// ADC sr,S
	opc[0x64] = &opc_sta;		opcamod[0x64] = DIRECT;				// STZ dp
	opc[0x65] = &opc_adcsbccmp;	opcamod[0x65] = DIRECT;				// ADC dp
	opc[0x66] = &opc_ror;		opcamod[0x66] = DIRECT;				// ROR dp
	opc[0x67] = &opc_adcsbccmp;	opcamod[0x67] = DIRECTINDIRECTLONG;		// ADC [dp]
	opc[0x68] = &opc_pop;		opcamod[0x68] = IMPLIED;			// PLA
	opc[0x69] = &opc_adcsbccmp;	opcamod[0x69] = IMMEDIATE;			// ADC #imm
	opc[0x6a] = &opc_ror;		opcamod[0x6a] = ACCUMULATOR;			// ROR
	opc[0x6b] = &opc_return;	opcamod[0x6b] = IMPLIED;			// RTL
	opc[0x6c] = &opc_jmpjsr;	opcamod[0x6c] = ABSOLUTEINDIRECT;		// JMP ($abs)
	opc[0x6d] = &opc_adcsbccmp;	opcamod[0x6d] = ABSOLUTE;			// ADC $abs
	opc[0x6e] = &opc_ror;		opcamod[0x6e] = ABSOLUTE;			// ROR $abs
	opc[0x6f] = &opc_adcsbccmp;	opcamod[0x6f] = ABSOLUTELONG;			// ADC $abslong
	opc[0x70] = &opc_bxx;		opcamod[0x70] = BVS;				// BVS rel
	opc[0x71] = &opc_adcsbccmp;	opcamod[0x71] = DIRECTINDIRECTINDEXEDY;		// ADC (dp),Y
	opc[0x72] = &opc_adcsbccmp;	opcamod[0x72] = DIRECTINDIRECT;			// ADC (dp)
	opc[0x73] = &opc_adcsbccmp;	opcamod[0x73] = STACKINDIRECTINDEXEDY;		// ADC (sr,S),Y
	opc[0x74] = &opc_sta;		opcamod[0x74] = DIRECTINDEXEDX;			// STZ dp,X
	opc[0x75] = &opc_adcsbccmp;	opcamod[0x75] = DIRECTINDEXEDX;			// ADC dp,X
	opc[0x76] = &opc_ror;		opcamod[0x76] = DIRECTINDEXEDX;			// ROR dp,X
	opc[0x77] = &opc_adcsbccmp;	opcamod[0x77] = DIRECTINDIRECTLONGINDEXEDY;	// ADC [dp],Y
	opc[0x78] = &opc_flagop;		opcamod[0x78] = IMPLIED;			// SEI
	opc[0x79] = &opc_adcsbccmp;	opcamod[0x79] = ABSOLUTEINDEXEDY;		// ADC $abs,Y
	opc[0x7a] = &opc_pop;		opcamod[0x7a] = IMPLIED;			// PLY
	opc[0x7b] = &opc_xfer;		opcamod[0x7b] = IMPLIED;			// TDC
	opc[0x7c] = &opc_jmpjsr;	opcamod[0x7c] = ABSOLUTEINDEXEDINDIRECT;	// JMP ($abs,X)
	opc[0x7d] = &opc_adcsbccmp;	opcamod[0x7d] = ABSOLUTEINDEXEDX;		// ADC $abs,X
	opc[0x7e] = &opc_ror;		opcamod[0x7e] = ABSOLUTEINDEXEDX;		// ROR $abs,X
	opc[0x7f] = &opc_adcsbccmp;	opcamod[0x7f] = ABSOLUTELONGINDEXEDX;		// ADC $abslong,X
	opc[0x80] = &opc_bxx;		opcamod[0x80] = BRA;				// BRA rel
	opc[0x81] = &opc_sta;		opcamod[0x81] = DIRECTINDEXEDINDIRECTX;		// STA (dp,X)
	opc[0x82] = &opc_brlper;	opcamod[0x82] = BRLPER;				// BRL $longrel
	opc[0x83] = &opc_sta;		opcamod[0x83] = STACKRELATIVE;			// STA sr,S
	opc[0x84] = &opc_stxy;		opcamod[0x84] = DIRECT;				// STY dp
	opc[0x85] = &opc_sta;		opcamod[0x85] = DIRECT;				// STA dp
	opc[0x86] = &opc_stxy;		opcamod[0x86] = DIRECT;				// STX dp
	opc[0x87] = &opc_sta;		opcamod[0x87] = DIRECTINDIRECTLONG;		// STA [dp]
	opc[0x88] = &opc_inxydexy;	opcamod[0x88] = IMPLIED;			// DEY
	opc[0x89] = &opc_bit;		opcamod[0x89] = IMMEDIATE;			// BIT #imm
	opc[0x8a] = &opc_xfer;		opcamod[0x8a] = IMPLIED;			// TXA
	opc[0x8b] = &opc_push;		opcamod[0x8b] = IMPLIED;			// PHB
	opc[0x8c] = &opc_stxy;		opcamod[0x8c] = ABSOLUTE;			// STY $abs
	opc[0x8d] = &opc_sta;		opcamod[0x8d] = ABSOLUTE;			// STA $abs
	opc[0x8e] = &opc_stxy;		opcamod[0x8e] = ABSOLUTE;			// STX $abs
	opc[0x8f] = &opc_sta;		opcamod[0x8f] = ABSOLUTELONG;			// STA $abslong
	opc[0x90] = &opc_bxx;		opcamod[0x90] = BCC;				// BCC rel
	opc[0x91] = &opc_sta;		opcamod[0x91] = DIRECTINDIRECTINDEXEDY;		// STA (dp),Y
	opc[0x92] = &opc_sta;		opcamod[0x92] = DIRECTINDIRECT;			// STA (dp)
	opc[0x93] = &opc_sta;		opcamod[0x93] = STACKINDIRECTINDEXEDY;		// STA (sr,S),Y
	opc[0x94] = &opc_stxy;		opcamod[0x94] = DIRECTINDEXEDX;			// STY dp,X
	opc[0x95] = &opc_sta;		opcamod[0x95] = DIRECTINDEXEDX;			// STA dp,X
	opc[0x96] = &opc_stxy;		opcamod[0x96] = DIRECTINDEXEDY;			// STX dp,Y
	opc[0x97] = &opc_sta;		opcamod[0x97] = DIRECTINDIRECTLONGINDEXEDY;	// STA [dp],Y
	opc[0x98] = &opc_xfer;		opcamod[0x98] = IMPLIED;			// TYA
	opc[0x99] = &opc_sta;		opcamod[0x99] = ABSOLUTEINDEXEDY;		// STA $abs,Y
	opc[0x9a] = &opc_xfer;		opcamod[0x9a] = IMPLIED;			// TXS
	opc[0x9b] = &opc_xfer;		opcamod[0x9b] = IMPLIED;			// TXY
	opc[0x9c] = &opc_sta;		opcamod[0x9c] = ABSOLUTE;			// STZ $abs
	opc[0x9d] = &opc_sta;		opcamod[0x9d] = ABSOLUTEINDEXEDX;		// STA $abs,X
	opc[0x9e] = &opc_sta;		opcamod[0x9e] = ABSOLUTEINDEXEDX;		// STZ $abs,X
	opc[0x9f] = &opc_sta;		opcamod[0x9f] = ABSOLUTELONGINDEXEDX;		// STA $abslong,X
	opc[0xa0] = &opc_ldxy;		opcamod[0xa0] = IMMEDIATE;			// LDY #imm
	opc[0xa1] = &opc_lda;		opcamod[0xa1] = DIRECTINDEXEDINDIRECTX;		// LDA (dp,X)
	opc[0xa2] = &opc_ldxy;		opcamod[0xa2] = IMMEDIATE;			// LDX #imm
	opc[0xa3] = &opc_lda;		opcamod[0xa3] = STACKRELATIVE;			// LDA sr,S
	opc[0xa4] = &opc_ldxy;		opcamod[0xa4] = DIRECT;				// LDY dp
	opc[0xa5] = &opc_lda;		opcamod[0xa5] = DIRECT;				// LDA dp
	opc[0xa6] = &opc_ldxy;		opcamod[0xa6] = DIRECT;				// LDX dp
	opc[0xa7] = &opc_lda;		opcamod[0xa7] = DIRECTINDIRECTLONG;		// LDA [dp]
	opc[0xa8] = &opc_xfer;		opcamod[0xa8] = IMPLIED;			// TAY
	opc[0xa9] = &opc_lda;		opcamod[0xa9] = IMMEDIATE;			// LDA #imm
	opc[0xaa] = &opc_xfer;		opcamod[0xaa] = IMPLIED;			// TAX
	opc[0xab] = &opc_pop;		opcamod[0xab] = IMPLIED;			// PLB
	opc[0xac] = &opc_ldxy;		opcamod[0xac] = ABSOLUTE;			// LDY $abs
	opc[0xad] = &opc_lda;		opcamod[0xad] = ABSOLUTE;			// LDA $abs
	opc[0xae] = &opc_ldxy;		opcamod[0xae] = ABSOLUTE;			// LDX $abs
	opc[0xaf] = &opc_lda;		opcamod[0xaf] = ABSOLUTELONG;			// LDA $abslong
	opc[0xb0] = &opc_bxx;		opcamod[0xb0] = BCS;				// BCS rel
	opc[0xb1] = &opc_lda;		opcamod[0xb1] = DIRECTINDIRECTINDEXEDY;		// LDA (dp),Y
	opc[0xb2] = &opc_lda;		opcamod[0xb2] = DIRECTINDIRECT;			// LDA (dp)
	opc[0xb3] = &opc_lda;		opcamod[0xb3] = STACKINDIRECTINDEXEDY;		// LDA (sr,S),Y
	opc[0xb4] = &opc_ldxy;		opcamod[0xb4] = DIRECTINDEXEDX;			// LDY dp,X
	opc[0xb5] = &opc_lda;		opcamod[0xb5] = DIRECTINDEXEDX;			// LDA dp,X
	opc[0xb6] = &opc_ldxy;		opcamod[0xb6] = DIRECTINDEXEDY;			// LDX dp,Y
	opc[0xb7] = &opc_lda;		opcamod[0xb7] = DIRECTINDIRECTLONGINDEXEDY;	// LDA [dp],Y
	opc[0xb8] = &opc_flagop;		opcamod[0xb8] = IMPLIED;			// CLV
	opc[0xb9] = &opc_lda;		opcamod[0xb9] = ABSOLUTEINDEXEDY;		// LDA $abs,Y
	opc[0xba] = &opc_xfer;		opcamod[0xba] = IMPLIED;			// TSX
	opc[0xbb] = &opc_xfer;		opcamod[0xbb] = IMPLIED;			// TYX
	opc[0xbc] = &opc_ldxy;		opcamod[0xbc] = ABSOLUTEINDEXEDX;		// LDY $abs,X
	opc[0xbd] = &opc_lda;		opcamod[0xbd] = ABSOLUTEINDEXEDX;		// LDA $abs,X
	opc[0xbe] = &opc_ldxy;		opcamod[0xbe] = ABSOLUTEINDEXEDY;		// LDX $abs,Y
	opc[0xbf] = &opc_lda;		opcamod[0xbf] = ABSOLUTELONGINDEXEDX;		// LDA $abslong,X
	opc[0xc0] = &opc_adcsbccmp;	opcamod[0xc0] = IMMEDIATE;			// CPY #imm
	opc[0xc1] = &opc_adcsbccmp;	opcamod[0xc1] = DIRECTINDEXEDINDIRECTX;		// CMP (dp,X)
	opc[0xc2] = &opc_rep;		opcamod[0xc2] = IMMEDIATE;			// REP #imm
	opc[0xc3] = &opc_adcsbccmp;	opcamod[0xc3] = STACKRELATIVE;			// CMP sr,S
	opc[0xc4] = &opc_adcsbccmp;	opcamod[0xc4] = DIRECT;				// CPY dp
	opc[0xc5] = &opc_adcsbccmp;	opcamod[0xc5] = DIRECT;				// CMP dp
	opc[0xc6] = &opc_incdec;	opcamod[0xc6] = DIRECT;				// DEC dp
	opc[0xc7] = &opc_adcsbccmp;	opcamod[0xc7] = DIRECTINDIRECTLONG;		// CMP [dp]
	opc[0xc8] = &opc_inxydexy;	opcamod[0xc8] = IMPLIED;			// INY
	opc[0xc9] = &opc_adcsbccmp;	opcamod[0xc9] = IMMEDIATE;			// CMP #imm
	opc[0xca] = &opc_inxydexy;	opcamod[0xca] = IMPLIED;			// DEX
	opc[0xcb] = &opc_wai;		opcamod[0xcb] = IMPLIED;			// WAI
	opc[0xcc] = &opc_adcsbccmp;	opcamod[0xcc] = ABSOLUTE;			// CPY $abs
	opc[0xcd] = &opc_adcsbccmp;	opcamod[0xcd] = ABSOLUTE;			// CMP $abs
	opc[0xce] = &opc_incdec;	opcamod[0xce] = ABSOLUTE;			// DEC $abs
	opc[0xcf] = &opc_adcsbccmp;	opcamod[0xcf] = ABSOLUTELONG;			// CMP $abslong
	opc[0xd0] = &opc_bxx;		opcamod[0xd0] = BNE;				// BNE rel
	opc[0xd1] = &opc_adcsbccmp;	opcamod[0xd1] = DIRECTINDIRECTINDEXEDY; 	// CMP (dp),Y
	opc[0xd2] = &opc_adcsbccmp;	opcamod[0xd2] = DIRECTINDIRECT;			// CMP (dp)
	opc[0xd3] = &opc_adcsbccmp;	opcamod[0xd3] = STACKINDIRECTINDEXEDY;		// CMP (sr,S),Y
	opc[0xd4] = &opc_pei;		opcamod[0xd4] = DIRECT;				// PEI (dp)
	opc[0xd5] = &opc_adcsbccmp;	opcamod[0xd5] = DIRECTINDEXEDX;			// CMP dp,X
	opc[0xd6] = &opc_incdec;	opcamod[0xd6] = DIRECTINDEXEDX;			// DEC dp,X
	opc[0xd7] = &opc_adcsbccmp;	opcamod[0xd7] = DIRECTINDIRECTLONGINDEXEDY;	// CMP [dp],Y
	opc[0xd8] = &opc_flagop;		opcamod[0xd8] = IMPLIED;			// CLD
	opc[0xd9] = &opc_adcsbccmp;	opcamod[0xd9] = ABSOLUTEINDEXEDY;		// CMP $abs,Y
	opc[0xda] = &opc_push;		opcamod[0xda] = IMPLIED;			// PHX
	opc[0xdb] = &opc_stp;		opcamod[0xdb] = IMPLIED;			// STP
	opc[0xdc] = &opc_jmpjsr;	opcamod[0xdc] = ABSOLUTEINDIRECTLONG;		// JML [$abs]
	opc[0xdd] = &opc_adcsbccmp;	opcamod[0xdd] = ABSOLUTEINDEXEDX;		// CMP $abs,X
	opc[0xde] = &opc_incdec;	opcamod[0xde] = ABSOLUTEINDEXEDX;		// DEC $abs,X
	opc[0xdf] = &opc_adcsbccmp;	opcamod[0xdf] = ABSOLUTELONGINDEXEDX;		// CMP $abslong,X
	opc[0xe0] = &opc_adcsbccmp;	opcamod[0xe0] = IMMEDIATE;			// CPX #imm
	opc[0xe1] = &opc_adcsbccmp;	opcamod[0xe1] = DIRECTINDEXEDINDIRECTX;		// SBC (dp,X)
	opc[0xe2] = &opc_sep;		opcamod[0xe2] = IMMEDIATE;			// SEP #imm
	opc[0xe3] = &opc_adcsbccmp;	opcamod[0xe3] = STACKRELATIVE;			// SBC sr,S
	opc[0xe4] = &opc_adcsbccmp;	opcamod[0xe4] = DIRECT;				// CPX dp
	opc[0xe5] = &opc_adcsbccmp;	opcamod[0xe5] = DIRECT;				// SBC dp
	opc[0xe6] = &opc_incdec;	opcamod[0xe6] = DIRECT;				// INC dp
	opc[0xe7] = &opc_adcsbccmp;	opcamod[0xe7] = DIRECTINDIRECTLONG;		// SBC [dp]
	opc[0xe8] = &opc_inxydexy;	opcamod[0xe8] = IMPLIED;			// INX
	opc[0xe9] = &opc_adcsbccmp;	opcamod[0xe9] = IMMEDIATE;			// SBC #imm
	opc[0xea] = &opc_nop;		opcamod[0xea] = IMPLIED;			// NOP
	opc[0xeb] = &opc_xfer;		opcamod[0xeb] = IMPLIED;			// XBA
	opc[0xec] = &opc_adcsbccmp;	opcamod[0xec] = ABSOLUTE;			// CPX $abs
	opc[0xed] = &opc_adcsbccmp;	opcamod[0xed] = ABSOLUTE;			// SBC $abs
	opc[0xee] = &opc_incdec;	opcamod[0xee] = ABSOLUTE;			// INC $abs
	opc[0xef] = &opc_adcsbccmp;	opcamod[0xef] = ABSOLUTELONG;			// SBC $abslong
	opc[0xf0] = &opc_bxx;		opcamod[0xf0] = BEQ;				// BEQ rel
	opc[0xf1] = &opc_adcsbccmp;	opcamod[0xf1] = DIRECTINDIRECTINDEXEDY; 	// SBC (dp),Y
	opc[0xf2] = &opc_adcsbccmp;	opcamod[0xf2] = DIRECTINDIRECT;			// SBC (dp)
	opc[0xf3] = &opc_adcsbccmp;	opcamod[0xf3] = STACKINDIRECTINDEXEDY;		// SBC (sr,S),Y
	opc[0xf4] = &opc_pea;		opcamod[0xf4] = ABSOLUTE;			// PEA $abs
	opc[0xf5] = &opc_adcsbccmp;	opcamod[0xf5] = DIRECTINDEXEDX;			// SBC dp,X
	opc[0xf6] = &opc_incdec;	opcamod[0xf6] = DIRECTINDEXEDX;			// INC dp,X
	opc[0xf7] = &opc_adcsbccmp;	opcamod[0xf7] = DIRECTINDIRECTLONGINDEXEDY;	// SBC [dp],Y
	opc[0xf8] = &opc_flagop;		opcamod[0xf8] = IMPLIED;			// SED
	opc[0xf9] = &opc_adcsbccmp;	opcamod[0xf9] = ABSOLUTEINDEXEDY;		// SBC $abs,Y
	opc[0xfa] = &opc_pop;		opcamod[0xfa] = IMPLIED;			// PLX
	opc[0xfb] = &opc_xce;		opcamod[0xfb] = IMPLIED;			// XCE
	opc[0xfc] = &opc_jmpjsr;	opcamod[0xfc] = ABSOLUTEINDEXEDINDIRECT;	// JSR ($abs,X)
	opc[0xfd] = &opc_adcsbccmp;	opcamod[0xfd] = ABSOLUTEINDEXEDX;		// SBC $abs,X
	opc[0xfe] = &opc_incdec;	opcamod[0xfe] = ABSOLUTEINDEXEDX;		// INC $abs,X
	opc[0xff] = &opc_adcsbccmp;	opcamod[0xff] = ABSOLUTELONGINDEXEDX;		// SBC $abslong,X
}

static void push(unsigned char topush)
{
	wmem(0,s.x,topush);
	s.x--;
	if (e==1)
		if (s.x==0x00ff)
			s.x=0x1ff; // wrap the stack if in emulation mode
}

static void push16(unsigned short topush)
{
	union reg temp;

	temp.x = topush;
	push(temp.h);
	push(temp.l);
}

static unsigned char pop(void)
{
	s.x++;
	if (e==1)
		if (s.x==0x200)
			s.x=0x100; // wrap the stack if in emulation mode
	return rmem(0,s.x);
}

static unsigned short pop16(void)
{
	union reg temp;

	temp.l=pop();
	temp.h=pop();

	return temp.x;
}

static void cpu_reset(void)
{
	s.x=0x1ff; // stack to default
	a.x=0; // registers cleared for determinism (index high bytes must be 0 in emulation mode)
	x.x=0;
	y.x=0;
	d.x=0; // direct reg to zero page
	p=0x34; // PSR clear except IRQ disable, unimplemented bit and break bit set
	e=1; // hidden bit 1
	pc.x=(mem[0xfffd]*256)+mem[0xfffc]; // set PC to reset address
	b=0; // data bank to 0
	k=0; // program bank to 0
}

// side-effect free memory read for the trace/disassembler
static unsigned char peek(unsigned char bank, unsigned short address)
{
	return mem[((bank * 65536) + address) & MEMTOP];
}

static void show_trace(void)
{
	printf("A=%04X X=%04X Y=%04X S=%04X D=%04X P=%02X B=%02X e=%d cyc=%ld\n",a.x,x.x,y.x,s.x,d.x,p,b,e,engine_65816_cycles);
}

static void disass(void)
{
	printf("%02X/%04X: %02X %02X%02X%02X ",k,pc.x,peek(k,pc.x),peek(k,pc.x+1),peek(k,pc.x+2),peek(k,pc.x+3));
}

void engine_65816_reset()
{
	cpu_reset();
}

int engine_65816_init(unsigned char *a_memory, int a_traceflag)
{
	engine_65816_cycles = 0;
	engine_65816_halt = 0;
	traceflag = a_traceflag;

	mem = a_memory;
	initops();

	// initiate reset cycle
	engine_65816_reset();

	return 0;
}

void engine_65816_step()
{
	if (engine_65816_halt)
		return; // STP/BRK halted the processor
	if (traceflag) disass();
	opcload = rmem(k,pc.x);
	opc[opcload](opcamod[opcload]);
	if (traceflag) show_trace();
}

long engine_65816_cycle_count()
{
	return engine_65816_cycles;
}

int engine_65816_halted()
{
	return engine_65816_halt;
}

/*
Handler routines for opcodes

These are loaded up and called by pointer via the opcode table.
*/

// processor status flag bits
#define FLAG_C 0x01
#define FLAG_Z 0x02
#define FLAG_I 0x04
#define FLAG_D 0x08
#define FLAG_X 0x10 // index registers 8-bit (native mode)
#define FLAG_M 0x20 // accumulator/memory 8-bit (native mode)
#define FLAG_V 0x40
#define FLAG_N 0x80

// width tests: emulation mode is always 8-bit
static int acc8(void)
{
	return (e==1) || ((p & FLAG_M) != 0);
}

static int idx8(void)
{
	return (e==1) || ((p & FLAG_X) != 0);
}

// flag helpers
static void set_flag(unsigned char mask, int cond)
{
	if (cond)
		p |= mask;
	else
		p &= (unsigned char)~mask;
}

static void set_nz8(unsigned char v)
{
	set_flag(FLAG_Z, v == 0);
	set_flag(FLAG_N, (v & 0x80) != 0);
}

static void set_nz16(unsigned short v)
{
	set_flag(FLAG_Z, v == 0);
	set_flag(FLAG_N, (v & 0x8000) != 0);
}

static void set_nz(unsigned short v, int is8)
{
	if (is8)
		set_nz8((unsigned char)v);
	else
		set_nz16(v);
}

// cycle counting for the common addressing modes
enum { CYC_READ, CYC_WRITE, CYC_RMW };

static void addr_cycles(int amod, int kind, int is8)
{
	int c = 0;
	int dp = 0; // direct page mode: +1 cycle if DL != 0

	if (kind == CYC_RMW)
	{
		switch (amod)
		{
			case ACCUMULATOR: c = 2; break;
			case ABSOLUTE: c = 6; break;
			case DIRECT: c = 5; dp = 1; break;
			case DIRECTINDEXEDX: c = 6; dp = 1; break;
			case ABSOLUTEINDEXEDX: c = 7; break;
		}
		if ((amod != ACCUMULATOR) && !is8)
			c += 2; // 16-bit read-modify-write does an extra read and write
	}
	else
	{
		switch (amod)
		{
			case IMMEDIATE: c = 2; break;
			case ABSOLUTE: c = 4; break;
			case ABSOLUTELONG: c = 5; break;
			case DIRECT: c = 3; dp = 1; break;
			case DIRECTINDEXEDX:
			case DIRECTINDEXEDY: c = 4; dp = 1; break;
			case ABSOLUTEINDEXEDX:
			case ABSOLUTEINDEXEDY:
				if (kind == CYC_WRITE)
					c = 5;
				else
					c = 4 + (boundcross == 1);
				break;
			case ABSOLUTELONGINDEXEDX: c = 5; break;
			case DIRECTINDIRECT: c = 5; dp = 1; break;
			case DIRECTINDIRECTLONG: c = 6; dp = 1; break;
			case DIRECTINDEXEDINDIRECTX: c = 6; dp = 1; break;
			case DIRECTINDIRECTINDEXEDY:
				if (kind == CYC_WRITE)
					c = 6;
				else
					c = 5 + (boundcross == 1);
				dp = 1;
				break;
			case DIRECTINDIRECTLONGINDEXEDY: c = 6; dp = 1; break;
			case STACKRELATIVE: c = 4; break;
			case STACKINDIRECTINDEXEDY: c = 7; break;
		}
		if (!is8)
			c++; // 16-bit data takes an extra cycle
	}
	if (dp && (d.l != 0))
		c++;
	engine_65816_cycles += c;
}

// store 8 or 16 bits of work through the writeback address
static void store_work(int amod, unsigned short v, int is8)
{
	work.x = v;
	writeback(amod, is8 ? 8 : 16);
}

static void opc_wdm(int amod)
{
	// WDM is currently unimplemented and acts like a 2-byte NOP (opcode + signature byte).
	inc_pc(2);
	engine_65816_cycles += 2;
}

static void opc_stp(int amod)
{
	// BRK is also mapped here, so it halts the processor too
	engine_65816_halt = 1;
	inc_pc(1);
	engine_65816_cycles += 3;
}

static void opc_flagop(int amod)
{
	switch (opcload)
	{
		case 0x18: p &= (unsigned char)~FLAG_C; break; // CLC
		case 0x38: p |= FLAG_C; break; // SEC
		case 0x58: p &= (unsigned char)~FLAG_I; break; // CLI
		case 0x78: p |= FLAG_I; break; // SEI
		case 0xb8: p &= (unsigned char)~FLAG_V; break; // CLV
		case 0xd8: p &= (unsigned char)~FLAG_D; break; // CLD
		case 0xf8: p |= FLAG_D; break; // SED
	}
	inc_pc(1);
	engine_65816_cycles += 2;
}

static void push_reg(const union reg *r, int is8)
{
	if (is8)
	{
		push(r->l);
		engine_65816_cycles += 3;
	}
	else
	{
		push16(r->x);
		engine_65816_cycles += 4;
	}
}

static void opc_push(int amod)
{
	union reg tmp;

	inc_pc(1);
	switch (opcload)
	{
		case 0x48: push_reg(&a, acc8()); break; // PHA
		case 0xda: push_reg(&x, idx8()); break; // PHX
		case 0x5a: push_reg(&y, idx8()); break; // PHY
		case 0x08: tmp.l = p; push_reg(&tmp, 1); break; // PHP
		case 0x8b: tmp.l = b; push_reg(&tmp, 1); break; // PHB
		case 0x4b: tmp.l = k; push_reg(&tmp, 1); break; // PHK
		case 0x0b: push_reg(&d, 0); break; // PHD
	}
}

static void pop_reg(union reg *r, int is8)
{
	if (is8)
	{
		r->l = pop();
		set_nz8(r->l);
		engine_65816_cycles += 4;
	}
	else
	{
		r->x = pop16();
		set_nz16(r->x);
		engine_65816_cycles += 5;
	}
}

static void opc_pop(int amod)
{
	union reg tmp;

	inc_pc(1);
	switch (opcload)
	{
		case 0x68: pop_reg(&a, acc8()); break; // PLA
		case 0xfa: pop_reg(&x, idx8()); break; // PLX
		case 0x7a: pop_reg(&y, idx8()); break; // PLY
		case 0x2b: pop_reg(&d, 0); break; // PLD
		case 0xab: // PLB
			pop_reg(&tmp, 1);
			b = tmp.l;
			break;
		case 0x28: // PLP
			p = pop(); // conditions all flags, obviously
			if (e==1)
				p |= 0x30; // M and X bits are forced to 1 in emulation mode
			else if ((p & FLAG_X) != 0)
			{
				x.h = 0; // 8-bit index registers lose their high bytes
				y.h = 0;
			}
			engine_65816_cycles += 4;
			break;
	}
}

// transfer into an index register (width set by X)
static void xfer_to_index(union reg *dst, const union reg *src)
{
	if (idx8())
	{
		dst->l = src->l;
		set_nz8(dst->l);
	}
	else
	{
		dst->x = src->x;
		set_nz16(dst->x);
	}
}

// transfer into the accumulator (width set by M)
static void xfer_to_acc(const union reg *src)
{
	if (acc8())
	{
		a.l = src->l;
		set_nz8(a.l);
	}
	else
	{
		a.x = src->x;
		set_nz16(a.x);
	}
}

static void opc_xfer(int amod)
{
	unsigned char t;

	inc_pc(1);

	switch(opcload)
	{
		case 0xaa: xfer_to_index(&x, &a); break; // TAX
		case 0xa8: xfer_to_index(&y, &a); break; // TAY
		case 0xba: xfer_to_index(&x, &s); break; // TSX
		case 0x9b: xfer_to_index(&y, &x); break; // TXY
		case 0xbb: xfer_to_index(&x, &y); break; // TYX
		case 0x8a: xfer_to_acc(&x); break; // TXA
		case 0x98: xfer_to_acc(&y); break; // TYA
		case 0x9a: // TXS - affects no flags
			if (e==1)
				s.l = x.l; // stack high byte stays at $01
			else
				s.x = x.x;
			break;
		case 0x1b: // TCS - affects no flags
			if (e==1)
				s.l = a.l; // stack high byte stays at $01
			else
				s.x = a.x;
			break;
		case 0x5b: // TCD
			d.x = a.x;
			set_nz16(d.x);
			break;
		case 0x7b: // TDC
			a.x = d.x;
			set_nz16(a.x);
			break;
		case 0x3b: // TSC
			a.x = s.x;
			set_nz16(a.x);
			break;
		case 0xeb: // XBA
			t = a.h;
			a.h = a.l;
			a.l = t;
			set_nz8(a.l);
			engine_65816_cycles++; // XBA takes 3
			break;
	}

	engine_65816_cycles+=2; // for all instructions
}

static void opc_logic(int amod)
{
	int is8 = acc8();
	unsigned short v, m;

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	v = is8 ? a.l : a.x;
	m = is8 ? work.l : work.x;
	switch (opcload >> 5) // bits 7-5 pick the operation within the standard ALU opcode group
	{
		case 0: v |= m; break; // ORA
		case 1: v &= m; break; // AND
		case 2: v ^= m; break; // EOR
	}
	if (is8)
		a.l = (unsigned char)v;
	else
		a.x = v;
	set_nz(v, is8);
	addr_cycles(amod, CYC_READ, is8);
}

static void opc_lda(int amod)
{
	int is8 = acc8();

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	if (is8)
	{
		a.l = work.l;
		set_nz8(a.l);
	}
	else
	{
		a.x = work.x;
		set_nz16(a.x);
	}
	addr_cycles(amod, CYC_READ, is8);
}

static void opc_ldxy(int amod)
{
	int is8 = idx8();
	union reg *r = (opcload & 0x02) ? &x : &y; // LDX opcodes (a2,a6,ae,b6,be) have bit 1 set, LDY don't

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	if (is8)
	{
		r->l = work.l;
		set_nz8(r->l);
	}
	else
	{
		r->x = work.x;
		set_nz16(r->x);
	}
	addr_cycles(amod, CYC_READ, is8);
}

static void opc_sta(int amod)
{
	int is8 = acc8();
	int stz = (opcload == 0x64) || (opcload == 0x74) || (opcload == 0x9c) || (opcload == 0x9e);

	inc_pc(1);
	noread = 1; // stores never read the target
	fetch(amod, is8 ? 8 : 16); // set up writeback address
	noread = 0;
	store_work(amod, stz ? 0 : (is8 ? a.l : a.x), is8);
	addr_cycles(amod, CYC_WRITE, is8);
}

static void opc_stxy(int amod)
{
	int is8 = idx8();
	union reg *r = (opcload & 0x02) ? &x : &y; // STX opcodes (86,8e,96) have bit 1 set, STY don't

	inc_pc(1);
	noread = 1;
	fetch(amod, is8 ? 8 : 16); // set up writeback address
	noread = 0;
	store_work(amod, is8 ? r->l : r->x, is8);
	addr_cycles(amod, CYC_WRITE, is8);
}

// ASL, ROL, LSR and ROR share this routine
enum { SH_ASL, SH_ROL, SH_LSR, SH_ROR };

static void do_shift(int amod, int kind)
{
	int is8 = acc8();
	unsigned msb = is8 ? 0x80 : 0x8000;
	unsigned mask = is8 ? 0xff : 0xffff;
	unsigned cin = (p & FLAG_C) ? 1 : 0;
	unsigned v, r = 0;

	inc_pc(1);
	if (amod == ACCUMULATOR)
		v = is8 ? a.l : a.x;
	else
	{
		fetch(amod, is8 ? 8 : 16);
		v = is8 ? work.l : work.x;
	}
	switch (kind)
	{
		case SH_ASL:
			set_flag(FLAG_C, (v & msb) != 0);
			r = (v << 1) & mask;
			break;
		case SH_ROL:
			set_flag(FLAG_C, (v & msb) != 0);
			r = ((v << 1) | cin) & mask;
			break;
		case SH_LSR:
			set_flag(FLAG_C, (v & 1) != 0);
			r = v >> 1;
			break;
		case SH_ROR:
			set_flag(FLAG_C, (v & 1) != 0);
			r = (v >> 1) | (cin ? msb : 0);
			break;
	}
	set_nz(r, is8); // LSR always clears N since bit 7/15 is shifted out
	if (amod == ACCUMULATOR)
	{
		if (is8)
			a.l = (unsigned char)r;
		else
			a.x = (unsigned short)r;
	}
	else
		store_work(amod, (unsigned short)r, is8);
	addr_cycles(amod, CYC_RMW, is8);
}

static void opc_asl(int amod) { do_shift(amod, SH_ASL); }
static void opc_rol(int amod) { do_shift(amod, SH_ROL); }
static void opc_lsr(int amod) { do_shift(amod, SH_LSR); }
static void opc_ror(int amod) { do_shift(amod, SH_ROR); }

static void opc_inxydexy(int amod)
{
	union reg *r = ((opcload == 0xe8) || (opcload == 0xca)) ? &x : &y; // INX/DEX : INY/DEY
	int delta = ((opcload == 0xe8) || (opcload == 0xc8)) ? 1 : -1; // INX/INY : DEX/DEY

	inc_pc(1);
	if (idx8())
	{
		r->l += delta;
		set_nz8(r->l);
	}
	else
	{
		r->x += delta;
		set_nz16(r->x);
	}
	engine_65816_cycles+=2; // for all 4 instructions
}

static void opc_incdec(int amod)
{
	int is8 = acc8();
	int delta = (opcload == 0x3a) || ((opcload & 0xe0) == 0xc0) ? -1 : 1; // DEC: 3a,c6,ce,d6,de  INC: the rest
	unsigned v;

	inc_pc(1);
	if (amod == ACCUMULATOR)
		v = is8 ? a.l : a.x;
	else
	{
		fetch(amod, is8 ? 8 : 16);
		v = is8 ? work.l : work.x;
	}
	v += delta;
	if (is8)
		v &= 0xff;
	else
		v &= 0xffff;
	set_nz(v, is8);
	if (amod == ACCUMULATOR)
	{
		if (is8)
			a.l = (unsigned char)v;
		else
			a.x = (unsigned short)v;
	}
	else
		store_work(amod, (unsigned short)v, is8);
	addr_cycles(amod, CYC_RMW, is8);
}

static void inval_op(int amod)
{
	inc_pc(1);
	engine_65816_cycles += 2;
}

static void opc_wai(int amod)
{
	// interrupts currently unimplemented - add 3 cycs and continue.
	inc_pc(1);
	engine_65816_cycles += 3;
}

static void opc_jmpjsr(int amod)
{
	inc_pc(1);
	noread = 1; // we only want the target address, not the data there
	fetch(amod,16);
	noread = 0;
	switch(opcload)
	{
		case 0x20: // JSR $abs
			push16(pc.x - 1);
			pc.x = wb_a.x;
			engine_65816_cycles += 6;
			break;
		case 0x22: // JSL $abslong
			push(k);
			push16(pc.x - 1);
			k = wb_b;
			pc.x = wb_a.x;
			engine_65816_cycles += 8;
			break;
		case 0x4c: // JMP $abs
			pc.x = wb_a.x;
			engine_65816_cycles += 3;
			break;
		case 0x5c: // JML $abslong
			k = wb_b;
			pc.x = wb_a.x;
			engine_65816_cycles += 4;
			break;
		case 0x6c: // JMP ($abs)
			pc.x = wb_a.x;
			engine_65816_cycles += 5;
			break;
		case 0x7c: // JMP ($abs,X)
			pc.x = wb_a.x;
			engine_65816_cycles += 6;
			break;
		case 0xdc: // JMP [$abslong]
			pc.x = wb_a.x;
			k = wb_b;
			engine_65816_cycles += 6;
			break;
		case 0xfc: // JSR ($abs,X)
			push16(pc.x - 1);
			pc.x = wb_a.x;
			engine_65816_cycles += 8;
			break;
	}
}

static void opc_return(int amod)
{
	pc.x = pop16();
	pc.x++;
	if (opcload==0x6b)
		k=pop(); // pop k if this is RTL
	engine_65816_cycles += 6; // both types run 6 engine_65816_cycles
}

static void opc_pei(int amod)
{
	// Note: This instruction is advertised as Direct Indirect, but the way it behaves,
	// it is actually just Direct. It pushes the 16-bit contents of the DP location.
	inc_pc(1);
	fetch(amod,16);
	push16(work.x);
	engine_65816_cycles += 6;
	if (d.l != 0)
		engine_65816_cycles++; // extra engine_65816_cycles if dp is not page aligned
}

static void opc_pea(int amod)
{
	inc_pc(1);
	noread = 1;
	fetch(amod,16);
	noread = 0;
	push16(wb_a.x);
	engine_65816_cycles += 5;
}

static void opc_brlper(int amod)
{
	union reg offset;

	// get 16-bit offset
	inc_pc(1);
	offset.l = rmem(k,pc.x);
	inc_pc(1);
	offset.h = rmem(k,pc.x);
	inc_pc(1); // point to next instruction for PER

	switch (opcload)
	{
		case 0x62: // PER
			push16(pc.x + offset.x);
			engine_65816_cycles += 6;
			break;
		case 0x82: // BRL
			pc.x += offset.x;
			engine_65816_cycles += 4;
			break;
	}
}

static void opc_bxx(int amod)
{
	union reg offset;
	int taken=0;

	// get offset byte
	inc_pc(1);
	offset.l = rmem(k,pc.x);
	if (offset.l > 127) // sign extend to a 16-bit value
		offset.h = 0xff;
	else
		offset.h = 0;
	inc_pc(1); // point to next instruction jic branch not taken

	// determine if to take the branch
	switch (amod)
	{
		case BRA:
			taken=1;
			break;
		case BCC:
			taken = ((p & 0x01) == 0x00);
			break;
		case BCS:
			taken = ((p & 0x01) == 0x01);
			break;
		case BNE:
			taken = ((p & 0x02) == 0x00);
			break;
		case BEQ:
			taken = ((p & 0x02) == 0x02);
			break;
		case BVC:
			taken = ((p & 0x40) == 0x00);
			break;
		case BVS:
			taken = ((p & 0x40) == 0x40);
			break;
		case BPL:
			taken = ((p & 0x80) == 0x00);
			break;
		case BMI:
			taken = ((p & 0x80) == 0x80);
			break;
	}

	// compute clock engine_65816_cycles used
	engine_65816_cycles += 2; // will always use at least 2
	if (taken)
	{
		unsigned short oldpc = pc.x;
		pc.x += offset.x; // move program counter if we take the branch
		engine_65816_cycles++; // add one if branch taken
		if ((e==1) && ((oldpc & 0xff00) != (pc.x & 0xff00)))
			engine_65816_cycles++; // add one for a page crossing in emulation mode
	}
}

static void opc_nop(int amod)
{
	inc_pc(1);
	engine_65816_cycles += 2;
}

static void opc_rep(int amod)
{
	inc_pc(1);
	fetch(amod,8);
	work.l = ~work.l; // negate to make AND mask
	p &= work.l;
	if (e==1)
		p |= 0x30; // M and X bits can't be cleared in emulation mode
	engine_65816_cycles += 3;
}

static void opc_sep(int amod)
{
	inc_pc(1);
	fetch(amod,8);
	p |= work.l;
	if ((e==0) && ((p & 0x10) == 0x10))
	{
		x.h = 0; // 8-bit index registers lose their high bytes
		y.h = 0;
	}
	engine_65816_cycles += 3;
}

static void opc_xce(int amod)
{
	int hold;

	hold = (p & 0x01); // save carry bit
	if (e)
		p |= 1;
	else
		p &= 0xfe;
	e = hold; // set e to what carry was
	if (e==1)
	{
		p |= 0x30; // set unimplemented and break bits
		s.h = 0x01; // high byte of stack ptr is 01
		x.h = 0; // index registers become 8-bit
		y.h = 0;
	}
	inc_pc(1);
	engine_65816_cycles += 2;
}

// ADC, SBC and CMP/CPX/CPY share this routine
enum { ALU_ADC, ALU_SBC, ALU_CMP };

static unsigned alu(int op, unsigned acc, unsigned m, int is8)
{
	unsigned mask = is8 ? 0xff : 0xffff;
	unsigned sign = is8 ? 0x80 : 0x8000;
	unsigned carry = (p & FLAG_C) ? 1 : 0;
	int decimal = ((p & FLAG_D) != 0) && (op != ALU_CMP);
	int nibbles = is8 ? 2 : 4;
	int i;
	unsigned opnd, sum, res, n, part;
	int borrow;

	// subtraction is addition of the inverted operand; a compare is a subtraction with carry set
	opnd = (op == ALU_ADC) ? m : (~m & mask);
	if (op == ALU_CMP)
		carry = 1;
	sum = acc + opnd + carry;
	res = sum & mask;

	if (op != ALU_CMP) // CMP, CPX, CPY don't condition the V flag
		set_flag(FLAG_V, ((acc ^ res) & ~(acc ^ opnd) & sign) != 0);

	if (!decimal)
		set_flag(FLAG_C, sum > mask);
	else if (op == ALU_ADC)
	{
		// BCD add, digit by digit
		res = 0;
		for (i = 0; i < nibbles; i++)
		{
			n = ((acc >> (4*i)) & 0x0f) + ((m >> (4*i)) & 0x0f) + carry;
			if (i == nibbles - 1)
			{
				// V is conditioned from the result before the top digit's decimal adjust
				part = res | ((n & 0x0f) << (4*i));
				set_flag(FLAG_V, ((acc ^ part) & ~(acc ^ m) & sign) != 0);
			}
			if (n > 9)
				n += 6;
			carry = (n > 0x0f);
			res |= (n & 0x0f) << (4*i);
		}
		set_flag(FLAG_C, carry);
	}
	else
	{
		// BCD subtract, digit by digit (V keeps its binary value)
		res = 0;
		borrow = !carry;
		for (i = 0; i < nibbles; i++)
		{
			int dn = (int)((acc >> (4*i)) & 0x0f) - (int)((m >> (4*i)) & 0x0f) - borrow;
			borrow = (dn < 0);
			if (borrow)
				dn -= 6;
			res |= ((unsigned)dn & 0x0f) << (4*i);
		}
		set_flag(FLAG_C, !borrow);
	}

	set_nz(res, is8);
	return res;
}

static void opc_adcsbccmp(int amod)
{
	int op;
	union reg *r = &a;
	int is8;
	unsigned acc, m, res;

	// decide which instruction this is
	switch (opcload)
	{
		case 0xc0: case 0xc4: case 0xcc: r = &y; op = ALU_CMP; break; // CPY
		case 0xe0: case 0xe4: case 0xec: r = &x; op = ALU_CMP; break; // CPX
		default:
			switch (opcload >> 5) // bits 7-5 pick the operation within the standard ALU opcode group
			{
				case 3: op = ALU_ADC; break;
				case 7: op = ALU_SBC; break;
				default: op = ALU_CMP; break; // 6
			}
			break;
	}
	is8 = (r == &a) ? acc8() : idx8();

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	acc = is8 ? r->l : r->x;
	m = is8 ? work.l : work.x;
	res = alu(op, acc, m, is8);
	if (op != ALU_CMP)
	{
		if (is8)
			a.l = (unsigned char)res;
		else
			a.x = (unsigned short)res;
	}
	addr_cycles(amod, CYC_READ, is8);
}

static void opc_bit(int amod)
{
	int is8 = acc8();
	unsigned m, acc;

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	m = is8 ? work.l : work.x;
	acc = is8 ? a.l : a.x;
	if (amod != IMMEDIATE) // BIT #imm only affects Z
	{
		set_flag(FLAG_V, (m & (is8 ? 0x40 : 0x4000)) != 0); // V = bit 6/14 of memory
		set_flag(FLAG_N, (m & (is8 ? 0x80 : 0x8000)) != 0); // N = bit 7/15 of memory
	}
	set_flag(FLAG_Z, (m & acc) == 0);
	addr_cycles(amod, CYC_READ, is8);
}

static void opc_trbtsb(int amod)
{
	int is8 = acc8();
	unsigned m, acc;

	inc_pc(1);
	fetch(amod, is8 ? 8 : 16);
	m = is8 ? work.l : work.x;
	acc = is8 ? a.l : a.x;
	set_flag(FLAG_Z, (m & acc) == 0);
	if (opcload & 0x10)
		m &= ~acc; // TRB: 14,1c
	else
		m |= acc; // TSB: 04,0c
	store_work(amod, (unsigned short)m, is8);
	addr_cycles(amod, CYC_RMW, is8);
}
