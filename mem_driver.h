#ifndef MEM_DRIVER_H
#define MEM_DRIVER_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/shm.h>
#include <sys/ipc.h> // for ftok

#define SHM_SIZE 2097152
#define SHM_MODE 0600

// video space
const static uint32_t VIDSTART = 0x180000;
const static uint32_t VIDEND = 0x1bfbff;

// reserved memory spaces
const static uint32_t ZEROPAGESTART = 0x000000;
const static uint32_t ZEROPAGEEND = 0x0000ff;
const static uint32_t E400ROMSTART = 0x00e400;
const static uint32_t E400ROMEND = 0x00ffff;
const static uint32_t X1CROMSTART = 0x1c0000;
const static uint32_t X1CROMEND = 0x1fffff;
const static uint32_t E4SHADOWSTART = 0x1fe400;
const static uint32_t E4SHADOWEND = 0x1fffff;

void mem_driver_startup();
void mem_driver_shutdown();
void mem_driver_dispose_shared();
int mem_driver_shmid();
char *mem_driver_buffer();
void mem_driver_write(uint32_t a_address, uint8_t a_byte);

#endif // MEM_DRIVER_H

