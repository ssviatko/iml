#include "z80_engine.h"

/*
Zilog Z80 CPU core.

Implements the full documented instruction set plus the commonly known undocumented
behavior: the X/Y (bit 3/5) flags, IXH/IXL/IYH/IYL, SLL, IN F,(C), the DDCB/FDCB
register-copy forms, the extra ED NOPs, and MEMPTR (WZ) for BIT n,(HL) flags.
Timing is in T-states. All memory and I/O goes through the Z80 driver
(z80_mem_read/z80_mem_write/z80_io_read/z80_io_write).

Conventions used below (from the standard Z80 opcode decomposition):
	opcode = xxyyyzzz, p = yy y>>1, q = y&1
	register codes 0-7 = B,C,D,E,H,L,(HL),A
	register pair codes: 0=BC 1=DE 2=HL 3=SP (or AF for PUSH/POP)
*/

// flag bits
#define FC 0x01 // carry
#define FN 0x02 // subtract
#define FP 0x04 // parity/overflow
#define FX 0x08 // undocumented, copy of bit 3
#define FH 0x10 // half carry
#define FY 0x20 // undocumented, copy of bit 5
#define FZ 0x40 // zero
#define FS 0x80 // sign

// register file. Index 6 holds F, since code 6 is (HL) in opcodes and never a real register.
enum { rB, rC, rD, rE, rH, rL, rF, rA };
static uint8_t r[8];  // main registers
static uint8_t rs[8]; // shadow registers
#define A r[rA]
#define F r[rF]

static uint16_t ix, iy, sp, pc;
static uint16_t wz; // MEMPTR, affects X/Y flags of BIT n,(HL)
static uint8_t reg_i, reg_r; // interrupt vector and refresh registers
static uint8_t iff1, iff2, im;
static uint8_t halted;
static uint8_t ei_delay; // interrupts are not accepted until after the instruction following EI
static long cycles;
static int pfx; // current prefix: 0 = none, 1 = DD (IX), 2 = FD (IY)

static uint8_t szp_tab[256]; // S,Z,Y,X and parity flags for a value

static void init_tables(void)
{
	int i, j, bits;

	for (i = 0; i < 256; i++)
	{
		bits = 0;
		for (j = 0; j < 8; j++)
			bits += (i >> j) & 1;
		szp_tab[i] = (i & (FS | FY | FX)) | ((i == 0) ? FZ : 0) | (((bits & 1) == 0) ? FP : 0);
	}
}

// ---------------------------------------------------------------- memory access

static inline uint8_t rd(uint16_t addr)
{
	return z80_mem_read(addr);
}

static inline void wr(uint16_t addr, uint8_t v)
{
	z80_mem_write(addr, v);
}

static inline uint16_t rd16(uint16_t addr)
{
	return rd(addr) | (rd(addr + 1) << 8);
}

static inline void wr16(uint16_t addr, uint16_t v)
{
	wr(addr, v & 0xff);
	wr(addr + 1, v >> 8);
}

static inline uint8_t fetch8(void)
{
	return rd(pc++);
}

static inline uint16_t fetch16(void)
{
	uint16_t v = rd16(pc);
	pc += 2;
	return v;
}

// opcode fetch (M1 cycle): bumps the low 7 bits of the refresh register
static inline uint8_t fetch_op(void)
{
	reg_r = (reg_r & 0x80) | ((reg_r + 1) & 0x7f);
	return fetch8();
}

static void push16(uint16_t v)
{
	sp--;
	wr(sp, v >> 8);
	sp--;
	wr(sp, v & 0xff);
}

static uint16_t pop16(void)
{
	uint16_t v = rd16(sp);
	sp += 2;
	return v;
}

// ---------------------------------------------------------------- register access

static inline uint16_t get_hl(void)
{
	return (r[rH] << 8) | r[rL];
}

static inline void set_hl(uint16_t v)
{
	r[rH] = v >> 8;
	r[rL] = v & 0xff;
}

