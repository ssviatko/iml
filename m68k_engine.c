#include "m68k_engine.h"
#include <setjmp.h>

/*
Motorola MC68000 CPU core.

Implements the complete MC68000 instruction set and exception model: supervisor/user
mode with separate stack pointers, trace, autovectored interrupts, address errors
(word/long access at an odd address), privilege violations, illegal and line A/F
instructions, TRAP, TRAPV, CHK and divide by zero. Timing is approximate (in clocks).
All memory goes through the m68k driver (m68k_mem_read8/16/32, m68k_mem_write8/16/32)
with a 24 bit address bus.

Opcodes are classified once at startup into a 64K table of handlers; anything the
classifier rejects is an illegal instruction.
*/

// status register
#define SR_T 0x8000
#define SR_S 0x2000
#define SR_X 0x10
#define SR_N 0x08
#define SR_Z 0x04
#define SR_V 0x02
#define SR_C 0x01

// exception vectors
enum {
	V_BUSERR = 2, V_ADDRERR = 3, V_ILLEGAL = 4, V_ZERODIV = 5, V_CHK = 6, V_TRAPV = 7,
	V_PRIV = 8, V_TRACE = 9, V_LINEA = 10, V_LINEF = 11, V_SPURIOUS = 24, V_AUTO = 24,
	V_TRAP = 32
};

// effective address categories, one bit per addressing mode index (see eai)
enum {
	EM_DN = 1 << 0, EM_AN = 1 << 1, EM_AI = 1 << 2, EM_PI = 1 << 3, EM_PD = 1 << 4,
	EM_DI = 1 << 5, EM_IX = 1 << 6, EM_AW = 1 << 7, EM_AL = 1 << 8, EM_PCDI = 1 << 9,
	EM_PCIX = 1 << 10, EM_IMM = 1 << 11
};
#define C_ALL 0xfff
#define C_DATA (C_ALL & ~EM_AN)
#define C_MEM (C_ALL & ~(EM_DN | EM_AN))
#define C_CTRL (EM_AI | EM_DI | EM_IX | EM_AW | EM_AL | EM_PCDI | EM_PCIX)
#define C_ALT 0x1ff
#define C_DALT (C_ALT & ~EM_AN)
#define C_MALT (C_ALT & ~(EM_DN | EM_AN))

static uint32_t D[8], A[8]; // A[7] is the active stack pointer
static uint32_t other_sp;   // USP while in supervisor mode, SSP while in user mode
static uint32_t pc;
static uint32_t ppc;        // address of the instruction being executed
static uint16_t sr;
static uint16_t ir;         // opcode being executed
static int stopped, halted;
static int irq_level;
static int in_exception;    // address error while stacking an exception halts the CPU
static long cycles;
static jmp_buf abort_jmp;

typedef void (*handler_t)(uint16_t op);
static handler_t optab[65536];

static const int szbytes[3] = { 1, 2, 4 };
static const uint32_t szmask[3] = { 0xff, 0xffff, 0xffffffff };
static const uint32_t szmsb[3] = { 0x80, 0x8000, 0x80000000 };

static void exception(int vec);

// ---------------------------------------------------------------- memory access

static void address_error(uint32_t addr, int write, int program)
{
	uint16_t old = sr;
	uint16_t fc;

	if (in_exception)
	{
		halted = 1; // double fault
		longjmp(abort_jmp, 1);
	}
	in_exception = 1;
	fc = ((sr & SR_S) ? 4 : 0) | (program ? 2 : 1);
	fc |= (write ? 0 : 0x10) | (program ? 0 : 0x08);
	if (!(sr & SR_S))
	{
		uint32_t t = A[7];
		A[7] = other_sp;
		other_sp = t;
	}
	sr = (sr | SR_S) & ~SR_T;
	A[7] -= 4; m68k_mem_write32(A[7] & 0xffffff, ppc + 2);
	A[7] -= 2; m68k_mem_write16(A[7] & 0xffffff, old);
	A[7] -= 2; m68k_mem_write16(A[7] & 0xffffff, ir);
	A[7] -= 4; m68k_mem_write32(A[7] & 0xffffff, addr);
	A[7] -= 2; m68k_mem_write16(A[7] & 0xffffff, fc);
	if (A[7] & 1)
		halted = 1;
	pc = m68k_mem_read32(V_ADDRERR * 4);
	if (pc & 1)
		halted = 1;
	in_exception = 0;
	cycles += 50;
	longjmp(abort_jmp, 1);
}

static inline uint8_t rd8(uint32_t a)
{
	return m68k_mem_read8(a & 0xffffff);
}

static inline uint16_t rd16(uint32_t a)
{
	if (a & 1)
		address_error(a, 0, 0);
	return m68k_mem_read16(a & 0xffffff);
}

static inline uint32_t rd32(uint32_t a)
{
	if (a & 1)
		address_error(a, 0, 0);
	return m68k_mem_read32(a & 0xffffff);
}

static inline void wr8(uint32_t a, uint8_t v)
{
	m68k_mem_write8(a & 0xffffff, v);
}

static inline void wr16(uint32_t a, uint16_t v)
{
	if (a & 1)
		address_error(a, 1, 0);
	m68k_mem_write16(a & 0xffffff, v);
}

static inline void wr32(uint32_t a, uint32_t v)
{
	if (a & 1)
		address_error(a, 1, 0);
	m68k_mem_write32(a & 0xffffff, v);
}

static inline uint32_t rd_sz(uint32_t a, int sz)
{
	return (sz == 0) ? rd8(a) : ((sz == 1) ? rd16(a) : rd32(a));
}

static inline void wr_sz(uint32_t a, int sz, uint32_t v)
{
	if (sz == 0)
		wr8(a, v);
	else if (sz == 1)
		wr16(a, v);
	else
		wr32(a, v);
}

static inline uint16_t fetch16(void)
{
	uint16_t v;

	if (pc & 1)
		address_error(pc, 0, 1);
	v = m68k_mem_read16(pc & 0xffffff);
	pc += 2;
	return v;
}

