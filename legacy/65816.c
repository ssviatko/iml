#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MEMSIZE 0x040000 // lets go with 256k
#define ROMSTART 0xe000 // rom start address
#define ROMSIZE 0x2000 // rom size
#define PERSISTENTSTART 0xc000 // start of persistent area
#define PERSISTENTSIZE 0x2000 // size of persistent area

// addressing mode codes
enum { 
	IMPLIED,
	IMMEDIATE,
	ABSOLUTE,
	ABSOLUTELONG,
	ACCUMULATOR,
	BRA, BCC, BCS, BEQ, BNE, BMI, BPL, BVC, BVS, BRLPER,
	DIRECT,
	DIRECTINDEXEDX,
	DIRECTINDEXEDY,
	ABSOLUTEINDEXEDX,
	ABSOLUTEINDEXEDY,
	ABSOLUTELONGINDEXEDX,
	DIRECTINDIRECT,
	DIRECTINDIRECTLONG,
	DIRECTINDEXEDINDIRECTX,
	DIRECTINDIRECTINDEXEDY,
	DIRECTINDIRECTLONGINDEXEDY,
	STACKRELATIVE,
	STACKINDIRECTINDEXEDY,
	ABSOLUTEINDIRECT, // JMP ($abs)
	ABSOLUTEINDEXEDINDIRECT, // JMP or JSR ($abs,X)
	ABSOLUTEINDIRECTLONG // JML [$abs]
};

// forward declarations for opcode handler functions
void inval_op(int amod);
void opc_asl(int amod);
void opc_rol(int amod);
void opc_ror(int amod);
void opc_clc(int amod);
void opc_clv(int amod);
void opc_cld(int amod);
void opc_sec(int amod);
void opc_sed(int amod);
void opc_sei(int amod);
void opc_cli(int amod);
void opc_lsr(int amod);
void opc_sta(int amod);
void opc_stxy(int amod);
void opc_lda(int amod);
void opc_ldxy(int amod);
void opc_rep(int amod);
void opc_nop(int amod);
void opc_stp(int amod);
void opc_sep(int amod);
void opc_xce(int amod);
void opc_bxx(int amod);
void opc_incdec(int amod);
void opc_inxydexy(int amod);
void opc_xfer(int amod);
void opc_logic(int amod);
void opc_pea(int amod);
void opc_pei(int amod);
void opc_push(int amod);
void opc_pop(int amod);
void opc_jmpjsr(int amod);
void opc_return(int amod);
void opc_adcsbccmp(int amod);
void opc_bit(int amod);
void opc_trbtsb(int amod);
void opc_wdm(int amod);
void opc_wai(int amod);
void opc_brlper(int amod);

// declarations for opcode table
typedef void (*ptr_to_opc)(int amod); // typedef for opcode pointers
ptr_to_opc opc[256] = { NULL }; // opcode function pointer table
int opcamod[256]; // address modes

// memory
unsigned char mem[MEMSIZE];

// registers
union reg {
	unsigned short x;
	struct {
		unsigned char l;
		unsigned char h;
	};
};

union reg a,x,y,s,d,pc; // A, X, Y, Stack, Direct
unsigned char p,b,k; // PSR, Data Bank, Program Bank
unsigned char e; // emulation mode "hidden bit"
union reg work; // internal work register
unsigned char wb_b; // writeback bank (fetch/writeback)
union reg wb_a; // writeback address (fetch/writeback)
unsigned char im_b; // intermediate bank
union reg im_a; // intermediate address

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

union longaddr la,savela; // for long address calculation
int boundcross; // flag for page boundary crossings
int halfcarry; // half carry for BCD functions

// utility
unsigned char traceflag = 0; // trace mode
int halt = 0; // halts execution when = 1; STP instruction sets this
long cycles = 0; // clock cycle counter
unsigned char opcload; // currently executing instruction

// memory and I/O read/write engine
void wsoftswitch(unsigned short address,unsigned char value)
{
	switch (address)
	{
		case 0xe000: // TRACEFLG
			traceflag = value;
			break;
	}
}

unsigned char rsoftswitch(unsigned short address)
{
	switch (address)
	{
		case 0xe000: // TRACEFLG
			return traceflag;
			break;
		default:
			return 0;
			break;
	}
}

unsigned char rmem(unsigned char bank,unsigned short address)
{
	if ((bank == 0) && ((address >= 0xe000) && (address <= 0xe0ff)))
		rsoftswitch(address);
	else
	{
		if (((bank*65536)+address) < MEMSIZE)
			return mem[(bank*65536)+address];
		else
			return 0;
	}
}

void wmem(unsigned char bank,unsigned short address,unsigned char value)
{
	if (traceflag)
		printf("W%02X/%04X=%02X ",bank,address,value);

	if ((bank == 0) && ((address >= 0xe000) && (address <= 0xe0ff)))
		wsoftswitch(address,value);
	else if (((bank*65536)+address) < MEMSIZE)
		mem[(bank*65536)+address] = value;
}

void inc_pc(int howmuch)
{
	pc.x+=howmuch;
	pc.x%=0x10000;
}

void writeback(int amod,int size) // write back work register to wb_b/wb_a.x
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

