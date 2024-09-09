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

void mem_driver_startup();
void mem_driver_shutdown();
void mem_driver_dispose_shared();
int mem_driver_shmid();
char *mem_driver_buffer();

#endif // MEM_DRIVER_H