static inline uint32_t fetch32(void)
{
	uint32_t v = fetch16() << 16;
	return v | fetch16();
}

static inline void push16(uint16_t v)
{
	A[7] -= 2;
	wr16(A[7], v);
}

static inline void push32(uint32_t v)
{
	A[7] -= 4;
	wr32(A[7], v);
}

static inline uint16_t pop16(void)
{
	uint16_t v = rd16(A[7]);
	A[7] += 2;
	return v;
}

static inline uint32_t pop32(void)
{
	uint32_t v = rd32(A[7]);
	A[7] += 4;
	return v;
}

// ---------------------------------------------------------------- status register

static void set_sr(uint16_t v)
{
	v &= 0xa71f;
	if ((v ^ sr) & SR_S)
	{
		uint32_t t = A[7];
		A[7] = other_sp;
		other_sp = t;
	}
	sr = v;
}

static inline void set_ccr(uint8_t v)
{
	sr = (sr & 0xff00) | (v & 0x1f);
}

static int test_cc(int cc)
{
	int c = sr & SR_C, v = sr & SR_V, z = sr & SR_Z, n = sr & SR_N;

	switch (cc)
	{
		case 0: return 1;                   // T
		case 1: return 0;                   // F
		case 2: return !c && !z;            // HI
		case 3: return c || z;              // LS
		case 4: return !c;                  // CC
		case 5: return c != 0;              // CS
		case 6: return !z;                  // NE
		case 7: return z != 0;              // EQ
		case 8: return !v;                  // VC
		case 9: return v != 0;              // VS
		case 10: return !n;                 // PL
		case 11: return n != 0;             // MI
		case 12: return !n == !v;           // GE
		case 13: return !n != !v;           // LT
		case 14: return !z && (!n == !v);   // GT
		default: return z || (!n != !v);    // LE
	}
}

// ---------------------------------------------------------------- effective addresses

// mode index of a 6 bit mode/register field: 0-6 for modes 0-6, 7-11 for abs.W, abs.L,
// d16(PC), d8(PC,Xn), #imm. -1 if invalid.
static inline int eai(int ea)
{
	int m = (ea >> 3) & 7;

	if (m < 7)
		return m;
	m = ea & 7;
	return (m <= 4) ? 7 + m : -1;
}

static inline int ea_ok(int ea, int cat)
{
	int i = eai(ea);
	return (i >= 0) && ((cat >> i) & 1);
}

// clocks for calculating an effective address: [mode index][long]
static const uint8_t ea_clk[12][2] = {
	{ 0, 0 }, { 0, 0 }, { 4, 8 }, { 4, 8 }, { 6, 10 }, { 8, 12 },
	{ 10, 14 }, { 8, 12 }, { 12, 16 }, { 8, 12 }, { 10, 14 }, { 4, 8 }
};

static uint32_t index_ext(uint32_t base)
{
	uint16_t ext = fetch16();
	int r = (ext >> 12) & 15;
	uint32_t x = (r < 8) ? D[r] : A[r - 8];

	if (!(ext & 0x800))
		x = (int16_t)x;
	return base + x + (int8_t)ext;
}

// address of a memory operand (modes 2-7, not immediate); applies (An)+ and -(An)
static uint32_t ea_addr(int ea, int sz)
{
	int reg = ea & 7;
	uint32_t a, b;

	cycles += ea_clk[eai(ea)][sz == 2];
	switch ((ea >> 3) & 7)
	{
		case 2:
			return A[reg];
		case 3:
			a = A[reg];
			A[reg] += (sz == 0 && reg == 7) ? 2 : szbytes[sz];
			return a;
		case 4:
			A[reg] -= (sz == 0 && reg == 7) ? 2 : szbytes[sz];
			return A[reg];
		case 5:
			return A[reg] + (int16_t)fetch16();
		case 6:
			return index_ext(A[reg]);
		default:
			switch (reg)
			{
				case 0:
					return (int16_t)fetch16();
				case 1:
					return fetch32();
				case 2:
					b = pc;
					return b + (int16_t)fetch16();
				default:
					return index_ext(pc);
			}
	}
}

// a resolved operand: register or memory address
typedef struct {
	int ea;
	uint32_t addr;
} ea_t;

static void ea_resolve(ea_t *e, int ea, int sz)
{
	e->ea = ea;
	if (ea >= 0x10 && ea != 0x3c)
		e->addr = ea_addr(ea, sz);
}

static uint32_t ea_get(ea_t *e, int sz)
{
	int ea = e->ea;

	if (ea < 8)
		return D[ea] & szmask[sz];
	if (ea < 16)
		return A[ea & 7] & szmask[sz];
	if (ea == 0x3c)
	{
		cycles += ea_clk[11][sz == 2];
		if (sz == 2)
			return fetch32();
		return fetch16() & szmask[sz];
	}
	return rd_sz(e->addr, sz);
}

static void ea_put(ea_t *e, int sz, uint32_t v)
{
	int ea = e->ea;

	if (ea < 8)
		D[ea] = (D[ea] & ~szmask[sz]) | (v & szmask[sz]);
	else if (ea < 16)
		A[ea & 7] = v; // only reached with long values
	else
		wr_sz(e->addr, sz, v);
}

static uint32_t ea_read(int ea, int sz)
{
	ea_t e;

	ea_resolve(&e, ea, sz);
	return ea_get(&e, sz);
}

static void ea_write(int ea, int sz, uint32_t v)
{
	ea_t e;

	ea_resolve(&e, ea, sz);
	ea_put(&e, sz, v);
}

// ---------------------------------------------------------------- arithmetic

static inline void flags_logic(uint32_t r, int sz)
{
	r &= szmask[sz];
	sr &= ~(SR_N | SR_Z | SR_V | SR_C);
	if (r & szmsb[sz])
		sr |= SR_N;
	if (r == 0)
		sr |= SR_Z;
}

