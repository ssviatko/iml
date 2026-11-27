#ifndef IO_DRIVER_H
#define IO_DRIVER_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/msg.h>
#include <sys/shm.h>
#include <sys/ipc.h> // for ftok
#include <errno.h>
#include <time.h>
#include <tgmath.h>

#define SHM_SIZE 2097152
#define SHM_MODE 0600
#define MSQ_MODE 0600
#define MEMTOP 0x1fffff

typedef struct __attribute__((packed)) {
	long type;
	uint16_t address;
	uint8_t byte;
} io_message_t;

// video space
const static uint32_t VIDSTART = 0x180000;
const static uint32_t VIDEND = 0x1bfbff;
const static uint32_t IOSTART = 0x1bfc00;
const static uint32_t IOEND = 0x1bffff;

// reserved memory spaces
const static uint32_t ZEROPAGESTART = 0x000000;
const static uint32_t ZEROPAGEEND = 0x0000ff;
const static uint32_t E400ROMSTART = 0x00e400;
const static uint32_t E400ROMEND = 0x00ffff;
const static uint32_t X1CROMSTART = 0x1c0000;
const static uint32_t X1CROMEND = 0x1fffff;
const static uint32_t E4SHADOWSTART = 0x1fe400;
const static uint32_t E4SHADOWEND = 0x1fffff;

// floating point registers
const static uint32_t FPCOND = 0x1bfcbf; // condition/error byte
// FPCOND bits:
// 7 = division by zero error (set)
// 6 = FP_FROM_ASCII: the text wasn't a number
// 5 = FP_CLASSIFY: infinite. FP_ISAVE_CHECKED: out of the 64 bit range
// 4 = FP_CLASSIFY: not a number
// 3 = FP_COMPARE: unordered (a NaN)
// 2 = FP_COMPARE: FACC > FARG
// 1 = FP_COMPARE: FACC < FARG. FP_CLASSIFY: negative
// 0 = equality (when set). FP_CLASSIFY: zero

const static uint32_t FPASCII = 0x1bfcc0; // 24 byte ASCII buffer
const static uint32_t FPINT = 0x1bfcd8; // 64 bit integer buffer
const static uint32_t FPACCUMULATOR = 0x1bfce0;
const static uint32_t FPARGUMENT = 0x1bfcf0;

// IO address space is from 0000-03ff. 0400-F7FF is reserved.
// Commands/conditions begin at F800.

// Keyboard
const static uint32_t IO_KEYQ_SIZE = 0x00;
const static uint32_t IO_KEYQ_WAITING = 0x01;
const static uint32_t IO_KEYQ_DEQUEUE = 0x02;
const static uint32_t IO_KEYQ_CLEAR = 0x03;

// Console
const static uint32_t IO_CON_CLS = 0x10;
const static uint32_t IO_CON_COLOR = 0x11;
const static uint32_t IO_CON_CHAROUT = 0x12;
const static uint32_t IO_CON_REGISTER = 0x13;
const static uint32_t IO_CON_CURSORH = 0x14;
const static uint32_t IO_CON_CURSORV = 0x15;
const static uint32_t IO_CON_CURSOR = 0x16;
const static uint32_t IO_CON_CR = 0x17;

// Misc environment
const static uint32_t IO_VIDMODE = 0x20;
const static uint32_t IO_RANDBYTE = 0x21;

// Memory window shadowing (applies to every CPU). Writing a byte N to one of these soft switches
// shadows the 8192 byte section N of the 2MB address space (physical N*0x2000) into the
// corresponding window in low memory: reads and writes of the window go to the upper memory.
//   IO_Z80_WINDOW_6 -> 0x6000-0x7fff   (power-on value 0x03)
//   IO_Z80_WINDOW_8 -> 0x8000-0x9fff   (power-on value 0x04)
//   IO_Z80_WINDOW_A -> 0xa000-0xbfff   (power-on value 0x05)
//   IO_Z80_WINDOW_C -> 0xc000-0xdfff   (power-on value 0x06)
// The power-on values map each window onto itself, i.e. the windows start out unmapped.
const static uint32_t IO_Z80_WINDOW_8 = 0x30;
const static uint32_t IO_Z80_WINDOW_A = 0x31;
const static uint32_t IO_Z80_WINDOW_C = 0x32;
const static uint32_t IO_Z80_WINDOW_6 = 0x33;

// command format for floating point operations:
// bit 7: 0=float 1=double
// bit 6: 0=accumulator, 1=argument
// bit 5: 0=float/double 1=intel 80 bit
// bits 0-4: 5 bit of command data

const static uint16_t IO_FP_INIT_CONSTANT = 0x40;
const static uint16_t IO_FP_TO_ASCII = 0x41;
const static uint16_t IO_FP_MULTIPLY = 0x42;
const static uint16_t IO_FP_DIVIDE = 0x43;
const static uint16_t IO_FP_ADD = 0x44;
const static uint16_t IO_FP_SUBTRACT = 0x45;
const static uint16_t IO_FP_LN = 0x46;
const static uint16_t IO_FP_ILOAD = 0x47;
const static uint16_t IO_FP_ISAVE = 0x48;
const static uint16_t IO_FP_EXP = 0x49;
const static uint16_t IO_FP_SIN = 0x4A;
const static uint16_t IO_FP_COS = 0x4B;
const static uint16_t IO_FP_TAN = 0x4C;
const static uint16_t IO_FP_ATN = 0x4D;
const static uint16_t IO_FP_POWER = 0x4E;        // FACC ^ FARG
const static uint16_t IO_FP_COMPARE = 0x4F;      // FACC vs FARG -> FPCOND
const static uint16_t IO_FP_FROM_ASCII = 0x50;   // FPASCII text (up to 31 chars) -> register
const static uint16_t IO_FP_TO_ASCII_G = 0x51;   // register -> FPASCII (up to 32 bytes), %g style, digits in bits 0-4
const static uint16_t IO_FP_FUNC = 0x52;         // more unary functions, selected by bits 0-4
const static uint16_t IO_FP_CLASSIFY = 0x53;     // zero/negative/NaN/infinite -> FPCOND
const static uint16_t IO_FP_ISAVE_CHECKED = 0x54; // ISAVE with an out of range check

