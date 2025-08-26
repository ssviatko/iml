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
// 6 =
// 5 =
// 4 =
// 3 =
// 2 =
// 1 =
// 0 = equality (when set)

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

// Z80 mode memory shadowing
const static uint32_t IO_Z80_WINDOW_8 = 0x30;
const static uint32_t IO_Z80_WINDOW_A = 0x31;
const static uint32_t IO_Z80_WINDOW_C = 0x32;
const static uint32_t IO_Z80_WINDOW_E = 0x33;

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

const static uint16_t IO_CMD_SERVERALIVE = 0xF800;
const static uint16_t IO_CMD_SERVERDEAD = 0xF801;
const static uint16_t IO_CMD_CLIENTALIVE = 0xF802;
const static uint16_t IO_CMD_CLIENTDEAD = 0xF803;

const static uint16_t IO_CMD_VIDEODIRTY = 0xF900;
const static uint16_t IO_CMD_KEYPRESS = 0xF901;
const static uint16_t IO_CMD_WARMRESET = 0xF902;

// Z80 constants
const static uint16_t Z80_ROM_END = 0x1fff;

// memory driver
void mem_driver_startup();
void mem_driver_shutdown();
void mem_driver_dispose_shared();
int mem_driver_shmid();
unsigned char *mem_driver_buffer();
uint8_t mem_driver_read(uint32_t a_address);
void mem_driver_write(uint32_t a_address, uint8_t a_byte);

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
uint32_t z80_effadr(uint32_t a_address);
void z80_driver_startup();
void z80_driver_shutdown();
uint8_t z80_mem_read(uint16_t a_address);
void z80_mem_write(uint16_t a_address, uint8_t a_byte);
uint8_t z80_io_read(uint8_t a_address);
void z80_io_write(uint8_t a_address, uint8_t a_byte);

// floating point support
void fp_init_constant(uint8_t a_byte);
void fp_to_ascii(uint8_t a_byte);
void fp_multiply(uint8_t a_byte);
void fp_divide(uint8_t a_byte);
void fp_add(uint8_t a_byte);
void fp_subtract(uint8_t a_byte);
void fp_ln(uint8_t a_byte);
void fp_iload(uint8_t a_byte);
void fp_isave(uint8_t a_byte);

#endif // IO_DRIVER_H