// d + s + x. keepz: Z is only cleared (ADDX)
static uint32_t alu_add(uint32_t s, uint32_t d, int sz, int x, int keepz)
{
	uint32_t m = szmask[sz], msb = szmsb[sz];
	uint64_t r64;
	uint32_t r;
	uint16_t f;

	s &= m;
	d &= m;
	r64 = (uint64_t)s + d + x;
	r = r64 & m;
	f = sr & ~0x1f;
	if (r & msb)
		f |= SR_N;
	if (r == 0)
		f |= keepz ? (sr & SR_Z) : SR_Z;
	if (~(s ^ d) & (s ^ r) & msb)
		f |= SR_V;
	if (r64 > m)
		f |= SR_C | SR_X;
	sr = f;
	return r;
}

// d - s - x. keepz: Z is only cleared (SUBX, NEGX). setx = 0: X is not affected (CMP)
static uint32_t alu_sub(uint32_t s, uint32_t d, int sz, int x, int keepz, int setx)
{
	uint32_t m = szmask[sz], msb = szmsb[sz];
	uint32_t r;
	uint16_t f;

	s &= m;
	d &= m;
	r = (d - s - x) & m;
	f = sr & ~(setx ? 0x1f : 0x0f);
	if (r & msb)
		f |= SR_N;
	if (r == 0)
		f |= keepz ? (sr & SR_Z) : SR_Z;
	if ((s ^ d) & (r ^ d) & msb)
		f |= SR_V;
	if ((uint64_t)s + x > d)
		f |= setx ? (SR_C | SR_X) : SR_C;
	sr = f;
	return r;
}

// BCD arithmetic. N and V are officially undefined; these follow the real chip (as measured
// for MAME's 68000 core).
static uint8_t bcd_add(uint8_t s, uint8_t d)
{
	uint32_t r = (s & 0x0f) + (d & 0x0f) + ((sr & SR_X) ? 1 : 0);
	uint32_t corf = (r > 9) ? 6 : 0;
	uint32_t v;

	r += (s & 0xf0) + (d & 0xf0);
	v = ~r;
	r += corf;
	sr &= ~(SR_X | SR_C | SR_V | SR_N);
	if (r > 0x9f)
	{
		r -= 0xa0;
		sr |= SR_X | SR_C;
	}
	if (v & r & 0x80)
		sr |= SR_V;
	if (r & 0x80)
		sr |= SR_N;
	if (r & 0xff)
		sr &= ~SR_Z;
	return r;
}

static uint8_t bcd_sub(uint8_t s, uint8_t d)
{
	uint32_t r = (d & 0x0f) - (s & 0x0f) - ((sr & SR_X) ? 1 : 0);
	uint32_t corf = (r > 0x0f) ? 6 : 0;
	uint32_t v;

	r += (d & 0xf0) - (s & 0xf0);
	v = r;
	sr &= ~(SR_X | SR_C | SR_V | SR_N);
	if (r > 0xff)
	{
		r += 0xa0;
		sr |= SR_X | SR_C;
	}
	r = (r - corf) & 0xff;
	if (v & ~r & 0x80)
		sr |= SR_V;
	if (r & 0x80)
		sr |= SR_N;
	if (r)
		sr &= ~SR_Z;
	return r;
}

static uint8_t bcd_neg(uint8_t d)
{
	uint32_t r = (0x9a - d - ((sr & SR_X) ? 1 : 0)) & 0xff;

	sr &= ~(SR_X | SR_C | SR_V | SR_N);
	if (r != 0x9a)
	{
		uint32_t v = ~r;

		if ((r & 0x0f) == 0x0a)
			r = (r & 0xf0) + 0x10;
		r &= 0xff;
		if (v & r & 0x80)
			sr |= SR_V;
		if (r)
			sr &= ~SR_Z;
		sr |= SR_X | SR_C;
	}
	if (r & 0x80)
		sr |= SR_N;
	return (r == 0x9a) ? d : r; // nothing to subtract: the operand is left alone
}

// shift/rotate. type: 0 AS, 1 LS, 2 ROX, 3 RO
static uint32_t do_shift(int type, int left, uint32_t v, int cnt, int sz)
{
	uint32_t m = szmask[sz], msb = szmsb[sz];
	int c = 0, ov = 0, x = (sr & SR_X) ? 1 : 0, i;
	uint16_t f;

	v &= m;
	for (i = 0; i < cnt; i++)
	{
		if (left)
		{
			c = (v & msb) != 0;
			switch (type)
			{
				case 0:
					if ((v ^ (v << 1)) & msb)
						ov = 1;
					v = (v << 1) & m;
					break;
				case 1: v = (v << 1) & m; break;
				case 2: v = ((v << 1) | x) & m; x = c; break;
				default: v = ((v << 1) | c) & m; break;
			}
		}
		else
		{
			c = v & 1;
			switch (type)
			{
				case 0: v = (v >> 1) | (v & msb); break;
				case 1: v >>= 1; break;
				case 2: v = (v >> 1) | (x ? msb : 0); x = c; break;
				default: v = (v >> 1) | (c ? msb : 0); break;
			}
		}
	}
	f = sr & (0xff00 | SR_X);
	if (cnt == 0)
	{
		if (type == 2 && x)
			f |= SR_C;
	}
	else
	{
		if (c)
			f |= SR_C;
		if (type != 3)
			f = (f & ~SR_X) | (c ? SR_X : 0);
	}
	if (v & msb)
		f |= SR_N;
	if (v == 0)
		f |= SR_Z;
	if (ov)
		f |= SR_V;
	sr = f;
	return v;
}

// ---------------------------------------------------------------- instructions

static void op_illegal(uint16_t op)
{
	pc = ppc;
	if ((op & 0xf000) == 0xa000)
		exception(V_LINEA);
	else if ((op & 0xf000) == 0xf000)
		exception(V_LINEF);
	else
		exception(V_ILLEGAL);
}

