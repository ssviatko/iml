#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <stdint.h>

#include "memio_driver.h"

int g_countdown = 6;
uint16_t curcolor;

void ctrlc(int)
{
	printf("nearcolor: shutting down memory and io driver...\n");
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

void nearcolor()
{
	size_t i;
	unsigned char *mem = mem_driver_buffer();

	g_countdown--;
	if (g_countdown == 0) {
		g_countdown = 6;
		switch (mem[IOSTART + IO_VIDMODE]) {
			case 4:
				mem_driver_write(IOSTART + IO_VIDMODE, 5);
				break;
			case 5:
				mem_driver_write(IOSTART + IO_VIDMODE, 6);
				break;
			case 6:
				mem_driver_write(IOSTART + IO_VIDMODE, 4);
				break;
		}
	}

	for (i = VIDSTART; i <= VIDEND; i += 2) {
		int red = (curcolor & 0xf00) >> 8;
		int green = (curcolor & 0xf0) >> 4;
		int blue = curcolor & 0xf;
		red += (rand() & 1) * ((rand() & 1) ? -1 : 1);
		green += (rand() & 1) * ((rand() & 1) ? -1 : 1);
		blue += (rand() & 1) * ((rand() & 1) ? -1 : 1);
		red = (red < 0) ? 0 : red;
		red = (red > 0xf) ? 0xf : red;
		green = (green < 0) ? 0 : green;
		green = (green > 0xf) ? 0xf : green;
		blue = (blue < 0) ? 0 : blue;
		blue = (blue > 0xf) ? 0xf : blue;
		curcolor = (red << 8) + (green << 4) + blue;
		mem_driver_write(i, curcolor & 0xff);
		mem_driver_write(i + 1, (curcolor & 0xf00) >> 8);
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
		fprintf(stderr, "nearcolor: fatal error: can't catch SIGINT");
		exit(-1);
	}

	printf("nearcolor: starting up memory and io driver..\n");
	mem_driver_startup();
	printf("nearcolor: started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	io_driver_startup();
	printf("nearcolor: started up io driver, qid_forward = %d qid_backchannel = %d\n", io_driver_qid_forward(), io_driver_qid_backchannel());
	io_message_t msg;
	// wait for client to connect
	io_driver_post_forward(IO_CMD_SERVERALIVE, 0);
	printf("nearcolor: waiting for client to connect...\n");
	while (io_driver_wait_backchannel(&msg) == -1) {
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000;
		nanosleep(&ts, NULL);
	}
	if (msg.address == IO_CMD_CLIENTALIVE) {
		printf("nearcolor: client alive. running server.\n");
	} else {
		fprintf(stderr, "nearcolor: unexptected message from client: %04X/%02X\n", msg.address, msg.byte);
		exit(-1);
	}

	mem_driver_write(IOSTART + IO_VIDMODE, 4);
	curcolor = rand() & 0xfff;

	while (1) {
		if (io_driver_wait_backchannel(&msg) == 0) {
			if (msg.address == IO_CMD_CLIENTDEAD) {
				// client died, so break out of our loop
				break;
			}
		}
		nearcolor();
		sleep(30);
	}
	ctrlc(0); // just use the ctrlc handler to shut everything down
	return 0;
}