void fetch(int amod,int size)
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
			work.l = rmem(wb_b,wb_a.x);
			if (size==16)
			{
				im_b = wb_b; // don't destroy the writeback address
				im_a.x = wb_a.x;
				im_a.x++;
				if (im_a.x == 0)
					im_b++; // wrap around to next bank if wb_a is $FFFF
				work.h = rmem(im_b,im_a.x);
			}
			else
				work.h = 0;
			break;
		case DIRECT: // dp
		case DIRECTINDEXEDX: // dp,X
		case DIRECTINDEXEDY: // dp,Y
			wb_b = 0; // direct page is always in bank 0
			wb_a.h = 0; // assume e=1 for now
			wb_a.l = rmem(k,pc.x);
			inc_pc(1);
			if (e==0)
				wb_a.x += d.x;
			if ((amod == DIRECTINDEXEDX) || (amod == DIRECTINDEXEDY))
			{
				if (amod == DIRECTINDEXEDX)
					im_a.x = x.x; // DIRECTINDEXEDX
				else
					im_a.x = y.x; // DIRECTINDEXEDY
				if (e==1)
				{
					// in emulation mode, use 8-bit offset and wrap to beginning of page
					wb_a.l += im_a.l;
				}
				else
				{
					if ((p & 0x10) == 0x10) // if e==0 and 8-bit indexes, then..
						wb_a.x += im_a.l; // add x.l or y.l to the whole thing and span pages
					else
						wb_a.x += im_a.x; // if e==0 and 16 bit indexes, add and wrap to beginning of bank 0
				}
			}
			work.l = rmem(0,wb_a.x);
			if (size==16)
				work.h = rmem(0,wb_a.x + 1); //will wrap to 00/0000 because wb_a.x is a short
			else
				work.h = 0;
			break;
		case DIRECTINDEXEDINDIRECTX: // (dp,X)
			// get location of address on direct page
			im_b = 0; // direct page is always in bank 0
			im_a.h = 0; // assume e=1 for now
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			if (e == 0)
			{
				im_a.x += d.x;
				im_a.x += x.x; // add X to get location of address
			}
			else // emulation mode
				im_a.l += x.l; // add low byte of X to get location of address
			wb_a.l = rmem(0,im_a.x); // get low byte of address
			if (e == 0)
				im_a.x++; // in native mode, do 16-bit increment
			else
				im_a.l++; // else, just increment the low byte, wrapping to beginning of page
			wb_a.h = rmem(0,im_a.x); // get high byte of address
			wb_b = b; // assume DBR
			work.l = rmem(wb_b,wb_a.x); // get byte at address
			if (size == 16)
				work.h = rmem(wb_b,wb_a.x + 1); // don't wrap banks
			else
				work.h = 0;
			break;
		case DIRECTINDIRECT: // (dp)
		case DIRECTINDIRECTLONG: // [dp]
		case DIRECTINDIRECTINDEXEDY: // (dp),Y
		case DIRECTINDIRECTLONGINDEXEDY: // [dp],Y
			// get location of address on direct page
			im_b = 0; // direct page is always in bank 0
			im_a.h = 0; // assume e=1 for now
			im_a.l = rmem(k,pc.x);
			inc_pc(1);
			if (e == 0)
				im_a.x += d.x;
			wb_a.l = rmem(0,im_a.x); // get low byte of address
			if (e == 0)
				im_a.x++; // in native mode, do 16-bit increment
			else
				im_a.l++; // else, just increment the low byte, wrapping to beginning of page
			wb_a.h = rmem(0,im_a.x); // get high byte of address
			if ((amod == DIRECTINDIRECT) || (amod == DIRECTINDIRECTINDEXEDY))
			{
				wb_b = b; // assume DBR for DIRECTINDIRECT and DIRECTINDIRECTINDEXEDY
			}
			else
			{
				if (e == 0)
					im_a.x++;
				else
					im_a.l++;
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
			work.l = rmem(wb_b,wb_a.x);
			if (size == 16)
			{
				im_b = wb_b; // don't destroy the writeback address
				im_a.x = wb_a.x;
				im_a.x++;
				if (im_a.x == 0)
					im_b++; // wrap around to next bank if wb_a is $FFFF
				work.h = rmem(im_b,im_a.x);
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
				work.l = rmem(wb_b,wb_a.x); // get the byte off the stack
				if (size == 16)
					work.h = rmem(wb_b,wb_a.x + 1); // don't wrap banks
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
				work.l = rmem(wb_b,wb_a.x);
				if (size == 16)
				{
					im_b = wb_b; // don't destroy the writeback address
					im_a.x = wb_a.x;
					im_a.x++;
					if (im_a.x == 0)
						im_b++; // wrap around to next bank if wb_a is $FFFF
					work.h = rmem(im_b,im_a.x);
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
			wb_a.l = rmem(k,im_a.x);
			wb_a.h = rmem(k,im_a.x + 1);
			wb_b = rmem(k,im_a.x + 2);
			break;
		default:
			printf("fatal: undefined addressing mode %d in fetch.\n",amod);
			exit(1);
			break;
	}
}

void initops(void)
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
	// missing: 00,02,40,44,54 (BRK, COP, RTI, MVN, MVP)
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
	opc[0x18] = &opc_clc;		opcamod[0x18] = IMPLIED;			// CLC
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
	opc[0x38] = &opc_sec;		opcamod[0x38] = IMPLIED;			// SEC
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
	opc[0x58] = &opc_cli;		opcamod[0x58] = IMPLIED;			// CLI
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
	opc[0x78] = &opc_sei;		opcamod[0x78] = IMPLIED;			// SEI
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
	opc[0xb8] = &opc_clv;		opcamod[0xb8] = IMPLIED;			// CLV
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
	opc[0xd8] = &opc_cld;		opcamod[0xd8] = IMPLIED;			// CLD
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
	opc[0xf8] = &opc_sed;		opcamod[0xf8] = IMPLIED;			// SED
	opc[0xf9] = &opc_adcsbccmp;	opcamod[0xf9] = ABSOLUTEINDEXEDY;		// SBC $abs,Y
	opc[0xfa] = &opc_pop;		opcamod[0xfa] = IMPLIED;			// PLX
	opc[0xfb] = &opc_xce;		opcamod[0xfb] = IMPLIED;			// XCE
	opc[0xfc] = &opc_jmpjsr;	opcamod[0xfc] = ABSOLUTEINDEXEDINDIRECT;	// JSR ($abs,X)
	opc[0xfd] = &opc_adcsbccmp;	opcamod[0xfd] = ABSOLUTEINDEXEDX;		// SBC $abs,X
	opc[0xfe] = &opc_incdec;	opcamod[0xfe] = ABSOLUTEINDEXEDX;		// INC $abs,X
	opc[0xff] = &opc_adcsbccmp;	opcamod[0xff] = ABSOLUTELONGINDEXEDX;		// SBC $abslong,X
}

void push(unsigned char topush)
{
	wmem(0,s.x,topush);
	s.x--;
	if (e==1)
		if (s.x==0x00ff)
			s.x=0x1ff; // wrap the stack if in emulation mode
}

void push16(unsigned short topush)
{
	union reg temp;

	temp.x = topush;
	push(temp.h);
	push(temp.l);
}

unsigned char pop(void)
{
	s.x++;
	if (e==1)
		if (s.x==0x200)
			s.x=0x100; // wrap the stack if in emulation mode
	return rmem(0,s.x);
}

unsigned short pop16(void)
{
	union reg temp;

	temp.l=pop();
	temp.h=pop();

	return temp.x;
}

void reset(void)
{
	s.x=0x1ff; // stack to default
	d.x=0; // direct reg to zero page
	p=0x30; // PSR clear, unimplemented bit set, break bit set
	e=1; // hidden bit 1
	pc.x=(mem[0xfffd]*256)+mem[0xfffc]; // set PC to reset address
	b=0; // data bank to 0
	k=0; // program bank to 0
}

void show_trace(void)
{
	printf("A=%04X X=%04X Y=%04X S=%04X D=%04X P=%02X B=%02X e=%d cyc=%ld\n",a.x,x.x,y.x,s.x,d.x,p,b,e,cycles);
}

void disass(void)
{
	printf("%02X/%04X: %02X %02X%02X%02X ",k,pc.x,rmem(k,pc.x),rmem(k,pc.x+1),rmem(k,pc.x+2),rmem(k,pc.x+3));
}

int main(int argc, char **argv)
{
	FILE *rom,*core;
	int i;

	initops();

	// check shell flags
	if (argc > 1)
		if (strcmp(argv[1],"-t")==0)
			traceflag++;

	// zero memory
	for (i=0; i<MEMSIZE; i++)
		mem[i]=0;

	// load ROM
	if ((rom=fopen("rom.o","r")) == NULL)
	{
		perror("Cannot open ROM file.\nA file named \"rom.o\" must exist in this directory.\n");
		exit(1);
	}
	if (fread(mem+ROMSTART,1,ROMSIZE,rom)!=ROMSIZE)
	{
		perror("Cannot read ROM file. It may be corrupted.\n");
		exit(1);
	}
	fclose(rom);

	// load persistent area of core file
	if ((core=fopen("core","r")) == NULL)
		printf("Warning: cannot load persistent memory from core file.\n");
	else
	{
		fseek(core,PERSISTENTSTART,SEEK_SET);
		if (fread(mem+PERSISTENTSTART,1,PERSISTENTSIZE,core)!=PERSISTENTSIZE)
			printf("Warning: cannot read core file. It may be corrupted.\n");
		fclose(core);
	}

	// initiate reset cycle
	reset();

	// start executing at PC
	while (!halt)
	{
		if (traceflag) disass();
		opcload=rmem(k,pc.x);
		opc[opcload](opcamod[opcload]);
		if (traceflag) show_trace();
	}
	printf("Executed %ld cycles.\n",cycles);

	// dump core
	if ((core=fopen("core","w")) == NULL)
	{
		perror("Cannot open core file for writing.\n");
		exit(1);
	}
	if (fwrite(mem,1,MEMSIZE,core)!=MEMSIZE)
	{
		perror("Cannot write core file.\n");
		exit(1);
	}
	fclose(core);

	return 0;
}