static int privileged(void)
{
	if (sr & SR_S)
		return 1;
	pc = ppc;
	exception(V_PRIV);
	return 0;
}

// ORI/ANDI/EORI to CCR and SR
static void op_logi_sr(uint16_t op)
{
	uint16_t v = fetch16();
	uint16_t cur = (op & 0x40) ? sr : (sr & 0xff);

	if ((op & 0x40) && !privileged())
		return;
	switch (op & 0x0f00)
	{
		case 0x0000: cur |= v; break;
		case 0x0200: cur &= v; break;
		default: cur ^= v; break;
	}
	if (op & 0x40)
		set_sr(cur);
	else
		set_ccr(cur);
	cycles += 20;
}

// ORI, ANDI, SUBI, ADDI, EORI, CMPI
static void op_imm(uint16_t op)
{
	int sz = (op >> 6) & 3;
	uint32_t s = (sz == 2) ? fetch32() : (fetch16() & szmask[sz]);
	ea_t e;
	uint32_t d, r;

	ea_resolve(&e, op & 0x3f, sz);
	d = ea_get(&e, sz);
	cycles += (sz == 2) ? 16 : 8;
	switch ((op >> 9) & 7)
	{
		case 0: r = d | s; flags_logic(r, sz); break;
		case 1: r = d & s; flags_logic(r, sz); break;
		case 2: r = alu_sub(s, d, sz, 0, 0, 1); break;
		case 3: r = alu_add(s, d, sz, 0, 0); break;
		case 5: r = d ^ s; flags_logic(r, sz); break;
		default: alu_sub(s, d, sz, 0, 0, 0); return; // CMPI
	}
	ea_put(&e, sz, r);
	if (e.ea >= 16)
		cycles += 4;
}

static void bit_op(uint16_t op, uint32_t bit)
{
	int ea = op & 0x3f;
	int type = (op >> 6) & 3;
	ea_t e;
	uint32_t v, mask;
	int sz = (ea < 8) ? 2 : 0;

	ea_resolve(&e, ea, sz);
	v = ea_get(&e, sz);
	mask = 1u << (bit & ((sz == 2) ? 31 : 7));
	if (v & mask)
		sr &= ~SR_Z;
	else
		sr |= SR_Z;
	cycles += (sz == 2) ? 6 : 4;
	switch (type)
	{
		case 0: return;
		case 1: v ^= mask; break;
		case 2: v &= ~mask; break;
		default: v |= mask; break;
	}
	cycles += 4;
	ea_put(&e, sz, v);
}

static void op_bit_dyn(uint16_t op)
{
	bit_op(op, D[(op >> 9) & 7]);
}

static void op_bit_st(uint16_t op)
{
	uint32_t bit = fetch16() & 0xff;
	cycles += 4;
	bit_op(op, bit);
}

static void op_movep(uint16_t op)
{
	int dn = (op >> 9) & 7;
	uint32_t a = A[op & 7] + (int16_t)fetch16();
	int mode = (op >> 6) & 7;

	switch (mode)
	{
		case 4:
			D[dn] = (D[dn] & 0xffff0000) | (rd8(a) << 8) | rd8(a + 2);
			cycles += 16;
			break;
		case 5:
			D[dn] = (rd8(a) << 24) | (rd8(a + 2) << 16) | (rd8(a + 4) << 8) | rd8(a + 6);
			cycles += 24;
			break;
		case 6:
			wr8(a, D[dn] >> 8);
			wr8(a + 2, D[dn]);
			cycles += 16;
			break;
		default:
			wr8(a, D[dn] >> 24);
			wr8(a + 2, D[dn] >> 16);
			wr8(a + 4, D[dn] >> 8);
			wr8(a + 6, D[dn]);
			cycles += 24;
			break;
	}
}

static const int move_sz[4] = { 0, 0, 2, 1 }; // line 1 = byte, 2 = long, 3 = word

static void op_move(uint16_t op)
{
	int sz = move_sz[op >> 12];
	uint32_t v = ea_read(op & 0x3f, sz);
	int dst = ((op >> 9) & 7) | ((op >> 3) & 0x38);

	flags_logic(v, sz);
	ea_write(dst, sz, v);
	cycles += 4;
}

static void op_movea(uint16_t op)
{
	int sz = move_sz[op >> 12];
	uint32_t v = ea_read(op & 0x3f, sz);

	A[(op >> 9) & 7] = (sz == 1) ? (uint32_t)(int16_t)v : v;
	cycles += 4;
}

// NEGX, CLR, NEG, NOT
static void op_unary(uint16_t op)
{
	int sz = (op >> 6) & 3;
	ea_t e;
	uint32_t v, r;

	ea_resolve(&e, op & 0x3f, sz);
	switch (op & 0x0f00)
	{
		case 0x0000: v = ea_get(&e, sz); r = alu_sub(v, 0, sz, (sr & SR_X) ? 1 : 0, 1, 1); break;
		case 0x0200: if (e.ea >= 16) ea_get(&e, sz); r = 0; flags_logic(0, sz); break;
		case 0x0400: v = ea_get(&e, sz); r = alu_sub(v, 0, sz, 0, 0, 1); break;
		default: v = ea_get(&e, sz); r = ~v; flags_logic(r, sz); break;
	}
	ea_put(&e, sz, r);
	cycles += (sz == 2) ? 6 : 4;
	if (e.ea >= 16)
		cycles += (sz == 2) ? 6 : 4;
}

static void op_move_from_sr(uint16_t op)
{
	ea_write(op & 0x3f, 1, sr);
	cycles += 6;
}

static void op_move_to_ccr(uint16_t op)
{
	set_ccr(ea_read(op & 0x3f, 1));
	cycles += 12;
}

static void op_move_to_sr(uint16_t op)
{
	if (!privileged())
		return;
	set_sr(ea_read(op & 0x3f, 1));
	cycles += 12;
}

static void op_nbcd(uint16_t op)
{
	ea_t e;

	ea_resolve(&e, op & 0x3f, 0);
	ea_put(&e, 0, bcd_neg(ea_get(&e, 0)));
	cycles += 6;
}

