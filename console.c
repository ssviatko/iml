#include <stdio.h>
#include <signal.h>
#include <time.h>

#include "mem_driver.h"
#include "io_driver.h"

void ctrlc()
{
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();
	// send CLIENTDEAD
	io_message_t msg;
	msg.address = IO_CMD_CLIENTDEAD;
	msg.byte = 0;
	io_driver_post_backchannel(&msg);
	exit(0);
}

int main(int argc, char **argv)
{
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
	
	struct timespec ts;
	io_message_t msg;
	// wait indefinitely for SERVERALIVE. Nothing to do if the server isn't there
	printf("waiting for server to appear...\n");
	while (io_driver_wait_forward(&msg) == -1) {
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000; // 20ms
		nanosleep(&ts, NULL);
	}
	if (msg.address != IO_CMD_SERVERALIVE) {
		fprintf(stderr, "expected IO_CMD_SERVERALIVE from server!\n");
		exit(-1);
	}
	// send CLIENTALIVE
	msg.address = IO_CMD_CLIENTALIVE;
	msg.byte = 0;
	io_driver_post_backchannel(&msg);
	
	// retrieve commands from server
	while (1) {
		printf("waiting for command from server...\n");
		while (io_driver_wait_forward(&msg) == -1) {
			ts.tv_sec = 0;
			ts.tv_nsec = 20000000; // 20ms
			nanosleep(&ts, NULL);
		}
		printf("received %04X/%02X from server.\n", msg.address, msg.byte);
		if (msg.address == IO_CMD_SERVERDEAD) {
			printf("server died!\n");
			break;
		}
		unsigned char *mem = (unsigned char *)mem_driver_buffer();
		printf("video: %02X %02X %02X %02X %02X %02X\n", mem[VIDSTART + 0], mem[VIDSTART + 1], mem[VIDSTART + 2],
			mem[VIDSTART + 3], mem[VIDSTART + 4], mem[VIDSTART + 5]);
	}
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();

	return 0;
}