const static uint16_t IO_CMD_SERVERALIVE = 0xF800;
const static uint16_t IO_CMD_SERVERDEAD = 0xF801;
const static uint16_t IO_CMD_CLIENTALIVE = 0xF802;
const static uint16_t IO_CMD_CLIENTDEAD = 0xF803;

const static uint16_t IO_CMD_VIDEODIRTY = 0xF900;
const static uint16_t IO_CMD_KEYPRESS = 0xF901;
const static uint16_t IO_CMD_WARMRESET = 0xF902;
// server -> client: a character written to the text console (IO_CON_REGISTER or IO_CON_CR).
// Only sent to a client that connected with IO_CMD_CLIENTALIVE byte = IO_CLIENT_TEXTSTREAM,
// and only in the text modes (8/9).
const static uint16_t IO_CMD_CONCHAR = 0xF903;
const static uint8_t IO_CLIENT_TEXTSTREAM = 1;

// Z80 constants
const static uint16_t Z80_ROM_END = 0x1fff;

// Low memory that is subject to shadowing: 0x6000-0xdfff are the four 8K windows above, and
// 0xe000-0xe3ff always shadows the soft switch bank at 0x1bfc00-0x1bffff.
const static uint32_t SHADOWSTART = 0x006000;
const static uint32_t SHADOWEND = 0x00e3ff;
const static uint32_t IOSHADOWSTART = 0x00e000;

// memory driver
void mem_driver_startup();
void mem_driver_shutdown();
void mem_driver_dispose_shared();
int mem_driver_shmid();
unsigned char *mem_driver_buffer();
uint8_t mem_driver_read(uint32_t a_address);
void mem_driver_write(uint32_t a_address, uint8_t a_byte);
uint32_t mem_driver_effadr(uint32_t a_address); // translate an address through the shadow windows

// io driver
void io_driver_startup();
int io_driver_qid_forward();
int io_driver_qid_backchannel();
void io_driver_shutdown();
void io_driver_post_forward(uint16_t a_address, uint8_t a_byte);
void io_driver_post_backchannel(uint16_t a_address, uint8_t a_byte);
int io_driver_wait_forward(io_message_t *a_msg);
int io_driver_wait_backchannel(io_message_t *a_msg);

// keyboard queue and console support, used by the server
void kbd_enqueue(uint8_t a_char);
uint8_t kbd_dequeue();
void kbd_clear();
void con_cls();
void con_register();
void con_cr();

// z80/8080/8085 support (16 bit address w/ 256 byte special I/O)
void z80_driver_startup();
void z80_driver_shutdown();
uint8_t z80_mem_read(uint16_t a_address);
void z80_mem_write(uint16_t a_address, uint8_t a_byte);
uint8_t z80_io_read(uint8_t a_address);
void z80_io_write(uint8_t a_address, uint8_t a_byte);

// m68k support (flat 24 bit big endian address space, mirrored every 2MB).
// The ROM image is loaded at 0x1c0000 (the write protected 1C ROM area) and begins with its
// exception vector table. The 68000 fetches its reset vectors from address 0, so the first
// M68K_VECTORS_SIZE bytes of the ROM are copied to 0x000000 at power on and warm reset.
// Everything below the video buffer is RAM, including the vector table.
const static uint32_t M68K_ROM_BASE = 0x1c0000;
const static uint32_t M68K_ROM_SIZE = 0x40000;
const static uint32_t M68K_VECTORS_SIZE = 0x400;

void m68k_driver_startup();
uint8_t m68k_mem_read8(uint32_t a_address);
uint16_t m68k_mem_read16(uint32_t a_address);
uint32_t m68k_mem_read32(uint32_t a_address);
void m68k_mem_write8(uint32_t a_address, uint8_t a_byte);
void m68k_mem_write16(uint32_t a_address, uint16_t a_word);
void m68k_mem_write32(uint32_t a_address, uint32_t a_long);

// floating point support
void fp_init_constant(uint8_t a_byte);
void fp_to_ascii(uint8_t a_byte);
void fp_multiply(uint8_t a_byte);
void fp_divide(uint8_t a_byte);
void fp_add(uint8_t a_byte);
void fp_subtract(uint8_t a_byte);
void fp_ln(uint8_t a_byte);
void fp_exp(uint8_t a_byte);
void fp_iload(uint8_t a_byte);
void fp_isave(uint8_t a_byte);
void fp_sin(uint8_t a_byte);
void fp_cos(uint8_t a_byte);
void fp_tan(uint8_t a_byte);
void fp_atn(uint8_t a_byte);
void fp_power(uint8_t a_byte);
void fp_compare(uint8_t a_byte);
void fp_from_ascii(uint8_t a_byte);
void fp_to_ascii_g(uint8_t a_byte);
void fp_func(uint8_t a_byte);
void fp_classify(uint8_t a_byte);
void fp_isave_checked(uint8_t a_byte);

#endif // IO_DRIVER_H