/*
Handler routines for opcodes

These are loaded up and called by pointer via the opcode table.
*/

void inval_op(int amod)
{
	inc_pc(1);
	cycles += 2;
}

void opc_wdm(int amod)
{
	// WDM is currently unimplemented and acts like a NOP.
	inc_pc(1);
	cycles += 2;
}

void opc_wai(int amod)
{
	// interrupts currently unimplemented - add 3 cycs and continue.
	inc_pc(1);
	cycles += 3;
}

void opc_jmpjsr(int amod)
{
	inc_pc(1);
	fetch(amod,16);
	switch(opcload)
	{
		case 0x20: // JSR $abs
			push16(pc.x - 1);
			pc.x = wb_a.x;
			cycles += 6;
			break;
		case 0x22: // JSL $abslong
			push(k);
			push16(pc.x - 1);
			k = wb_b;
			pc.x = wb_a.x;
			cycles += 8;
			break;
		case 0x4c: // JMP $abs
			pc.x = wb_a.x;
			cycles += 3;
			break;
		case 0x5c: // JML $abslong
			k = wb_b;
			pc.x = wb_a.x;
			cycles += 4;
			break;
		case 0x6c: // JMP ($abs)
			pc.x = wb_a.x;
			cycles += 5;
			break;
		case 0x7c: // JMP ($abs,X)
			pc.x = wb_a.x;
			cycles += 6;
			break;
		case 0xdc: // JMP [$abslong]
			pc.x = wb_a.x;
			k = wb_b;
			cycles += 6;
			break;
		case 0xfc: // JSR ($abs,X)
			push16(pc.x - 1);
			pc.x = wb_a.x;
			cycles += 8;
			break;
	}
}

void opc_return(int amod)
{
	pc.x = pop16();
	pc.x++;
	if (opcload==0x6b)
		k=pop(); // pop k if this is RTL
	cycles += 6; // both types run 6 cycles
}

void opc_pei(int amod)
{
	// Note: This instruction is advertised as Direct Indirect, but the way it behaves,
	// it is actually just Direct. It pushes the 16-bit contents of the DP location.
	inc_pc(1);
	fetch(amod,16);
	push16(work.x);
	cycles += 6;
	if (d.l != 0)
		cycles++; // extra cycles if dp is not page aligned
}

void opc_pea(int amod)
{
	inc_pc(1);
	fetch(amod,16);
	push16(wb_a.x);
	cycles += 5;
}

void opc_push(int amod)
{
	inc_pc(1);
	switch(opcload)
	{
		case 0x48: // PHA
			if ((e==1) || ((e==0) && ((p & 0x20)==0x20)))
			{
				push(a.l);
				cycles += 3;
			}
			else
			{
				push16(a.x);
				cycles += 4;
			}
			break;
		case 0xda: // PHX
			if ((e==1) || ((e==0) && ((p & 0x10)==0x10)))
			{
				push(x.l);
				cycles += 3;
			}
			else
			{
				push16(x.x);
				cycles += 4;
			}
			break;
		case 0x5a: // PHY
			if ((e==1) || ((e==0) && ((p & 0x10)==0x10)))
			{
				push(y.l);
				cycles += 3;
			}
			else
			{
				push16(y.x);
				cycles += 4;
			}
			break;
		case 0x08: // PHP
			push(p);
			cycles += 3;
			break;
		case 0x8b: // PHB
			push(b);
			cycles += 3;
			break;
		case 0x0b: // PHD
			push16(d.x);
			cycles += 4;
			break;
		case 0x4b: // PHK
			push(k);
			cycles += 3;
			break;
	}
}