// HL, or IX/IY when a DD/FD prefix is active
static inline uint16_t get_hlx(void)
{
	return (pfx == 0) ? get_hl() : ((pfx == 1) ? ix : iy);
}

static inline void set_hlx(uint16_t v)
{
	if (pfx == 0)
		set_hl(v);
	else if (pfx == 1)
		ix = v;
	else
		iy = v;
}

static uint16_t get_rp(int p) // BC, DE, HL/IX/IY, SP
{
	switch (p)
	{
		case 0: return (r[rB] << 8) | r[rC];
		case 1: return (r[rD] << 8) | r[rE];
		case 2: return get_hlx();
		default: return sp;
	}
}

static void set_rp(int p, uint16_t v)
{
	switch (p)
	{
		case 0: r[rB] = v >> 8; r[rC] = v & 0xff; break;
		case 1: r[rD] = v >> 8; r[rE] = v & 0xff; break;
		case 2: set_hlx(v); break;
		default: sp = v; break;
	}
}

// 8-bit register by code (not 6). H and L become IXH/IXL/IYH/IYL under a prefix unless 'plain' is set.
static uint8_t get_reg(int code, int plain)
{
	if (pfx && !plain)
	{
		if (code == rH)
			return get_hlx() >> 8;
		if (code == rL)
			return get_hlx() & 0xff;
	}
	return r[code];
}

static void set_reg(int code, uint8_t v, int plain)
{
	if (pfx && !plain)
	{
		if (code == rH)
		{
			set_hlx((get_hlx() & 0x00ff) | (v << 8));
			return;
		}
		if (code == rL)
		{
			set_hlx((get_hlx() & 0xff00) | v);
			return;
		}
	}
	r[code] = v;
}

// effective address of the (HL) operand: HL, or IX/IY plus a signed displacement
static uint16_t mem_ea(void)
{
	uint16_t ea;

	if (pfx == 0)
		return get_hl();
	ea = get_hlx() + (int8_t)fetch8();
	wz = ea;
	cycles += 8; // displacement fetch and address calculation
	return ea;
}

// ---------------------------------------------------------------- ALU

static uint8_t add8(uint8_t a, uint8_t v, int c)
{
	unsigned res = a + v + c;

	F = (res & (FS | FY | FX)) | (((res & 0xff) == 0) ? FZ : 0) |
	    ((a ^ v ^ res) & FH) | ((~(a ^ v) & (a ^ res) & 0x80) ? FP : 0) |
	    ((res > 0xff) ? FC : 0);
	return res;
}

static uint8_t sub8(uint8_t a, uint8_t v, int c)
{
	unsigned res = a - v - c;

	F = (res & (FS | FY | FX)) | (((res & 0xff) == 0) ? FZ : 0) |
	    ((a ^ v ^ res) & FH) | (((a ^ v) & (a ^ res) & 0x80) ? FP : 0) |
	    FN | ((res & 0x100) ? FC : 0);
	return res;
}

static void alu(int op, uint8_t v)
{
	switch (op)
	{
		case 0: A = add8(A, v, 0); break; // ADD
		case 1: A = add8(A, v, F & FC); break; // ADC
		case 2: A = sub8(A, v, 0); break; // SUB
		case 3: A = sub8(A, v, F & FC); break; // SBC
		case 4: A &= v; F = szp_tab[A] | FH; break; // AND
		case 5: A ^= v; F = szp_tab[A]; break; // XOR
		case 6: A |= v; F = szp_tab[A]; break; // OR
		case 7: // CP: flags of A-v, but X/Y come from the operand
			sub8(A, v, 0);
			F = (F & ~(FX | FY)) | (v & (FX | FY));
			break;
	}
}

static uint8_t inc8(uint8_t v)
{
	uint8_t res = v + 1;

	F = (F & FC) | (res & (FS | FY | FX)) | ((res == 0) ? FZ : 0) |
	    (((v & 0x0f) == 0x0f) ? FH : 0) | ((v == 0x7f) ? FP : 0);
	return res;
}

