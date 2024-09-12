#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

#include "memio_driver.h"

void ctrlc()
{
	printf("shutting down memory and io driver...\n");
	mem_driver_shutdown();
	mem_driver_dispose_shared();
	// send SERVERDEAD
	io_driver_post_forward(IO_CMD_SERVERDEAD, 0);
	struct timespec ts;
	ts.tv_sec = 0;
	ts.tv_nsec = 500000000; // 500ms
	nanosleep(&ts, NULL); // wait for client to receiver SERVERDEAD
	io_driver_shutdown();
	exit(0);
}

int main(int argc, char **argv)
{
	struct timespec ts;

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
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	io_driver_startup();
	printf("started up io driver, qid_forward = %d qid_backchannel = %d\n", io_driver_qid_forward(), io_driver_qid_backchannel());
	unsigned char *mem = mem_driver_buffer();
	// wait for client to connect
	io_driver_post_forward(IO_CMD_SERVERALIVE, 0);
	printf("waiting for client to connect...\n");
	io_message_t msg;
	while (io_driver_wait_backchannel(&msg) == -1) {
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000;
		nanosleep(&ts, NULL);
	}
	if (msg.address == IO_CMD_CLIENTALIVE) {
		printf("client alive. running server.\n");
	} else {
		fprintf(stderr, "unexptected message from client: %04X/%02X\n", msg.address, msg.byte);
		exit(-1);
	}
	
	mem_driver_write(IOSTART + IO_VIDMODE, 8);
	mem_driver_write(IOSTART + IO_CON_CHAROUT, 0x41);
	mem_driver_write(IOSTART + IO_CON_COLOR, 0x0f);
	mem_driver_write(IOSTART + IO_CON_CLS, 0);
	mem_driver_write(IOSTART + IO_CON_CURSOR, 0x80);
	mem_driver_write(IOSTART + IO_CON_CURSORH, 0);
	mem_driver_write(IOSTART + IO_CON_CURSORV, 0);
	while (1) {
		char key;
		unsigned char waiting;
		while ((waiting = mem[IOSTART + IO_KEYQ_SIZE]) == 0) {
			ts.tv_sec = 0;
			ts.tv_nsec = 10000000;
			nanosleep(&ts, NULL);
			if (io_driver_wait_backchannel(&msg) == 0) {
				if (msg.address == IO_CMD_CLIENTDEAD) {
					// client died, so break out of our loop
					printf("client died!\n");
					ctrlc();
					exit(0);
				}
			}
		}
		key = mem[IOSTART + IO_KEYQ_WAITING];
		mem_driver_write(IOSTART + IO_KEYQ_DEQUEUE, 0);
		// wait for waiting IO to change
		while (mem[IOSTART + IO_KEYQ_SIZE] == waiting) {
			ts.tv_sec = 0;
			ts.tv_nsec = 10000000;
			nanosleep(&ts, NULL);			
		}
		printf("showing key %d\n", key);
		mem_driver_write(VIDSTART, key);
		mem_driver_write(VIDSTART + 1, 0x0f);
	}
	ctrlc(); // just use the ctrlc handler to shut everything down
	return 0;
}