static void op_swap(uint16_t op)
{
	uint32_t v = D[op & 7];

	v = (v << 16) | (v >> 16);
	D[op & 7] = v;
	flags_logic(v, 2);
	cycles += 4;
}

static void op_pea(uint16_t op)
{
	uint32_t a = ea_addr(op & 0x3f, 2);
	push32(a);
	cycles += 8;
}

static void op_ext(uint16_t op)
{
	int r = op & 7;

	if (op & 0x40)
	{
		D[r] = (int16_t)D[r];
		flags_logic(D[r], 2);
	}
	else
	{
		D[r] = (D[r] & 0xffff0000) | (uint16_t)(int8_t)D[r];
		flags_logic(D[r], 1);
	}
	cycles += 4;
}

static void op_movem(uint16_t op)
{
	uint16_t list = fetch16();
	int sz = (op & 0x40) ? 2 : 1;
	int ea = op & 0x3f;
	int mode = (ea >> 3) & 7;
	int i;
	uint32_t a;

	if (op & 0x400)
	{
		// memory to registers
		if (mode == 3)
			a = A[ea & 7];
		else
			a = ea_addr(ea, sz);
		for (i = 0; i < 16; i++)
		{
			if (list & (1 << i))
			{
				uint32_t v = (sz == 2) ? rd32(a) : (uint32_t)(int16_t)rd16(a);
				if (i < 8)
					D[i] = v;
				else
					A[i - 8] = v;
				a += szbytes[sz];
				cycles += (sz == 2) ? 8 : 4;
			}
		}
		if (mode == 3)
			A[ea & 7] = a;
		cycles += 12;
	}
	else if (mode == 4)
	{
		// registers to -(An): bit 0 = A7 ... bit 15 = D0
		a = A[ea & 7];
		for (i = 0; i < 16; i++)
		{
			if (list & (1 << i))
			{
				uint32_t v = (i < 8) ? A[7 - i] : D[15 - i];
				a -= szbytes[sz];
				if (sz == 2)
					wr32(a, v);
				else
					wr16(a, v);
				cycles += (sz == 2) ? 8 : 4;
			}
		}
		A[ea & 7] = a;
		cycles += 8;
	}
	else
	{
		a = ea_addr(ea, sz);
		for (i = 0; i < 16; i++)
		{
			if (list & (1 << i))
			{
				uint32_t v = (i < 8) ? D[i] : A[i - 8];
				if (sz == 2)
					wr32(a, v);
				else
					wr16(a, v);
				a += szbytes[sz];
				cycles += (sz == 2) ? 8 : 4;
			}
		}
		cycles += 8;
	}
}

static void op_tst(uint16_t op)
{
	int sz = (op >> 6) & 3;
	flags_logic(ea_read(op & 0x3f, sz), sz);
	cycles += 4;
}

static void op_tas(uint16_t op)
{
	ea_t e;
	uint32_t v;

	ea_resolve(&e, op & 0x3f, 0);
	v = ea_get(&e, 0);
	flags_logic(v, 0);
	ea_put(&e, 0, v | 0x80);
	cycles += (e.ea < 8) ? 4 : 14;
}

static void op_trap(uint16_t op)
{
	exception(V_TRAP + (op & 15));
}

static void op_link(uint16_t op)
{
	int r = op & 7;
	int16_t d;

	push32(A[r]);
	A[r] = A[7];
	d = fetch16();
	A[7] += d;
	cycles += 16;
}

static void op_unlk(uint16_t op)
{
	int r = op & 7;

	A[7] = A[r];
	A[r] = pop32();
	cycles += 12;
}

static void op_move_usp(uint16_t op)
{
	if (!privileged())
		return;
	if (op & 8)
		A[op & 7] = other_sp;
	else
		other_sp = A[op & 7];
	cycles += 4;
}

static void op_reset(uint16_t op)
{
	if (!privileged())
		return;
	cycles += 132; // asserts RESET for external devices; nothing to do here
}

static void op_nop(uint16_t op)
{
	cycles += 4;
}

static void op_stop(uint16_t op)
{
	uint16_t v;

	if (!privileged())
		return;
	v = fetch16();
	set_sr(v);
	stopped = 1;
	cycles += 4;
}

static void op_rte(uint16_t op)
{
	uint16_t v;

	if (!privileged())
		return;
	v = pop16();
	pc = pop32();
	set_sr(v);
	cycles += 20;
}

static void op_rts(uint16_t op)
{
	pc = pop32();
	cycles += 16;
}

static void op_trapv(uint16_t op)
{
	cycles += 4;
	if (sr & SR_V)
		exception(V_TRAPV);
}

static void op_rtr(uint16_t op)
{
	set_ccr(pop16());
	pc = pop32();
	cycles += 20;
}

static void op_jsr(uint16_t op)
{
	uint32_t a = ea_addr(op & 0x3f, 2);
	push32(pc);
	pc = a;
	cycles += 8;
}

static void op_jmp(uint16_t op)
{
	pc = ea_addr(op & 0x3f, 2);
	cycles += 4;
}

static void op_chk(uint16_t op)
{
	int16_t bound = ea_read(op & 0x3f, 1);
	int16_t v = D[(op >> 9) & 7];

	cycles += 10;
	if (v < 0)
	{
		sr |= SR_N;
		exception(V_CHK);
	}
	else if (v > bound)
	{
		sr &= ~SR_N;
		exception(V_CHK);
	}
}

static void op_lea(uint16_t op)
{
	A[(op >> 9) & 7] = ea_addr(op & 0x3f, 2);
	cycles += 4;
}