static uint8_t dec8(uint8_t v)
{
	uint8_t res = v - 1;

	F = (F & FC) | (res & (FS | FY | FX)) | ((res == 0) ? FZ : 0) |
	    (((v & 0x0f) == 0x00) ? FH : 0) | ((v == 0x80) ? FP : 0) | FN;
	return res;
}

static uint16_t add16(uint16_t a, uint16_t v)
{
	unsigned res = a + v;

	F = (F & (FS | FZ | FP)) | ((res >> 8) & (FY | FX)) |
	    (((a ^ v ^ res) & 0x1000) ? FH : 0) | ((res > 0xffff) ? FC : 0);
	wz = a + 1;
	return res;
}

static uint16_t adc16(uint16_t a, uint16_t v)
{
	unsigned c = F & FC;
	unsigned res = a + v + c;

	F = ((res >> 8) & (FS | FY | FX)) | (((res & 0xffff) == 0) ? FZ : 0) |
	    (((a ^ v ^ res) & 0x1000) ? FH : 0) | ((~(a ^ v) & (a ^ res) & 0x8000) ? FP : 0) |
	    ((res > 0xffff) ? FC : 0);
	wz = a + 1;
	return res;
}

static uint16_t sbc16(uint16_t a, uint16_t v)
{
	unsigned c = F & FC;
	unsigned res = a - v - c;

	F = ((res >> 8) & (FS | FY | FX)) | (((res & 0xffff) == 0) ? FZ : 0) |
	    (((a ^ v ^ res) & 0x1000) ? FH : 0) | (((a ^ v) & (a ^ res) & 0x8000) ? FP : 0) |
	    FN | ((res & 0x10000) ? FC : 0);
	wz = a + 1;
	return res;
}

static void daa(void)
{
	uint8_t a = A, corr = 0;
	int c = F & FC;
	int h;

	if ((F & FH) || ((a & 0x0f) > 9))
		corr |= 0x06;
	if (c || (a > 0x99))
	{
		corr |= 0x60;
		c = 1;
	}
	if (F & FN)
		h = ((F & FH) && ((a & 0x0f) < 6));
	else
		h = ((a & 0x0f) > 9);
	if (F & FN)
		A = a - corr;
	else
		A = a + corr;
	F = szp_tab[A] | (F & FN) | (h ? FH : 0) | (c ? FC : 0);
}

// CB-prefix rotates and shifts: RLC RRC RL RR SLA SRA SLL SRL
static uint8_t cb_rot(int y, uint8_t v)
{
	uint8_t c;

	switch (y)
	{
		case 0: c = v >> 7; v = (v << 1) | c; break;
		case 1: c = v & 1; v = (v >> 1) | (c << 7); break;
		case 2: c = v >> 7; v = (v << 1) | (F & FC); break;
		case 3: c = v & 1; v = (v >> 1) | ((F & FC) << 7); break;
		case 4: c = v >> 7; v <<= 1; break;
		case 5: c = v & 1; v = (v >> 1) | (v & 0x80); break;
		case 6: c = v >> 7; v = (v << 1) | 1; break; // SLL (undocumented)
		default: c = v & 1; v >>= 1; break;
	}
	F = szp_tab[v] | c;
	return v;
}

// BIT n,v. 'xy' supplies the undocumented X/Y flag source.
static void cb_bit(int n, uint8_t v, uint8_t xy)
{
	uint8_t t = v & (1 << n);

	F = (F & FC) | FH | (xy & (FX | FY)) | (t ? 0 : (FZ | FP)) | ((n == 7 && t) ? FS : 0);
}

static int cond(int y)
{
	int t;

	switch (y >> 1)
	{
		case 0: t = F & FZ; break; // NZ / Z
		case 1: t = F & FC; break; // NC / C
		case 2: t = F & FP; break; // PO / PE
		default: t = F & FS; break; // P / M
	}
	return (y & 1) ? (t != 0) : (t == 0);
}

