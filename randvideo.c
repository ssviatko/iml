#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

#include "memio_driver.h"

int g_countdown = 6;

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

void randvideo()
{
	size_t i;
	unsigned char *mem = mem_driver_buffer();

	g_countdown--;
	if (g_countdown == 0) {
		g_countdown = 6;
		switch (mem[IOSTART + IO_VIDMODE]) {
			case 0:
				mem_driver_write(IOSTART + IO_VIDMODE, 1);
				break;
			case 1:
				mem_driver_write(IOSTART + IO_VIDMODE, 2);
				break;
			case 2:
				mem_driver_write(IOSTART + IO_VIDMODE, 4);
				break;
			case 4:
				mem_driver_write(IOSTART + IO_VIDMODE, 5);
				break;
			case 5:
				mem_driver_write(IOSTART + IO_VIDMODE, 6);
				break;
			case 6:
				mem_driver_write(IOSTART + IO_VIDMODE, 8);
				break;
			case 8:
				mem_driver_write(IOSTART + IO_VIDMODE, 9);
				break;
			case 9:
				mem_driver_write(IOSTART + IO_VIDMODE, 0);
				break;
		}
	}
	
	printf("randomizing video... mode %d\n", mem[IOSTART + IO_VIDMODE]);
	for (i = VIDSTART; i <= VIDEND; ++i) {
		mem_driver_write(i, rand() & 0xff);
	}
	if (mem[IOSTART + IO_VIDMODE] >= 8) {
		int j = 0;
		for (i = VIDSTART; i < VIDSTART + 32; i+=2) {
			mem_driver_write(i, '*');
			mem_driver_write(i + 1, j++);
		}
	}
}

int main(int argc, char **argv)
{
	struct timespec ts;
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
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	io_driver_startup();
	printf("started up io driver, qid_forward = %d qid_backchannel = %d\n", io_driver_qid_forward(), io_driver_qid_backchannel());
	io_message_t msg;
	// wait for client to connect
	io_driver_post_forward(IO_CMD_SERVERALIVE, 0);
	printf("waiting for client to connect...\n");
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
	
	while (1) {
		if (io_driver_wait_backchannel(&msg) == 0) {
			if (msg.address == IO_CMD_CLIENTDEAD) {
				// client died, so break out of our loop
				break;
			}
		}
		randvideo();
		sleep(1);
	}
	ctrlc(); // just use the ctrlc handler to shut everything down
	return 0;
}