// ADDQ, SUBQ
static void op_addq(uint16_t op)
{
	int sz = (op >> 6) & 3;
	uint32_t q = (op >> 9) & 7;
	int ea = op & 0x3f;
	ea_t e;
	uint32_t r;

	if (q == 0)
		q = 8;
	if ((ea >> 3) == 1)
	{
		// address register: whole register, no flags
		if (op & 0x100)
			A[ea & 7] -= q;
		else
			A[ea & 7] += q;
		cycles += 8;
		return;
	}
	ea_resolve(&e, ea, sz);
	if (op & 0x100)
		r = alu_sub(q, ea_get(&e, sz), sz, 0, 0, 1);
	else
		r = alu_add(q, ea_get(&e, sz), sz, 0, 0);
	ea_put(&e, sz, r);
	cycles += (sz == 2) ? 8 : 4;
	if (ea >= 16)
		cycles += 4;
}

static void op_scc(uint16_t op)
{
	ea_write(op & 0x3f, 0, test_cc((op >> 8) & 15) ? 0xff : 0);
	cycles += 6;
}

static void op_dbcc(uint16_t op)
{
	int16_t disp = fetch16();
	int r = op & 7;
	uint16_t v;

	if (test_cc((op >> 8) & 15))
	{
		cycles += 12;
		return;
	}
	v = D[r] - 1;
	D[r] = (D[r] & 0xffff0000) | v;
	if (v != 0xffff)
	{
		pc = ppc + 2 + disp;
		cycles += 10;
	}
	else
		cycles += 14;
}

static void op_bcc(uint16_t op)
{
	int cc = (op >> 8) & 15;
	int32_t disp = (int8_t)op;
	uint32_t base = pc;

	if (disp == 0)
		disp = (int16_t)fetch16();
	if (cc == 1)
	{
		// BSR
		push32(pc);
		pc = base + disp;
		cycles += 18;
		return;
	}
	if (test_cc(cc))
	{
		pc = base + disp;
		cycles += 10;
	}
	else
		cycles += 8;
}

static void op_moveq(uint16_t op)
{
	uint32_t v = (int8_t)op;

	D[(op >> 9) & 7] = v;
	flags_logic(v, 2);
	cycles += 4;
}

// OR, AND, SUB, ADD, CMP, EOR between a data register and an effective address
static void op_alu(uint16_t op)
{
	int sz = (op >> 6) & 3;
	int dn = (op >> 9) & 7;
	int line = op >> 12;
	ea_t e;
	uint32_t s, d, r;

	if (!(op & 0x100) || line == 0xb)
	{
		// <ea>,Dn (and EOR Dn,<ea>)
		if (line == 0xb && (op & 0x100))
		{
			ea_resolve(&e, op & 0x3f, sz);
			r = ea_get(&e, sz) ^ D[dn];
			flags_logic(r, sz);
			ea_put(&e, sz, r);
			cycles += (e.ea < 8) ? ((sz == 2) ? 8 : 4) : ((sz == 2) ? 12 : 8);
			return;
		}
		s = ea_read(op & 0x3f, sz);
		d = D[dn];
		cycles += (sz == 2) ? 6 : 4;
		switch (line)
		{
			case 0x8: r = d | s; flags_logic(r, sz); break;
			case 0xc: r = d & s; flags_logic(r, sz); break;
			case 0x9: r = alu_sub(s, d, sz, 0, 0, 1); break;
			case 0xd: r = alu_add(s, d, sz, 0, 0); break;
			default: alu_sub(s, d, sz, 0, 0, 0); return; // CMP
		}
		D[dn] = (D[dn] & ~szmask[sz]) | (r & szmask[sz]);
		return;
	}
	// Dn,<ea>
	ea_resolve(&e, op & 0x3f, sz);
	d = ea_get(&e, sz);
	s = D[dn];
	switch (line)
	{
		case 0x8: r = d | s; flags_logic(r, sz); break;
		case 0xc: r = d & s; flags_logic(r, sz); break;
		case 0x9: r = alu_sub(s, d, sz, 0, 0, 1); break;
		default: r = alu_add(s, d, sz, 0, 0); break;
	}
	ea_put(&e, sz, r);
	cycles += (sz == 2) ? 12 : 8;
}

// ADDA, SUBA, CMPA
static void op_alua(uint16_t op)
{
	int sz = (op & 0x100) ? 2 : 1;
	uint32_t s = ea_read(op & 0x3f, sz);
	int an = (op >> 9) & 7;

	if (sz == 1)
		s = (int16_t)s;
	switch (op >> 12)
	{
		case 0x9: A[an] -= s; break;
		case 0xd: A[an] += s; break;
		default: alu_sub(s, A[an], 2, 0, 0, 0); break;
	}
	cycles += 8;
}

// ADDX, SUBX, ABCD, SBCD
static void op_xop(uint16_t op)
{
	int line = op >> 12;
	int sz = (line == 0x8 || line == 0xc) ? 0 : ((op >> 6) & 3);
	int rx = (op >> 9) & 7, ry = op & 7;
	uint32_t s, d, r, a = 0;
	int x = (sr & SR_X) ? 1 : 0;

	if (op & 8)
	{
		// -(Ay),-(Ax)
		s = rd_sz(A[ry] -= ((sz == 0 && ry == 7) ? 2 : szbytes[sz]), sz);
		a = (A[rx] -= ((sz == 0 && rx == 7) ? 2 : szbytes[sz]));
		d = rd_sz(a, sz);
		cycles += (sz == 2) ? 30 : 18;
	}
	else
	{
		s = D[ry];
		d = D[rx];
		cycles += (sz == 2) ? 8 : 4;
	}
	switch (line)
	{
		case 0x8: r = bcd_sub(s, d); break;
		case 0xc: r = bcd_add(s, d); break;
		case 0x9: r = alu_sub(s, d, sz, x, 1, 1); break;
		default: r = alu_add(s, d, sz, x, 1); break;
	}
	if (op & 8)
		wr_sz(a, sz, r);
	else
		D[rx] = (D[rx] & ~szmask[sz]) | (r & szmask[sz]);
}