static void swap_regs(uint8_t first, uint8_t last)
{
	uint8_t t;
	int i;

	for (i = first; i <= last; i++)
	{
		t = r[i];
		r[i] = rs[i];
		rs[i] = t;
	}
}

// ---------------------------------------------------------------- block instructions

// LDI, LDD, LDIR, LDDR
static void block_ld(int dec, int repeat)
{
	uint16_t hl = get_hl(), de = (r[rD] << 8) | r[rE], bc = (r[rB] << 8) | r[rC];
	uint8_t v = rd(hl), n;
	int step = dec ? -1 : 1;

	wr(de, v);
	hl += step;
	de += step;
	bc--;
	set_hl(hl);
	r[rD] = de >> 8;
	r[rE] = de & 0xff;
	r[rB] = bc >> 8;
	r[rC] = bc & 0xff;
	n = v + A;
	F = (F & (FS | FZ | FC)) | (n & FX) | ((n & 0x02) ? FY : 0) | (bc ? FP : 0);
	cycles += 16;
	if (repeat && bc)
	{
		pc -= 2;
		wz = pc + 1;
		cycles += 5;
	}
}

// CPI, CPD, CPIR, CPDR
static void block_cp(int dec, int repeat)
{
	uint16_t hl = get_hl(), bc = (r[rB] << 8) | r[rC];
	uint8_t v = rd(hl), res = A - v, n;
	uint8_t hf = ((A ^ v ^ res) & FH);

	hl += dec ? -1 : 1;
	bc--;
	set_hl(hl);
	r[rB] = bc >> 8;
	r[rC] = bc & 0xff;
	n = res - (hf ? 1 : 0);
	F = (F & FC) | FN | (res & FS) | ((res == 0) ? FZ : 0) | hf | (bc ? FP : 0) |
	    (n & FX) | ((n & 0x02) ? FY : 0);
	wz += dec ? -1 : 1;
	cycles += 16;
	if (repeat && bc && (res != 0))
	{
		pc -= 2;
		wz = pc + 1;
		cycles += 5;
	}
}

// flags shared by the block I/O instructions
static void block_io_flags(uint8_t val, unsigned k)
{
	F = (r[rB] & (FS | FY | FX)) | ((r[rB] == 0) ? FZ : 0) | ((val & 0x80) ? FN : 0) |
	    ((k > 0xff) ? (FH | FC) : 0) | ((szp_tab[(k & 7) ^ r[rB]] & FP));
}

// INI, IND, INIR, INDR
static void block_in(int dec, int repeat)
{
	uint8_t val = z80_io_read(r[rC]);
	uint16_t hl = get_hl();

	wr(hl, val);
	wz = ((r[rB] << 8) | r[rC]) + (dec ? -1 : 1);
	r[rB]--;
	set_hl(hl + (dec ? -1 : 1));
	block_io_flags(val, val + ((r[rC] + (dec ? -1 : 1)) & 0xff));
	cycles += 16;
	if (repeat && r[rB])
	{
		pc -= 2;
		cycles += 5;
	}
}

// OUTI, OUTD, OTIR, OTDR
static void block_out(int dec, int repeat)
{
	uint16_t hl = get_hl();
	uint8_t val = rd(hl);

	r[rB]--;
	z80_io_write(r[rC], val);
	wz = ((r[rB] << 8) | r[rC]) + (dec ? -1 : 1);
	set_hl(hl + (dec ? -1 : 1));
	block_io_flags(val, val + r[rL]);
	cycles += 16;
	if (repeat && r[rB])
	{
		pc -= 2;
		cycles += 5;
	}
}

// ---------------------------------------------------------------- prefixed instruction groups

