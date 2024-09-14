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
	
	mem_driver_write(IOSTART + IO_VIDMODE, 9);
	mem_driver_write(IOSTART + IO_CON_CHAROUT, 0x20);
	mem_driver_write(IOSTART + IO_CON_COLOR, 0x0d);
	mem_driver_write(IOSTART + IO_CON_CLS, 0);
	mem_driver_write(IOSTART + IO_CON_CURSOR, 0x80);
	mem_driver_write(IOSTART + IO_CON_CURSORH, 0);
	mem_driver_write(IOSTART + IO_CON_CURSORV, 0);
	while (1) {
		if (io_driver_wait_backchannel(&msg) == 0) {
			if (msg.address == IO_CMD_CLIENTDEAD) {
				// client died, so break out of our loop
//				printf("client died!\n");
				break;
			}
			if (msg.address == IO_CMD_KEYPRESS) {
//				printf("keypress: %d\n", msg.byte);
				// ctrl A - set 40 cols
				if (msg.byte == 0x01) {
					mem_driver_write(IOSTART + IO_VIDMODE, 0x08);
					continue;
				}
				// ctrl B - set 80 cols
				if (msg.byte == 0x02) {
					mem_driver_write(IOSTART + IO_VIDMODE, 0x09);
					continue;
				}
				// ctrl C - select next color
				if (msg.byte == 0x03) {
					uint8_t l_color = mem[IOSTART + IO_CON_COLOR];
					l_color++;
					l_color &= 0x0f;
					mem_driver_write(IOSTART + IO_CON_COLOR, l_color);
					continue;
				}
				kbd_enqueue(msg.byte);
			}
			if (mem[IOSTART + IO_KEYQ_SIZE] > 0) {
				uint8_t l_char = mem[IOSTART + IO_KEYQ_WAITING];
//				printf("showing key %d\n", l_char);
				mem_driver_write(IOSTART + IO_CON_CHAROUT, l_char);
				mem_driver_write(IOSTART + IO_CON_REGISTER, 0);
				mem_driver_write(IOSTART + IO_KEYQ_DEQUEUE, 0);
				continue;
			}
		}
		// nighty night
		ts.tv_sec = 0;
		ts.tv_nsec = 10000000;
		nanosleep(&ts, NULL);			
	}
	ctrlc(); // just use the ctrlc handler to shut everything down
	return 0;
}