static void op_cmpm(uint16_t op)
{
	int sz = (op >> 6) & 3;
	int rx = (op >> 9) & 7, ry = op & 7;
	uint32_t s, d;

	s = rd_sz(A[ry], sz);
	A[ry] += (sz == 0 && ry == 7) ? 2 : szbytes[sz];
	d = rd_sz(A[rx], sz);
	A[rx] += (sz == 0 && rx == 7) ? 2 : szbytes[sz];
	alu_sub(s, d, sz, 0, 0, 0);
	cycles += (sz == 2) ? 20 : 12;
}

static void op_exg(uint16_t op)
{
	int rx = (op >> 9) & 7, ry = op & 7;
	uint32_t t;

	switch (op & 0xf8)
	{
		case 0x40: t = D[rx]; D[rx] = D[ry]; D[ry] = t; break;
		case 0x48: t = A[rx]; A[rx] = A[ry]; A[ry] = t; break;
		default: t = D[rx]; D[rx] = A[ry]; A[ry] = t; break;
	}
	cycles += 6;
}

static void op_mul(uint16_t op)
{
	uint16_t s = ea_read(op & 0x3f, 1);
	int dn = (op >> 9) & 7;
	uint32_t r;

	if (op & 0x100)
		r = (int32_t)(int16_t)s * (int32_t)(int16_t)D[dn];
	else
		r = (uint32_t)s * (uint16_t)D[dn];
	D[dn] = r;
	flags_logic(r, 2);
	cycles += 70;
}

static void op_div(uint16_t op)
{
	uint16_t s = ea_read(op & 0x3f, 1);
	int dn = (op >> 9) & 7;

	if (s == 0)
	{
		cycles += 38;
		exception(V_ZERODIV);
		return;
	}
	if (op & 0x100)
	{
		int32_t n = D[dn];
		int32_t q, rem;

		cycles += 158;
		if (n == INT32_MIN && (int16_t)s == -1)
		{
			sr = (sr & ~(SR_C | SR_Z)) | SR_V | SR_N;
			return;
		}
		q = n / (int16_t)s;
		rem = n % (int16_t)s;
		if (q < -32768 || q > 32767)
		{
			sr = (sr & ~(SR_C | SR_Z)) | SR_V | SR_N;
			return;
		}
		D[dn] = ((uint32_t)(uint16_t)rem << 16) | (uint16_t)q;
		flags_logic(q, 1);
	}
	else
	{
		uint32_t n = D[dn];
		uint32_t q = n / s, rem = n % s;

		cycles += 140;
		if (q > 0xffff)
		{
			sr = (sr & ~(SR_C | SR_Z)) | SR_V | SR_N;
			return;
		}
		D[dn] = (rem << 16) | q;
		flags_logic(q, 1);
	}
}

static void op_shift_reg(uint16_t op)
{
	int sz = (op >> 6) & 3;
	int cnt = (op >> 9) & 7;
	int r = op & 7;
	uint32_t v;

	if (op & 0x20)
		cnt = D[cnt] & 63;
	else if (cnt == 0)
		cnt = 8;
	v = do_shift((op >> 3) & 3, (op >> 8) & 1, D[r], cnt, sz);
	D[r] = (D[r] & ~szmask[sz]) | v;
	cycles += ((sz == 2) ? 8 : 6) + 2 * cnt;
}

static void op_shift_mem(uint16_t op)
{
	ea_t e;

	ea_resolve(&e, op & 0x3f, 1);
	ea_put(&e, 1, do_shift((op >> 9) & 3, (op >> 8) & 1, ea_get(&e, 1), 1, 1));
	cycles += 8;
}

// ---------------------------------------------------------------- decoding