// CB prefix (no DD/FD) - rotates, BIT, RES, SET on registers and (HL)
static void exec_cb(void)
{
	uint8_t op = fetch_op();
	int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
	uint16_t hl = get_hl();
	uint8_t v;

	if (z == 6)
		v = rd(hl);
	else
		v = r[z];

	switch (x)
	{
		case 0: v = cb_rot(y, v); break;
		case 1: cb_bit(y, v, (z == 6) ? (wz >> 8) : v); break;
		case 2: v &= ~(1 << y); break; // RES
		case 3: v |= (1 << y); break; // SET
	}
	if (x != 1)
	{
		if (z == 6)
			wr(hl, v);
		else
			r[z] = v;
	}
	if (z == 6)
		cycles += (x == 1) ? 12 : 15;
	else
		cycles += 8;
}

// DD CB d op / FD CB d op
static void exec_ddcb(void)
{
	uint16_t ea = get_hlx() + (int8_t)fetch8();
	uint8_t op = fetch8(); // not an M1 cycle: R isn't bumped
	int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
	uint8_t v = rd(ea);

	wz = ea;
	switch (x)
	{
		case 0: v = cb_rot(y, v); break;
		case 1: cb_bit(y, v, ea >> 8); break;
		case 2: v &= ~(1 << y); break;
		case 3: v |= (1 << y); break;
	}
	if (x != 1)
	{
		wr(ea, v);
		if (z != 6)
			r[z] = v; // undocumented: result is also copied to a register
	}
	cycles += (x == 1) ? 16 : 19; // plus 4 for the DD/FD prefix already counted
}

static void exec_ed(void)
{
	uint8_t op = fetch_op();
	int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
	uint8_t v;
	uint16_t nn;
	uint16_t hl;

	if (x == 1)
	{
		switch (z)
		{
			case 0: // IN r,(C)
				v = z80_io_read(r[rC]);
				wz = ((r[rB] << 8) | r[rC]) + 1;
				F = szp_tab[v] | (F & FC);
				if (y != 6)
					r[y] = v;
				cycles += 12;
				break;
			case 1: // OUT (C),r
				z80_io_write(r[rC], (y == 6) ? 0 : r[y]);
				wz = ((r[rB] << 8) | r[rC]) + 1;
				cycles += 12;
				break;
			case 2: // SBC HL,rp / ADC HL,rp
				hl = get_hl();
				if (q == 0)
					set_hl(sbc16(hl, get_rp(p)));
				else
					set_hl(adc16(hl, get_rp(p)));
				cycles += 15;
				break;
			case 3: // LD (nn),rp / LD rp,(nn)
				nn = fetch16();
				wz = nn + 1;
				if (q == 0)
					wr16(nn, get_rp(p));
				else
					set_rp(p, rd16(nn));
				cycles += 20;
				break;
			case 4: // NEG (all 8 encodings)
				A = sub8(0, A, 0);
				cycles += 8;
				break;
			case 5: // RETN / RETI
				iff1 = iff2;
				pc = pop16();
				wz = pc;
				cycles += 14;
				break;
			case 6: // IM n
				switch (y & 3)
				{
					case 0: case 1: im = 0; break;
					case 2: im = 1; break;
					default: im = 2; break;
				}
				cycles += 8;
				break;
			case 7:
				switch (y)
				{
					case 0: reg_i = A; cycles += 9; break; // LD I,A
					case 1: reg_r = A; cycles += 9; break; // LD R,A
					case 2: // LD A,I
						A = reg_i;
						F = (F & FC) | (szp_tab[A] & ~FP) | (iff2 ? FP : 0);
						cycles += 9;
						break;
					case 3: // LD A,R
						A = reg_r;
						F = (F & FC) | (szp_tab[A] & ~FP) | (iff2 ? FP : 0);
						cycles += 9;
						break;
					case 4: // RRD
						hl = get_hl();
						v = rd(hl);
						wr(hl, (A << 4) | (v >> 4));
						A = (A & 0xf0) | (v & 0x0f);
						F = szp_tab[A] | (F & FC);
						wz = hl + 1;
						cycles += 18;
						break;
					case 5: // RLD
						hl = get_hl();
						v = rd(hl);
						wr(hl, (v << 4) | (A & 0x0f));
						A = (A & 0xf0) | (v >> 4);
						F = szp_tab[A] | (F & FC);
						wz = hl + 1;
						cycles += 18;
						break;
					default: cycles += 8; break; // NOP
				}
				break;
		}
	}
	else if ((x == 2) && (z <= 3) && (y >= 4))
	{
		int dec = y & 1;
		int repeat = y >= 6;

		switch (z)
		{
			case 0: block_ld(dec, repeat); break;
			case 1: block_cp(dec, repeat); break;
			case 2: block_in(dec, repeat); break;
			default: block_out(dec, repeat); break;
		}
	}
	else
		cycles += 8; // undefined ED opcodes act as 2-byte NOPs
}

