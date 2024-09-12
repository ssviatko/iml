#ifndef IO_DRIVER_H
#define IO_DRIVER_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/msg.h>
#include <sys/ipc.h> // for ftok
#include <errno.h>
#include <sys/shm.h>

#define SHM_SIZE 2097152
#define SHM_MODE 0600
#define MSQ_MODE 0600

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

// IO address space is from 0000-03ff. 0400-F7FF is reserved.
// Commands/conditions begin at F800.

const static uint16_t IO_VIDMODE = 0x0020;

const static uint16_t IO_CMD_SERVERALIVE = 0xF800;
const static uint16_t IO_CMD_SERVERDEAD = 0xF801;
const static uint16_t IO_CMD_CLIENTALIVE = 0xF802;
const static uint16_t IO_CMD_CLIENTDEAD = 0xF803;

const static uint16_t IO_CMD_VIDEODIRTY = 0xF900;

// memory driver
void mem_driver_startup();
void mem_driver_shutdown();
void mem_driver_dispose_shared();
int mem_driver_shmid();
char *mem_driver_buffer();
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

#endif // IO_DRIVER_H