static handler_t classify(uint16_t op)
{
	int ea = op & 0x3f;
	int sz = (op >> 6) & 3;
	int mode = (ea >> 3) & 7;
	int line = op >> 12;

	switch (line)
	{
		case 0x0:
			if (op == 0x003c || op == 0x023c || op == 0x0a3c || op == 0x007c || op == 0x027c || op == 0x0a7c)
				return op_logi_sr;
			if ((op & 0xf138) == 0x0108)
				return op_movep;
			if (op & 0x100)
				return ea_ok(ea, (sz == 0) ? C_DATA : C_DALT) ? op_bit_dyn : 0;
			switch ((op >> 9) & 7)
			{
				case 4:
					return ea_ok(ea, (sz == 0) ? (C_DATA & ~EM_IMM) : C_DALT) ? op_bit_st : 0;
				case 7:
					return 0;
				default:
					return (sz != 3 && ea_ok(ea, C_DALT)) ? op_imm : 0;
			}

		case 0x1:
		case 0x2:
		case 0x3:
		{
			int dmode = (op >> 6) & 7;
			int dst = ((op >> 9) & 7) | (dmode << 3);

			if (!ea_ok(ea, C_ALL) || (line == 1 && mode == 1))
				return 0;
			if (dmode == 1)
				return (line == 1) ? 0 : op_movea;
			return ea_ok(dst, C_DALT) ? op_move : 0;
		}

		case 0x4:
			switch (op)
			{
				case 0x4e70: return op_reset;
				case 0x4e71: return op_nop;
				case 0x4e72: return op_stop;
				case 0x4e73: return op_rte;
				case 0x4e75: return op_rts;
				case 0x4e76: return op_trapv;
				case 0x4e77: return op_rtr;
				case 0x4afc: return 0;
			}
			if ((op & 0xfff0) == 0x4e40) return op_trap;
			if ((op & 0xfff8) == 0x4e50) return op_link;
			if ((op & 0xfff8) == 0x4e58) return op_unlk;
			if ((op & 0xfff0) == 0x4e60) return op_move_usp;
			if ((op & 0xffc0) == 0x4e80) return ea_ok(ea, C_CTRL) ? op_jsr : 0;
			if ((op & 0xffc0) == 0x4ec0) return ea_ok(ea, C_CTRL) ? op_jmp : 0;
			if ((op & 0xf1c0) == 0x4180) return ea_ok(ea, C_DATA) ? op_chk : 0;
			if ((op & 0xf1c0) == 0x41c0) return ea_ok(ea, C_CTRL) ? op_lea : 0;
			if ((op & 0xffc0) == 0x40c0) return ea_ok(ea, C_DALT) ? op_move_from_sr : 0;
			if ((op & 0xffc0) == 0x44c0) return ea_ok(ea, C_DATA) ? op_move_to_ccr : 0;
			if ((op & 0xffc0) == 0x46c0) return ea_ok(ea, C_DATA) ? op_move_to_sr : 0;
			if ((op & 0xf900) == 0x4000 && sz != 3) return ea_ok(ea, C_DALT) ? op_unary : 0;
			if ((op & 0xffc0) == 0x4800) return ea_ok(ea, C_DALT) ? op_nbcd : 0;
			if ((op & 0xfff8) == 0x4840) return op_swap;
			if ((op & 0xffc0) == 0x4840) return ea_ok(ea, C_CTRL) ? op_pea : 0;
			if ((op & 0xffb8) == 0x4880) return op_ext;
			if ((op & 0xff80) == 0x4880) return ea_ok(ea, (C_CTRL & C_ALT) | EM_PD) ? op_movem : 0;
			if ((op & 0xff80) == 0x4c80) return ea_ok(ea, C_CTRL | EM_PI) ? op_movem : 0;
			if ((op & 0xff00) == 0x4a00 && sz != 3) return ea_ok(ea, C_DALT) ? op_tst : 0;
			if ((op & 0xffc0) == 0x4ac0) return ea_ok(ea, C_DALT) ? op_tas : 0;
			return 0;

		case 0x5:
			if (sz == 3)
			{
				if (mode == 1)
					return op_dbcc;
				return ea_ok(ea, C_DALT) ? op_scc : 0;
			}
			if (sz == 0 && mode == 1)
				return 0;
			return ea_ok(ea, C_ALT) ? op_addq : 0;

		case 0x6:
			return op_bcc;

		case 0x7:
			return (op & 0x100) ? 0 : op_moveq;

		case 0x8:
		case 0xc:
			if ((op & 0x1c0) == 0x0c0)
				return ea_ok(ea, C_DATA) ? ((line == 8) ? op_div : op_mul) : 0;
			if ((op & 0x1c0) == 0x1c0)
				return ea_ok(ea, C_DATA) ? ((line == 8) ? op_div : op_mul) : 0;
			if ((op & 0x1f0) == 0x100)
				return op_xop; // SBCD, ABCD
			if (line == 0xc && ((op & 0x1f8) == 0x140 || (op & 0x1f8) == 0x148 || (op & 0x1f8) == 0x188))
				return op_exg;
			if (op & 0x100)
				return ea_ok(ea, C_MALT) ? op_alu : 0;
			return ea_ok(ea, C_DATA) ? op_alu : 0;

		case 0x9:
		case 0xd:
			if (sz == 3)
				return ea_ok(ea, C_ALL) ? op_alua : 0;
			if ((op & 0x130) == 0x100)
				return op_xop; // SUBX, ADDX
			if (op & 0x100)
				return ea_ok(ea, C_MALT) ? op_alu : 0;
			if (sz == 0 && mode == 1)
				return 0;
			return ea_ok(ea, C_ALL) ? op_alu : 0;

		case 0xb:
			if (sz == 3)
				return ea_ok(ea, C_ALL) ? op_alua : 0;
			if (op & 0x100)
			{
				if (mode == 1)
					return op_cmpm;
				return ea_ok(ea, C_DALT) ? op_alu : 0;
			}
			if (sz == 0 && mode == 1)
				return 0;
			return ea_ok(ea, C_ALL) ? op_alu : 0;

		case 0xe:
			if (sz == 3)
				return (!(op & 0x800) && ea_ok(ea, C_MALT)) ? op_shift_mem : 0;
			return op_shift_reg;

		default:
			return 0;
	}
}

static void init_tables(void)
{
	int i;

	for (i = 0; i < 65536; i++)
	{
		optab[i] = classify(i);
		if (!optab[i])
			optab[i] = op_illegal;
	}
}

// ---------------------------------------------------------------- exceptions

static void exception(int vec)
{
	uint16_t old = sr;

	in_exception = 1;
	set_sr((sr | SR_S) & ~SR_T);
	push32(pc);
	push16(old);
	pc = rd32(vec * 4);
	in_exception = 0;
	cycles += 34;
}

void engine_m68k_reset()
{
	stopped = 0;
	halted = 0;
	irq_level = 0;
	in_exception = 0;
	sr = SR_S | 0x0700;
	other_sp = 0;
	A[7] = m68k_mem_read32(0);
	pc = m68k_mem_read32(4);
	cycles += 40;
}

int engine_m68k_init()
{
	int i;

	m68k_driver_startup();
	init_tables();
	for (i = 0; i < 8; i++)
		D[i] = A[i] = 0;
	cycles = 0;
	engine_m68k_reset();
	return 0;
}

void engine_m68k_step()
{
	int trace;

	if (halted)
		return;
	if (setjmp(abort_jmp))
	{
		in_exception = 0;
		return; // an address error (or double fault) cut the instruction short
	}

	// interrupts: level 7 is non-maskable
	if (irq_level && (irq_level == 7 || irq_level > ((sr >> 8) & 7)))
	{
		int level = irq_level;

		irq_level = 0;
		stopped = 0;
		ppc = pc;
		exception(V_AUTO + level);
		sr = (sr & ~0x0700) | (level << 8);
		cycles += 10;
		return;
	}
	if (stopped)
	{
		cycles += 4;
		return;
	}

	trace = sr & SR_T;
	ppc = pc;
	ir = fetch16();
	optab[ir](ir);
	if (trace)
		exception(V_TRACE);
}

void engine_m68k_irq(int level)
{
	irq_level = level & 7;
}

long engine_m68k_cycle_count()
{
	return cycles;
}

int engine_m68k_halted()
{
	return stopped || halted;
}