// ---------------------------------------------------------------- main decoder

static void exec_main(uint8_t op)
{
	int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
	uint8_t v, t;
	uint16_t nn, ea;
	int8_t d;

	switch (x)
	{
		case 0:
			switch (z)
			{
				case 0:
					switch (y)
					{
						case 0: cycles += 4; break; // NOP
						case 1: // EX AF,AF'
							t = r[rA]; r[rA] = rs[rA]; rs[rA] = t;
							t = r[rF]; r[rF] = rs[rF]; rs[rF] = t;
							cycles += 4;
							break;
						case 2: // DJNZ d
							d = (int8_t)fetch8();
							r[rB]--;
							if (r[rB])
							{
								pc += d;
								wz = pc;
								cycles += 13;
							}
							else
								cycles += 8;
							break;
						case 3: // JR d
							d = (int8_t)fetch8();
							pc += d;
							wz = pc;
							cycles += 12;
							break;
						default: // JR cc,d
							d = (int8_t)fetch8();
							if (cond(y - 4))
							{
								pc += d;
								wz = pc;
								cycles += 12;
							}
							else
								cycles += 7;
							break;
					}
					break;
				case 1:
					if (q == 0) // LD rp,nn
					{
						set_rp(p, fetch16());
						cycles += 10;
					}
					else // ADD HL,rp
					{
						set_hlx(add16(get_hlx(), get_rp(p)));
						cycles += 11;
					}
					break;
				case 2:
					switch (p)
					{
						case 0: // LD (BC),A / LD A,(BC)
						case 1: // LD (DE),A / LD A,(DE)
							ea = get_rp(p);
							if (q == 0)
							{
								wr(ea, A);
								wz = ((A << 8) | ((ea + 1) & 0xff));
							}
							else
							{
								A = rd(ea);
								wz = ea + 1;
							}
							cycles += 7;
							break;
						case 2: // LD (nn),HL / LD HL,(nn)
							nn = fetch16();
							wz = nn + 1;
							if (q == 0)
								wr16(nn, get_hlx());
							else
								set_hlx(rd16(nn));
							cycles += 16;
							break;
						default: // LD (nn),A / LD A,(nn)
							nn = fetch16();
							if (q == 0)
							{
								wr(nn, A);
								wz = ((A << 8) | ((nn + 1) & 0xff));
							}
							else
							{
								A = rd(nn);
								wz = nn + 1;
							}
							cycles += 13;
							break;
					}
					break;
				case 3: // INC rp / DEC rp
					set_rp(p, get_rp(p) + (q ? -1 : 1));
					cycles += 6;
					break;
				case 4: // INC r
				case 5: // DEC r
					if (y == 6)
					{
						ea = mem_ea();
						v = rd(ea);
						wr(ea, (z == 4) ? inc8(v) : dec8(v));
						cycles += 11;
					}
					else
					{
						v = get_reg(y, 0);
						set_reg(y, (z == 4) ? inc8(v) : dec8(v), 0);
						cycles += 4;
					}
					break;
				case 6: // LD r,n
					if (y == 6)
					{
						ea = mem_ea();
						wr(ea, fetch8());
						cycles += 10;
						if (pfx)
							cycles -= 3; // the displacement and immediate fetches overlap
					}
					else
					{
						set_reg(y, fetch8(), 0);
						cycles += 7;
					}
					break;
				case 7:
					switch (y)
					{
						case 0: // RLCA
							t = A >> 7;
							A = (A << 1) | t;
							F = (F & (FS | FZ | FP)) | (A & (FY | FX)) | t;
							break;
						case 1: // RRCA
							t = A & 1;
							A = (A >> 1) | (t << 7);
							F = (F & (FS | FZ | FP)) | (A & (FY | FX)) | t;
							break;
						case 2: // RLA
							t = A >> 7;
							A = (A << 1) | (F & FC);
							F = (F & (FS | FZ | FP)) | (A & (FY | FX)) | t;
							break;
						case 3: // RRA
							t = A & 1;
							A = (A >> 1) | ((F & FC) << 7);
							F = (F & (FS | FZ | FP)) | (A & (FY | FX)) | t;
							break;
						case 4: daa(); break;
						case 5: // CPL
							A = ~A;
							F = (F & (FS | FZ | FP | FC)) | FH | FN | (A & (FY | FX));
							break;
						case 6: // SCF
							F = (F & (FS | FZ | FP)) | FC | (A & (FY | FX));
							break;
						case 7: // CCF
							F = (F & (FS | FZ | FP)) | ((F & FC) ? FH : FC) | (A & (FY | FX));
							break;
					}
					cycles += 4;
					break;
			}
			break;

		case 1:
			if ((y == 6) && (z == 6)) // HALT
			{
				halted = 1;
				cycles += 4;
			}
			else if (z == 6) // LD r,(HL)
			{
				ea = mem_ea();
				set_reg(y, rd(ea), 1);
				cycles += 7;
			}
			else if (y == 6) // LD (HL),r
			{
				ea = mem_ea();
				wr(ea, get_reg(z, 1));
				cycles += 7;
			}
			else // LD r,r'
			{
				set_reg(y, get_reg(z, 0), 0);
				cycles += 4;
			}
			break;

		case 2: // ALU A,r
			if (z == 6)
			{
				ea = mem_ea();
				alu(y, rd(ea));
				cycles += 7;
			}
			else
			{
				alu(y, get_reg(z, 0));
				cycles += 4;
			}
			break;

		case 3:
			switch (z)
			{
				case 0: // RET cc
					if (cond(y))
					{
						pc = pop16();
						wz = pc;
						cycles += 11;
					}
					else
						cycles += 5;
					break;
				case 1:
					if (q == 0) // POP rp2
					{
						nn = pop16();
						if (p == 3)
						{
							r[rA] = nn >> 8;
							r[rF] = nn & 0xff;
						}
						else
							set_rp(p, nn);
						cycles += 10;
					}
					else
					{
						switch (p)
						{
							case 0: // RET
								pc = pop16();
								wz = pc;
								cycles += 10;
								break;
							case 1: // EXX
								swap_regs(rB, rL);
								cycles += 4;
								break;
							case 2: // JP (HL)
								pc = get_hlx();
								cycles += 4;
								break;
							default: // LD SP,HL
								sp = get_hlx();
								cycles += 6;
								break;
						}
					}
					break;
				case 2: // JP cc,nn
					nn = fetch16();
					wz = nn;
					if (cond(y))
						pc = nn;
					cycles += 10;
					break;
				case 3:
					switch (y)
					{
						case 0: // JP nn
							pc = fetch16();
							wz = pc;
							cycles += 10;
							break;
						case 2: // OUT (n),A
							t = fetch8();
							z80_io_write(t, A);
							wz = (A << 8) | ((t + 1) & 0xff);
							cycles += 11;
							break;
						case 3: // IN A,(n)
							t = fetch8();
							wz = ((A << 8) | t) + 1;
							A = z80_io_read(t);
							cycles += 11;
							break;
						case 4: // EX (SP),HL
							nn = rd16(sp);
							wr16(sp, get_hlx());
							set_hlx(nn);
							wz = nn;
							cycles += 19;
							break;
						case 5: // EX DE,HL (never uses IX/IY)
							nn = get_hl();
							set_hl((r[rD] << 8) | r[rE]);
							r[rD] = nn >> 8;
							r[rE] = nn & 0xff;
							cycles += 4;
							break;
						case 6: // DI
							iff1 = iff2 = 0;
							cycles += 4;
							break;
						case 7: // EI
							iff1 = iff2 = 1;
							ei_delay = 2;
							cycles += 4;
							break;
					}
					break;
				case 4: // CALL cc,nn
					nn = fetch16();
					wz = nn;
					if (cond(y))
					{
						push16(pc);
						pc = nn;
						cycles += 17;
					}
					else
						cycles += 10;
					break;
				case 5:
					if (q == 0) // PUSH rp2
					{
						if (p == 3)
							nn = (r[rA] << 8) | r[rF];
						else
							nn = get_rp(p);
						push16(nn);
						cycles += 11;
					}
					else // CALL nn
					{
						nn = fetch16();
						wz = nn;
						push16(pc);
						pc = nn;
						cycles += 17;
					}
					break;
				case 6: // ALU A,n
					alu(y, fetch8());
					cycles += 7;
					break;
				case 7: // RST
					push16(pc);
					pc = y * 8;
					wz = pc;
					cycles += 11;
					break;
			}
			break;
	}
}