void opc_pop(int amod)
{
	inc_pc(1);
	switch(opcload)
	{
		case 0x68: // PLA
			if ((e==1) || ((e==0) && ((p & 0x20)==0x20)))
			{
				a.l=pop();
				cycles += 4;
				if (a.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				a.x=pop16();
				cycles += 5;
				if (a.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0xfa: // PLX
			if ((e==1) || ((e==0) && ((p & 0x10)==0x10)))
			{
				x.l=pop();
				cycles += 4;
				if (x.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				x.x=pop16();
				cycles += 5;
				if (x.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x7a: // PLY
			if ((e==1) || ((e==0) && ((p & 0x10)==0x10)))
			{
				y.l=pop();
				cycles += 4;
				if (y.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				y.x=pop16();
				cycles += 5;
				if (y.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x28: // PLP
			p=pop(); // conditions all flags, obviously
			cycles += 4;
			break;
		case 0xab: // PLB
			b=pop();
			cycles += 4;
			if (b==0)
				p |= 0x02;
			else
				p &= 0xfd;
			if (b > 127)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
		case 0x2b: // PLD
			d.x=pop16();
			cycles += 5;
			if (d.x==0)
				p |= 0x02;
			else
				p &= 0xfd;
			if (d.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
	}
}

void opc_xfer(int amod)
{
	inc_pc(1);

	switch(opcload)
	{
		case 0xaa: // TAX
			if ((e==1) || (((p & 0x10) == 0x10) && (e==0))) // 8-bit index regs?
			{
				x.l = a.l; // just transfer low byte
				if (x.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				x.x = a.x;
				if (x.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0xa8: // TAY
			if ((e==1) || (((p & 0x10) == 0x10) && (e==0))) // 8-bit index regs?
			{
				y.l = a.l; // just transfer low byte
				if (y.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				y.x = a.x;
				if (y.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x8a: // TXA
			if ((e==1) || (((p & 0x20) == 0x20) && (e==0))) // emulation mode, or native w/ m=1?
			{
				a.l = x.l; // just transfer low byte
				if (a.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else // native mode, m=0, x=?
			{
				a.l = x.l;
				if ((p & 0x10) == 0x10) // 8 bit index regs?
					a.h = 0; // just apply a 0 to a.h (B) then
				else // 16-16 transfer
					a.h = x.h;
				if (a.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x98: // TYA
			if ((e==1) || (((p & 0x20) == 0x20) && (e==0))) // emulation mode, or native w/ m=1?
			{
				a.l = y.l; // just transfer low byte
				if (a.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else // native mode, m=0, x=?
			{
				a.l = y.l;
				if ((p & 0x10) == 0x10) // 8 bit index regs?
					a.h = 0; // just apply a 0 to a.h (B) then
				else // 16-16 transfer
					a.h = y.h;
				if (a.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (a.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0xba: // TSX
			if ((e==1) || (((p & 0x10) == 0x10) && (e==0))) // 8-bit index regs?
			{
				x.l = s.l; // just transfer low byte
				if (x.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				x.x = s.x;
				if (x.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x9a: // TXS
			if ((e==1) || (((p & 0x20) == 0x20) && (e==0))) // emulation mode, or native w/ m=1?
			{
				s.l = x.l; // just transfer low byte
				if (s.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (s.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else // native mode, m=0, x=?
			{
				s.l = x.l;
				if ((p & 0x10) == 0x10) // 8 bit index regs?
					s.h = 0; // just apply a 0 to stack hi-byte then
				else // 16-16 transfer
					s.h = x.h;
				if (s.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (s.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x9b: // TXY
			if ((e==1) || (((p & 0x10) == 0x10) && (e==0))) // 8-bit index regs?
			{
				y.l = x.l;
				if (y.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				y.x = x.x;
				if (y.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (y.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0xbb: // TYX
			if ((e==1) || (((p & 0x10) == 0x10) && (e==0))) // 8-bit index regs?
			{
				x.l = y.l;
				if (x.l == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.l > 127)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			else
			{
				x.x = y.x;
				if (x.x == 0) // condition flags
					p |= 0x02;
				else
					p &= 0xfd;
				if (x.x > 32767)
					p |= 0x80;
				else
					p &= 0x7f;
			}
			break;
		case 0x5b: // TCD
			d.x = a.x;
			if (d.x == 0) // condition flags
				p |= 0x02;
			else
				p &= 0xfd;
			if (d.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
		case 0x7b: // TDC
			a.x = d.x;
			if (a.x == 0) // condition flags
				p |= 0x02;
			else
				p &= 0xfd;
			if (a.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
		case 0x1b: // TCS
			s.l = a.l; // only xfer low byte in emulation mode
			if (e==0)
				s.h = a.h;
			if (s.x == 0) // condition flags
				p |= 0x02;
			else
				p &= 0xfd;
			if (s.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
		case 0x3b: // TSC
			a.x = s.x;
			if (a.x == 0) // condition flags
				p |= 0x02;
			else
				p &= 0xfd;
			if (a.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
		case 0xeb: // XBA
			work.l = a.h;
			a.h = a.l;
			a.l = work.l;
			if (a.l == 0) // condition flags
				p |= 0x02;
			else
				p &= 0xfd;
			if (a.l > 127)
				p |= 0x80;
			else
				p &= 0x7f;
			break;
	}

	cycles+=2; // for all instructions
}

void opc_brlper(int amod)
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
			cycles += 6;
			break;
		case 0x82: // BRL
			pc.x += offset.x;
			cycles += 4;
			break;
	}
}

void opc_bxx(int amod)
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

	// move program counter if we take the branch
	if (taken)
		pc.x += offset.x;

	// compute clock cycles used
	cycles += 2; // will always use at least 2
	if (e==1)
		cycles++; // add one for emulation mode
	if (taken)
		cycles++; // add one if branch taken
}

void opc_clc(int amod)
{
	p &= 0xfe;
	inc_pc(1);
	cycles += 2;
}

void opc_clv(int amod)
{
	p &= 0xbf;
	inc_pc(1);
	cycles += 2;
}

void opc_cld(int amod)
{
	p &= 0xf7;
	inc_pc(1);
	cycles += 2;
}

void opc_cli(int amod)
{
	p &= 0xfb;
	inc_pc(1);
	cycles += 2;
}

void opc_sec(int amod)
{
	p |= 0x01;
	inc_pc(1);
	cycles += 2;
}

void opc_sed(int amod)
{
	p |= 0x08;
	inc_pc(1);
	cycles += 2;
}

void opc_sei(int amod)
{
	p |= 0x04;
	inc_pc(1);
	cycles += 2;
}

void opc_logic(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		fetch(amod,8);
		switch (opcload)
		{
			case 0x49:
			case 0x4d:
			case 0x4f:
			case 0x45:
			case 0x52:
			case 0x47:
			case 0x5d:
			case 0x5f:
			case 0x59:
			case 0x55:
			case 0x41:
			case 0x51:
			case 0x57:
			case 0x43:
			case 0x53:
				a.l ^= work.l; // EOR
				break;
			case 0x29:
			case 0x2d:
			case 0x2f:
			case 0x25:
			case 0x32:
			case 0x27:
			case 0x3d:
			case 0x3f:
			case 0x39:
			case 0x35:
			case 0x21:
			case 0x31:
			case 0x37:
			case 0x23:
			case 0x33:
				a.l &= work.l; // AND
				break;
			case 0x09:
			case 0x0d:
			case 0x0f:
			case 0x05:
			case 0x12:
			case 0x07:
			case 0x1d:
			case 0x1f:
			case 0x19:
			case 0x15:
			case 0x01:
			case 0x11:
			case 0x17:
			case 0x03:
			case 0x13:
				a.l |= work.l; // ORA
				break;
		}
		if (a.l == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (a.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
	}
	else
	{
		fetch(amod,16);
		switch (opcload)
		{
			case 0x49:
			case 0x4d:
			case 0x4f:
			case 0x45:
			case 0x52:
			case 0x47:
			case 0x5d:
			case 0x5f:
			case 0x59:
			case 0x55:
			case 0x41:
			case 0x51:
			case 0x57:
			case 0x43:
			case 0x53:
				a.x ^= work.x; // EOR
				break;
			case 0x29:
			case 0x2d:
			case 0x2f:
			case 0x25:
			case 0x32:
			case 0x27:
			case 0x3d:
			case 0x3f:
			case 0x39:
			case 0x35:
			case 0x21:
			case 0x31:
			case 0x37:
			case 0x23:
			case 0x33:
				a.x &= work.x; // AND
				break;
			case 0x09:
			case 0x0d:
			case 0x0f:
			case 0x05:
			case 0x12:
			case 0x07:
			case 0x1d:
			case 0x1f:
			case 0x19:
			case 0x15:
			case 0x01:
			case 0x11:
			case 0x17:
			case 0x03:
			case 0x13:
				a.x |= work.x; // ORA
				break;
		}
		if (a.x == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (a.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
	}
	// compute cycles
	switch (amod) {
		case IMMEDIATE:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 4;
			break;
		case ABSOLUTELONG:
			cycles += 5;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
		case ABSOLUTEINDEXEDY:
			cycles += 4;
			if (boundcross == 1)
				cycles++;
			break;
		case ABSOLUTELONGINDEXEDX:
			cycles += 5;
			break;
		case DIRECTINDIRECT:
		case DIRECTINDIRECTLONG:
		case DIRECTINDIRECTINDEXEDY:
		case DIRECTINDIRECTLONGINDEXEDY:
		case DIRECTINDEXEDINDIRECTX:
			cycles += 6;
			if ((amod == DIRECTINDIRECT) || (amod == DIRECTINDIRECTINDEXEDY))
				cycles--; // only 5 cycles for DIRECTINDIRECT and DIRECTINDIRECTINDEXEDY
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			if ((amod == DIRECTINDIRECTINDEXEDY) && (boundcross == 1))
				cycles++;
			break;
		case STACKRELATIVE:
			cycles += 4;
			break;
		case STACKINDIRECTINDEXEDY:
			cycles += 7;
			break;
	}
	if ((e==0) && ((p & 0x20) == 0))
		cycles++; // add 1 for 16 bit A
}

void opc_sta(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		fetch(amod,8); // set up writeback address
		switch(opcload)
		{
			case 0x64:
			case 0x74:
			case 0x9c:
			case 0x9e:
				work.l = 0; // STZ
				break;
			default:		
				work.l = a.l; // STA
				break;
		}
		writeback(amod,8);
	}
	else
	{
		fetch(amod,16);
		switch(opcload)
		{
			case 0x64:
			case 0x74:
			case 0x9c:
			case 0x9e:
				work.x = 0; // STZ
				break;
			default:		
				work.x = a.x; // STA
				break;
		}
		writeback(amod,16);
	}
	// compute cycles
	switch (amod) {
		case ABSOLUTE:
			cycles += 4;
			break;
		case ABSOLUTELONG:
			cycles += 5;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod == DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case DIRECTINDIRECT:
		case DIRECTINDIRECTLONG:
		case DIRECTINDIRECTINDEXEDY:
		case DIRECTINDIRECTLONGINDEXEDY:
		case DIRECTINDEXEDINDIRECTX:
			cycles += 6;
			if (amod == DIRECTINDIRECT)
				cycles--; // only 5 cycles for DIRECTINDIRECT
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
		case ABSOLUTEINDEXEDY:
		case ABSOLUTELONGINDEXEDX:
			cycles += 5;
			break;
		case STACKRELATIVE:
			cycles += 4;
			break;
		case STACKINDIRECTINDEXEDY:
			cycles += 7;
			break;
	}
	if ((e==0) && ((p & 0x20) == 0))
		cycles++; // add 1 for 16 bit A
}

void opc_stxy(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x10) == 0x10) && (e==0)))
	{
		fetch(amod,8); // set up writeback address
		switch (opcload)
		{
			case 0x86:
			case 0x8e:
			case 0x96:
				work.l = x.l; // STX
				break;
			case 0x84:
			case 0x8c:
			case 0x94:
				work.l = y.l; // STY
				break;
		}
		writeback(amod,8);
	}
	else
	{
		fetch(amod,16);
		switch (opcload)
		{
			case 0x86:
			case 0x8e:
			case 0x96:
				work.x = x.x; // STX
				break;
			case 0x84:
			case 0x8c:
			case 0x94:
				work.x = y.x; // STY
				break;
		}
		writeback(amod,16);
	}
	// compute cycles
	switch (amod) {
		case ABSOLUTE:
			cycles += 4;
			break;
		case DIRECT:
			cycles += 3;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case DIRECTINDEXEDX:
		case DIRECTINDEXEDY:
			cycles += 4;
			if (d.l != 0)
				cycles++;
			break;
	}
	if ((e==0) && ((p & 0x10) == 0))
		cycles++; // add 1 for 16 bit X
}

void opc_lsr(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,8);
		else
			work.l = a.l; // get data from A
		if ((work.l & 0x01) == 0x01)
			p |= 0x01; // set carry to last bit
		else
			p &= 0xfe;
		work.l >>= 1; // and shift it right
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (amod!=ACCUMULATOR)
			writeback(amod,8); // put data back in memory
		else
			a.l = work.l; // put A back
	}
	else
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,16);
		else
			work.x = a.x; // get data from A
		if ((work.x & 0x0001) == 0x0001)
			p |= 0x01; // set carry to last bit
		else
			p &= 0xfe;
		work.x >>= 1; // and shift it right
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (amod!=ACCUMULATOR)
			writeback(amod,16); // put data back in memory
		else
			a.x = work.x; // put A back
	}
	p &= 0x7f; // clear n flag no matter what

	// compute cycles
	switch (amod) {
		case ACCUMULATOR:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 5;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 7;
			break;
	}
	if (((e==0) && ((p & 0x20) == 0)) && (amod != ACCUMULATOR))
		cycles++; // add 1 for 16 bit A
}

void opc_asl(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,8);
		else
			work.l = a.l; // get data from A
		if ((work.l & 0x80) == 0x80)
			p |= 0x01; // set carry to bit 7
		else
			p &= 0xfe;
		work.l <<= 1; // and shift it left
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,8); // put data back in memory
		else
			a.l = work.l; // put A back
	}
	else
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,16);
		else
			work.x = a.x; // get data from A
		if ((work.x & 0x8000) == 0x8000)
			p |= 0x01; // set carry to bit 15
		else
			p &= 0xfe;
		work.x <<= 1; // and shift it left
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,16); // put data back in memory
		else
			a.x = work.x; // put A back
	}

	// compute cycles
	switch (amod) {
		case ACCUMULATOR:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 5;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 7;
			break;
	}
	if (((e==0) && ((p & 0x20) == 0)) && (amod != ACCUMULATOR))
		cycles++; // add 1 for 16 bit A
}

void opc_ror(int amod)
{
	int savecarry;

	inc_pc(1);
	savecarry=(p & 0x01);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,8);
		else
			work.l = a.l; // get data from A
		if ((work.l & 0x01) == 0x01)
			p |= 0x01; // set carry to bit 0
		else
			p &= 0xfe;
		work.l >>= 1; // and shift it right
		if (savecarry)
			work.l |= 0x80;
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,8); // put data back in memory
		else
			a.l = work.l; // put A back
	}
	else
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,16);
		else
			work.x = a.x; // get data from A
		if ((work.x & 0x0001) == 0x0001)
			p |= 0x01; // set carry to bit 0
		else
			p &= 0xfe;
		work.x >>= 1; // and shift it right
		if (savecarry)
			work.x |= 0x8000;
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,16); // put data back in memory
		else
			a.x = work.x; // put A back
	}

	// compute cycles
	switch (amod) {
		case ACCUMULATOR:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 5;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 7;
			break;
	}
	if (((e==0) && ((p & 0x20) == 0)) && (amod != ACCUMULATOR))
		cycles++; // add 1 for 16 bit A
}

void opc_rol(int amod)
{
	int savecarry;

	inc_pc(1);
	savecarry=(p & 0x01);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,8);
		else
			work.l = a.l; // get data from A
		if ((work.l & 0x80) == 0x80)
			p |= 0x01; // set carry to bit 7
		else
			p &= 0xfe;
		work.l <<= 1; // and shift it left
		if (savecarry)
			work.l |= 0x01; // set bit 0 of low byte if carry was set
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,8); // put data back in memory
		else
			a.l = work.l; // put A back
	}
	else
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,16);
		else
			work.x = a.x; // get data from A
		if ((work.x & 0x8000) == 0x8000)
			p |= 0x01; // set carry to bit 15
		else
			p &= 0xfe;
		work.x <<= 1; // and shift it left
		if (savecarry)
			work.x |= 0x0001; // set bit 0 of low byte if carry was set
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,16); // put data back in memory
		else
			a.x = work.x; // put A back
	}

	// compute cycles
	switch (amod) {
		case ACCUMULATOR:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 5;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 7;
			break;
	}
	if (((e==0) && ((p & 0x20) == 0)) && (amod != ACCUMULATOR))
		cycles++; // add 1 for 16 bit A
}

void opc_lda(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		fetch(amod,8);
		if (work.l == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		a.l = work.l;
	}
	else
	{
		fetch(amod,16);
		if (work.x == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		a.x = work.x;
	}
	// compute cycles
	switch (amod) {
		case IMMEDIATE:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 4;
			break;
		case ABSOLUTELONG:
			cycles += 5;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
		case ABSOLUTEINDEXEDY:
			cycles += 4;
			if (boundcross == 1)
				cycles++;
			break;
		case ABSOLUTELONGINDEXEDX:
			cycles += 5;
			break;
		case DIRECTINDIRECT:
		case DIRECTINDIRECTLONG:
		case DIRECTINDIRECTINDEXEDY:
		case DIRECTINDIRECTLONGINDEXEDY:
		case DIRECTINDEXEDINDIRECTX:
			cycles += 6;
			if ((amod == DIRECTINDIRECT) || (amod == DIRECTINDIRECTINDEXEDY))
				cycles--; // only 5 cycles for DIRECTINDIRECT and DIRECTINDIRECTINDEXEDY
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			if ((amod == DIRECTINDIRECTINDEXEDY) && (boundcross == 1))
				cycles++;
			break;
		case STACKRELATIVE:
			cycles += 4;
			break;
		case STACKINDIRECTINDEXEDY:
			cycles += 7;
			break;
	}
	if ((e==0) && ((p & 0x20) == 0))
		cycles++; // add 1 for 16 bit A
}

void opc_ldxy(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x10) == 0x10) && (e==0)))
	{
		fetch(amod,8);
		if (work.l == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		switch (opcload)
		{
			case 0xa2:
			case 0xa6:
			case 0xae:
			case 0xb6:
			case 0xbe: // LDX
				x.l = work.l;
				break;
			case 0xa0:
			case 0xa4:
			case 0xac:
			case 0xb4:
			case 0xbc: // LDY
				y.l = work.l;
				break;
		}
	}
	else
	{
		fetch(amod,16);
		if (work.x == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		switch (opcload)
		{
			case 0xa2:
			case 0xa6:
			case 0xae:
			case 0xb6:
			case 0xbe: // LDX
				x.x = work.x;
				break;
			case 0xa0:
			case 0xa4:
			case 0xac:
			case 0xb4:
			case 0xbc: // LDY
				y.x = work.x;
				break;
		}
	}
	// compute cycles
	switch (amod) {
		case IMMEDIATE:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 4;
			break;
		case DIRECT:
			cycles += 3;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
		case ABSOLUTEINDEXEDY:
			cycles += 4;
			if (boundcross == 1)
				cycles++;
			break;
		case DIRECTINDEXEDX:
		case DIRECTINDEXEDY:
			cycles += 4;
			if (d.l != 0)
				cycles++;
			break;
	}
	if ((e==0) && ((p & 0x10) == 0))
		cycles++; // add 1 for 16 bit A
}

void opc_inxydexy(int amod)
{
	inc_pc(1);

	if ((e==1) || (((p & 0x10) == 0x10) && (e==0)))
	{
		if ((opcload == 0xe8) || (opcload == 0xca)) // X
		{
			if (opcload == 0xe8) // INX
				x.l++;
			else // DEX
				x.l--;
			work.l = x.l;
		}
		else // Y
		{
			if (opcload == 0xc8) // INY
				y.l++;
			else // DEY
				y.l--;
			work.l = y.l;
		}
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127) // condition negative flag
			p |= 0x80;
		else
			p &= 0x7f;
	}
	else
	{
		if ((opcload == 0xe8) || (opcload == 0xca)) // X
		{
			if (opcload == 0xe8) // INX
				x.x++;
			else // DEX
				x.x--;
			work.x = x.x;
		}
		else // Y
		{
			if (opcload == 0xc8) // INY
				y.x++;
			else // DEY
				y.x--;
			work.x = y.x;
		}
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767) // condition negative flag
			p |= 0x80;
		else
			p &= 0x7f;
	}
	cycles+=2; // for all 4 instructions
}

void opc_incdec(int amod)
{
	inc_pc(1);

	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,8);
		else
			work.l = a.l; // get data from A
		if (((opcload & 0xf0) == 0x30) ||
		    ((opcload & 0xf0) == 0xc0) ||
		    ((opcload & 0xf0) == 0xd0))
			work.l--; // DEC if opcode is 3a,c6,ce,d6 or de
		else if (((opcload & 0xf0) == 0x10) ||
			 ((opcload & 0xf0) == 0xe0) ||
			 ((opcload & 0xf0) == 0xf0))
			work.l++; // INC if opcode is 1a,e6,ee,f6 or fe
		else
		{
			perror("fatal: inc/dec instruction: unexpected opcode.\n");
			exit(1);
		}
		if (work.l == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,8); // put data back in memory
		else
			a.l = work.l; // put A back
	}
	else
	{
		if (amod!=ACCUMULATOR) // get data from memory if not LSR A		
			fetch(amod,16);
		else
			work.x = a.x; // get data from A
		if (((opcload & 0xf0) == 0x30) ||
		    ((opcload & 0xf0) == 0xc0) ||
		    ((opcload & 0xf0) == 0xd0))
			work.x--; // DEC
		else if (((opcload & 0xf0) == 0x10) ||
			 ((opcload & 0xf0) == 0xe0) ||
			 ((opcload & 0xf0) == 0xf0))
			work.x++; // INC if opcode is 1a,e6,ee,f6 or fe
		else
		{
			perror("fatal: inc/dec instruction: unexpected opcode.\n");
			exit(1);
		}
		if (work.x == 0) // condition Z flag
			p |= 0x02;
		else
			p &= 0xfd;
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		if (amod!=ACCUMULATOR)
			writeback(amod,16); // put data back in memory
		else
			a.x = work.x; // put A back
	}

	// compute cycles
	switch (amod) {
		case ACCUMULATOR:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 7;
			break;
	}
	if (((e==0) && ((p & 0x20) == 0)) && (amod!=ACCUMULATOR))
		cycles++; // add 1 for 16 bit A
}

void opc_rep(int amod)
{
	inc_pc(1);
	fetch(amod,8);
	work.l = ~work.l; // negate to make AND mask
	p &= work.l;
	cycles += 3;
}

void opc_sep(int amod)
{
	inc_pc(1);
	fetch(amod,8);
	p |= work.l;
	cycles += 3;
}

void opc_stp(int amod)
{
	halt = 1;
	inc_pc(1);
}

void opc_nop(int amod)
{
	inc_pc(1);
	cycles += 2;
}

void opc_xce(int amod)
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
	}
	inc_pc(1);
	cycles += 2;
}

unsigned char bcdadd(int carry,unsigned char a1,unsigned char a2)
{
	// add nibbles:
	// a1+a2+carry, if result is >=10, subtract 10 and pass on carry
	unsigned char sum;

	sum = (a1 & 0x0f) + (a2 & 0x0f) + carry;
	if (sum >= 10)
	{
		sum -= 10;
		halfcarry = 1;
	}
	else
		halfcarry = 0;

	return (sum & 0x0f);
}

unsigned char bcdsubtract(int carry,unsigned char a1,unsigned char a2)
{
	// subtract nibbles:
	// a1-a2-~carry, if result is < 0, roll over from 9 down.
	// if result is < -10, roll over from F down.
	char sum;

	sum = (a1 & 0x0f) - (a2 & 0x0f) - ((carry & 0x01) ^ 0x01);
	if (sum <= -10)
	{
		sum = 16 + (sum + 10); // roll back from F
		halfcarry = 0;
	}
	else if ((sum < 0) && (sum > -10))
	{
		sum = 10 + sum; // roll back from 9
		halfcarry = 0;
	}
	else
		halfcarry = 1;

	return (sum & 0x0f);
}

void opc_adcsbccmp(int amod)
{
	int subtracting = 0; // set to 1 if we are subtracting
	int comparing = 0; // set to 1 if we are comparing
	int cpx = 0, cpy = 0; // set to 1 if a CPX or CPY instruction is executing
	inc_pc(1);
	union longaddr lw;
	union reg savea; // to save A during compare operations
	unsigned char n0,n1,n2,n3; // nibbles for BCD calculations
	
	lw.xx = 0; // for arithmetic calculations

	switch(opcload) // are we adding, subtracting or comparing?
	{
		case 0xe9:
		case 0xed:
		case 0xef:
		case 0xe5:
		case 0xf2:
		case 0xe7:
		case 0xfd:
		case 0xff:
		case 0xf9:
		case 0xf5:
		case 0xe1:
		case 0xf1:
		case 0xf7:
		case 0xe3:
		case 0xf3:
			subtracting++; // all the SBC's
			break;
		case 0xc9:
		case 0xcd:
		case 0xcf:
		case 0xc5:
		case 0xd2:
		case 0xc7:
		case 0xdd:
		case 0xdf:
		case 0xd9:
		case 0xd5:
		case 0xc1:
		case 0xd1:
		case 0xd7:
		case 0xc3:
		case 0xd3:
			comparing++; // all the CMP's
			subtracting++; // compares are really subtractions
			break;
		case 0xe0:
		case 0xec:
		case 0xe4:
			cpx++; // all the CPX's
			comparing++;
			subtracting++;
			break;
		case 0xc0:
		case 0xcc:
		case 0xc4:
			cpy++; // all the CPY's
			comparing++;
			subtracting++;
			break;
	}

	// save A if we are doing a compare operation
	if (comparing)
	{
		savea.x = a.x;
		if (cpx)
			a.x = x.x; // load A temporarily with index register
		if (cpy)
			a.x = y.x;
	}

	if ((((e==1) || (((p & 0x20) == 0x20) && (e==0))) && !(cpx || cpy)) || (((e==1) || (((p & 0x10) == 0x10) && (e==0))) && (cpx || cpy)))
	/* explanation of this logic:
		if {
			{
				emulation mode OR
				native mode AND 8-bit M
			} AND {
				NOT cpx OR cpy instruction executing
		} OR {
			{
				emulation mode OR
				native mode AND 8-bit X
			} AND {
				cpx OR cpy instruction executing
			}
		}
	simple, no? */
	{
		fetch(amod,8);
		if (((p & 0x08) == 0x08) && (!comparing))
		{
			// SED active? decimal mode
			if (subtracting)
			{
				n0 = bcdsubtract((p & 0x01),(a.l & 0x0f),(work.l & 0x0f));
				n1 = bcdsubtract(halfcarry,(a.l >> 4),(work.l >> 4));
				a.l = n0;
				a.l += (n1 * 16);
			}
			else
			{
				n0 = bcdadd((p & 0x01),(work.l & 0x0f),(a.l & 0x0f)); // add low nibble
				n1 = bcdadd(halfcarry,(work.l >> 4),(a.l >> 4)); // add high nibble
				a.l = n0;
				a.l += (n1 * 16);
			}
			if (halfcarry) // condition carry
				p |= 0x01;
			else
				p &= 0xfe;
			// condition n
			if (a.l > 127)
				p |= 0x80;
			else
				p &= 0x7f;
			// condition z
			if (a.l == 0)
				p |= 0x02;
			else
				p &= 0xfd;
		}
		else
		{
			// CLD - binary mode
			lw.l = a.l;
			if (subtracting)
			{
				if (comparing)
					lw.xl += (unsigned char)(~work.l + 1); // take two's complement (invert and add 1)
				else
					lw.xl += (unsigned char)(~work.l + (p & 0x01)); // invert subtrahend and add carry
			}
			else
				lw.xl += (unsigned char)(work.l + (p & 0x01)); // add work.l and carry to lower 16 bits
			/*
			Overflow conditioning truth table for addition- MSB settings of operands and results

				Acc	Arg+C	Result	Overflow
				0	1	<na>	0	Always clear if A and Arg+C are different signs
				1	0	<na>	0	''
				0	0	0	0	(0 to 127) + (0 to 127) = V clear if result is < 128
				0	0	1	1	(0 to 127) + (0 to 127) = V set if result is >= 128
				1	1	0	1	(-128 to -1) + (-128 to -1) = V set if result is < -128
				1	1	1	0	(-128 to -1) + (-128 to -1) = V clear if result is >= -128

			Overflow conditioning truth table for subtraction

				Acc	Arg+~C	Result	Overflow
				0	0	<na>	0	Always clear if A and Arg+C are the same sign
				1	1	<na>	0	''
				0	1	0	0	(0 to 127) - (-128 to -1) = V clear if result is < 128
				0	1	1	1	(0 to 127) - (-128 to -1) = V set if result >= 128
				1	0	0	1	(-128 to -1) - (0 to 127) = V set if result < -128
				1	0	1	0	(-128 to -1) - (0 to 127) = V clear if result >= -128
			*/
			if (!comparing) // CMP, CPX, CPY don't condition the V flag
			{
				if (subtracting)
				{
					// subtraction
					// MSB of a.l equals MSB of (work.l + ~carry)
					if ((a.l & 0x80) == ((work.l + ((p & 0x01) ^ 0x01)) & 0x80)) 
						p &= 0xbf;
					else
					{
						if (((a.l & 0x80) ^ (lw.l & 0x80)) == 0x80)
							p |= 0x40; // Acc EOR'ed with Result = V flag
						else
							p &= 0xbf;
					}
				}
				else
				{
					// addition
					// MSB of a.l EOR'ed with MSB of (work.l + carry)
					if (((a.l & 0x80) ^ ((work.l + (p & 0x01)) & 0x80)) == 0x80) 
						p &= 0xbf; // V clear always if two operands are different signs
					else
					{
						if (((a.l & 0x80) ^ (lw.l & 0x80)) == 0x80)
							p |= 0x40; // set V according truth table above: Acc EOR'ed with Result = V flag
						else
							p &= 0xbf;
					}
				}
			}
			// condition carry
			if ((lw.xl & 0x0100) == 0x0100)
				p |= 0x01;
			else
				p &= 0xfe;
			a.l = lw.l;
			if (a.l == 0)
				p |= 0x02;
			else
				p &= 0xfd;
			// condition n
			if (a.l > 127)
				p |= 0x80;
			else
				p &= 0x7f;
			// condition z
			if (a.l == 0)
				p |= 0x02;
			else
				p &= 0xfd;
		}
	}
	else
	{
		fetch(amod,16);
		if (((p & 0x08) == 0x08) && (!comparing))
		{
			// SED active? decimal mode
			if (subtracting)
			{
				n0 = bcdsubtract((p & 0x01),(a.x & 0x000f),(work.x & 0x000f));
				n1 = bcdsubtract(halfcarry,((a.x & 0x00f0) >> 4),((work.x & 0x00f0) >> 4));
				n2 = bcdsubtract(halfcarry,((a.x & 0x0f00) >> 8),((work.x & 0x0f00) >> 8));
				n3 = bcdsubtract(halfcarry,((a.x & 0xf000) >> 12),((work.x & 0xf000) >> 12));
				a.x = n0;
				a.x += (n1 * 16) + (n2 * 256) + (n3 * 4096);
			}
			else
			{
				n0 = bcdadd((p & 0x01),(work.x & 0x000f),(a.x & 0x000f));
				n1 = bcdadd(halfcarry,((work.x & 0x00f0) >> 4),((a.x & 0x00f0) >> 4));
				n2 = bcdadd(halfcarry,((work.x & 0x0f00) >> 8),((a.x & 0x0f00) >> 8));
				n3 = bcdadd(halfcarry,((work.x & 0xf000) >> 12),((a.x & 0xf000) >> 12));
				a.x = n0;
				a.x += (n1 * 16) + (n2 * 256) + (n3 * 4096);
			}
			if (halfcarry) // condition carry
				p |= 0x01;
			else
				p &= 0xfe;
			// condition n
			if (a.x > 32768)
				p |= 0x80;
			else
				p &= 0x7f;
			// condition z
			if (a.x == 0)
				p |= 0x02;
			else
				p &= 0xfd;
		}
		else
		{
			// CLD active - binary mode
			lw.xl = a.x;
			if (subtracting)
			{
				if (comparing)
					lw.xx += (unsigned short)(~work.x + 1); // take two's complement (invert and add 1)
				else
					lw.xx += (unsigned short)(~work.x + (p & 0x01));// invert subtrahend and add carry
			}
			else
				lw.xx += (unsigned short)(work.x + (p & 0x01)); // add work.x and carry to 32 bit long register
			// Condition overflow
			if (!comparing) // CMP, CPX, CPY don't condition the V flag
			{
				if (subtracting)
				{
					// subtraction
					if ((a.x & 0x8000) == ((work.x + ((p & 0x01) ^ 0x01)) & 0x8000))
						p &= 0xbf;
					else
					{
						if (((a.x & 0x8000) ^ (lw.xl & 0x8000)) == 0x8000)
							p |= 0x40; // Acc EOR'ed with Result = V flag
						else
							p &= 0xbf;
					}
				}
				else
				{
					// addition
					// MSB of a.x EOR'ed with MSB of (work.x + carry)
					if (((a.x & 0x8000) ^ ((work.x + (p & 0x01)) & 0x8000)) == 0x8000) 
						p &= 0xbf; // V clear always if two operands are different signs
					else
					{
						if (((a.x & 0x8000) ^ (lw.xl & 0x8000)) == 0x8000)
							p |= 0x40; // set V according to truth table above: Acc EOR'ed with Result = V flag
						else
							p &= 0xbf;
					}
				}
			}
			// condition carry
			if ((lw.xh & 0x0001) == 0x0001)
				p |= 0x01;
			else
				p &= 0xfe;
			a.x = lw.xl;
			if (a.x == 0)
			p |= 0x02;
			else
			p &= 0xfd;
			// condition n
			if (a.x > 32767)
				p |= 0x80;
			else
				p &= 0x7f;
			// condition z
			if (a.x == 0)
				p |= 0x02;
			else
				p &= 0xfd;
		}
	}
	// restore A if we did a CMP, CPX or CPY
	if (comparing)
		a.x = savea.x;

	// compute cycles
	switch (amod) {
		case IMMEDIATE:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 4;
			break;
		case ABSOLUTELONG:
			cycles += 5;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
		case ABSOLUTEINDEXEDY:
			cycles += 4;
			if (boundcross == 1)
				cycles++;
			break;
		case ABSOLUTELONGINDEXEDX:
			cycles += 5;
			break;
		case DIRECTINDIRECT:
		case DIRECTINDIRECTLONG:
		case DIRECTINDIRECTINDEXEDY:
		case DIRECTINDIRECTLONGINDEXEDY:
		case DIRECTINDEXEDINDIRECTX:
			cycles += 6;
			if ((amod == DIRECTINDIRECT) || (amod == DIRECTINDIRECTINDEXEDY))
				cycles--; // only 5 cycles for DIRECTINDIRECT and DIRECTINDIRECTINDEXEDY
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			if ((amod == DIRECTINDIRECTINDEXEDY) && (boundcross == 1))
				cycles++;
			break;
		case STACKRELATIVE:
			cycles += 4;
			break;
		case STACKINDIRECTINDEXEDY:
			cycles += 7;
			break;
	}
	if (cpx || cpy) 
	{
		if ((e==0) && ((p & 0x10) == 0))
			cycles++; // add 1 for 16 bit XY
	}
	else
	{
		if ((e==0) && ((p & 0x20) == 0))
			cycles++; // add 1 for 16 bit A
	}
}

void opc_bit(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		fetch(amod,8);
		// set overflow if bit 6 is set in memory
		if ((work.l & 0x40) == 0x40)
			p |= 0x40;
		else
			p &= 0xbf;
		// set negative if bit 7 is set in memory
		if (work.l > 127)
			p |= 0x80;
		else
			p &= 0x7f;
		// set zero if logical AND of memory and acc is zero
		if ((work.l & a.l) == 0)
			p |= 0x02;
		else
			p &= 0xfd;
	}
	else
	{
		fetch(amod,16);
		// set overflow if bit 14 is set in memory
		if ((work.x & 0x4000) == 0x4000)
			p |= 0x40;
		else
			p &= 0xbf;
		// set negative if bit 15 is set in memory
		if (work.x > 32767)
			p |= 0x80;
		else
			p &= 0x7f;
		// set zero if logical AND of memory and acc is zero
		if ((work.x & a.x) == 0)
			p |= 0x02;
		else
			p &= 0xfd;
	}
	// compute cycles
	switch (amod) {
		case IMMEDIATE:
			cycles += 2;
			break;
		case ABSOLUTE:
			cycles += 4;
			break;
		case DIRECT:
		case DIRECTINDEXEDX:
			cycles += 3;
			if (amod==DIRECTINDEXEDX)
				cycles++;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
		case ABSOLUTEINDEXEDX:
			cycles += 4;
			if (boundcross == 1)
				cycles++;
			break;
	}
	if ((e==0) && ((p & 0x20) == 0))
		cycles++; // add 1 for 16 bit A
}

void opc_trbtsb(int amod)
{
	inc_pc(1);
	if ((e==1) || (((p & 0x20) == 0x20) && (e==0)))
	{
		fetch(amod,8);
		// set zero if logical AND of memory and acc is zero
		if ((work.l & a.l) == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		switch (opcload)
		{
			case 0x1c:
			case 0x14: // TRB
				work.l &= ~a.l;
				break;
			case 0x0c:
			case 0x04: // TSB
				work.l |= a.l;
				break;
		}
		writeback(amod,8);
	}
	else
	{
		fetch(amod,16);
		// set zero if logical AND of memory and acc is zero
		if ((work.x & a.x) == 0)
			p |= 0x02;
		else
			p &= 0xfd;
		switch (opcload)
		{
			case 0x1c:
			case 0x14: // TRB
				work.x &= ~a.x;
				break;
			case 0x0c:
			case 0x04: // TSB
				work.x |= a.x;
				break;
		}
		writeback(amod,16);
	}
	// compute cycles
	switch (amod) {
		case ABSOLUTE:
			cycles += 6;
			break;
		case DIRECT:
			cycles += 5;
			if (d.l != 0)
				cycles++; // add cycle if low byte of D is != 0
			break;
	}
	if ((e==0) && ((p & 0x20) == 0))
		cycles++; // add 1 for 16 bit A
}

