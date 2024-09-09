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

#define MSQ_MODE 0600

typedef struct {
	uint16_t address;
	uint8_t byte;
} io_message_t;

// IO address space is from 0000-00ff. 0100-F7FF is reserved.
// Commands/conditions begin at F800.

const static uint16_t IO_CMD_SERVERALIVE = 0xF800;
const static uint16_t IO_CMD_SERVERDEAD = 0xF801;
const static uint16_t IO_CMD_CLIENTALIVE = 0xF802;
const static uint16_t IO_CMD_CLIENTDEAD = 0xF803;

const static uint16_t IO_CMD_VIDEODIRTY = 0xF900;

void io_driver_startup();
void io_driver_shutdown();
void io_driver_post_forward(io_message_t *a_msg);
void io_driver_post_backchannel(io_message_t *a_msg);
int io_driver_wait_forward(io_message_t *a_msg);
int io_driver_wait_backchannel(io_message_t *a_msg);

#endif // IO_DRIVER_H
