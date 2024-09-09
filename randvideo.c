#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

#include "mem_driver.h"
#include "io_driver.h"

void ctrlc()
{
	printf("shutting down memory and io driver...\n");
	mem_driver_shutdown();
	mem_driver_dispose_shared();
	// send SERVERDEAD
	io_message_t msg;
	msg.address = IO_CMD_SERVERDEAD;
	msg.byte = 0;
	io_driver_post_forward(&msg);
	sleep(1); // wait for client to receiver SERVERDEAD
	io_driver_shutdown();
	exit(0);
}

void randvideo()
{
	size_t i;
	
	printf("randomizing video...\n");
	for (i = VIDSTART; i <= VIDEND; ++i) {
		mem_driver_write(i, rand() & 0xff);
	}
}

int main(int argc, char **argv)
{
	srand(time(NULL));

	// handle SIGINT
	struct sigaction sa;
	sa.sa_handler = ctrlc;
	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SIGINT);
	sa.sa_flags = 0;
	if (sigaction(SIGINT, &sa, NULL) < 0) {
		fprintf(stderr, "fatal error: can't catch SIGINT");
		exit(-1);
	}

	printf("starting up memory and io driver..\n");
	mem_driver_startup();
	io_driver_startup();
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	io_message_t msg;
	// wait for client to connect
	msg.address = IO_CMD_SERVERALIVE;
	msg.byte = 0;
	io_driver_post_forward(&msg);
	while (io_driver_wait_backchannel(&msg) == -1) {
		printf("waiting for client to connect...\n");
		sleep(1);
	}
	if (msg.address == IO_CMD_CLIENTALIVE) {
		printf("client alive. running server.\n");
	} else {
		fprintf(stderr, "unexptected message from client: %04X/%02X\n", msg.address, msg.byte);
		exit(-1);
	}
	
	while (1) {
		if (io_driver_wait_backchannel(&msg) == 0) {
			if (msg.address == IO_CMD_CLIENTDEAD) {
				// client died, so break out of our loop
				break;
			}
		}
		randvideo();
		msg.address = IO_CMD_VIDEODIRTY;
		msg.byte = 0x80;
		io_driver_post_forward(&msg);
		sleep(1);
	}
	ctrlc(); // just use the ctrlc handler to shut everything down
	return 0;
}