// ---------------------------------------------------------------- public interface

void engine_z80_reset()
{
	memset(r, 0, sizeof r);
	memset(rs, 0, sizeof rs);
	A = 0xff;
	F = 0xff;
	ix = iy = 0xffff;
	sp = 0xffff;
	pc = 0;
	wz = 0;
	reg_i = 0;
	reg_r = 0;
	iff1 = iff2 = 0;
	im = 0;
	halted = 0;
	ei_delay = 0;
	pfx = 0;
}

int engine_z80_init()
{
	z80_driver_startup();
	init_tables();
	cycles = 0;
	engine_z80_reset();
	return 0;
}

void engine_z80_step()
{
	uint8_t op;

	if (halted)
	{
		// a halted CPU keeps executing NOPs until an interrupt arrives
		reg_r = (reg_r & 0x80) | ((reg_r + 1) & 0x7f);
		cycles += 4;
		return;
	}

	pfx = 0;
	op = fetch_op();
	while ((op == 0xdd) || (op == 0xfd)) // DD/FD prefixes (a repeated prefix just replaces the previous)
	{
		pfx = (op == 0xdd) ? 1 : 2;
		cycles += 4;
		op = fetch_op();
	}

	if (op == 0xed)
	{
		pfx = 0; // ED instructions ignore DD/FD
		exec_ed();
	}
	else if (op == 0xcb)
	{
		if (pfx)
			exec_ddcb();
		else
			exec_cb();
	}
	else
		exec_main(op);

	if (ei_delay)
		ei_delay--;
}

// maskable interrupt request; 'data' is the byte the device places on the bus.
// returns 1 if the interrupt was accepted.
int engine_z80_irq(uint8_t data)
{
	if (!iff1 || ei_delay)
		return 0;
	halted = 0;
	iff1 = iff2 = 0;
	reg_r = (reg_r & 0x80) | ((reg_r + 1) & 0x7f);
	switch (im)
	{
		case 0: // execute the instruction on the bus; only RST is supported
			push16(pc);
			pc = data & 0x38;
			cycles += 13;
			break;
		case 1:
			push16(pc);
			pc = 0x38;
			cycles += 13;
			break;
		default:
			push16(pc);
			pc = rd16((reg_i << 8) | (data & 0xfe));
			cycles += 19;
			break;
	}
	wz = pc;
	return 1;
}

// non-maskable interrupt
void engine_z80_nmi()
{
	halted = 0;
	iff2 = iff1;
	iff1 = 0;
	reg_r = (reg_r & 0x80) | ((reg_r + 1) & 0x7f);
	push16(pc);
	pc = 0x66;
	wz = pc;
	cycles += 11;
}

long engine_z80_cycle_count()
{
	return cycles;
}

int engine_z80_halted()
{
	return halted;
}
