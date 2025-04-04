#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <signal.h>

#include "memio_driver.h"
#include "z80_engine.h"

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
		fprintf(stderr, "unexpected message from client: %04X/%02X\n", msg.address, msg.byte);
		exit(-1);
	}
	
	// load ROMs
	FILE *zrom;
	if ((zrom = fopen("zrom.bin", "r")) == NULL)
	{
		fprintf(stderr, "Cannot open ROM file.\nA file named \"zrom.bin\" must exist in this directory.\n");
		exit(-1);
	}
	printf("read %x bytes.\n", fread(mem + 0, 1, 0x2000, zrom));
	fclose(zrom);
	
	struct timeval start_time;
	struct timeval end_time;
	gettimeofday(&start_time, NULL);
	engine_z80_init();
	
	while (1) {
		if (io_driver_wait_backchannel(&msg) == 0) {
			if (msg.address == IO_CMD_CLIENTDEAD) {
				// client died, so break out of our loop
//				printf("client died!\n");
				break;
			}
			if (msg.address == IO_CMD_KEYPRESS) {
				kbd_enqueue(msg.byte);
			}
		}
			// start executing at PC
		if (!engine_z80_halted()) {
			engine_z80_step();
		} else {
			// nighty night
			ts.tv_sec = 0;
			ts.tv_nsec = 10000000;
			nanosleep(&ts, NULL);			
		}
	}
	gettimeofday(&end_time, NULL);
	printf("Executed %ld cycles.\n", engine_z80_cycle_count());
	long elapsed_secs = end_time.tv_sec - start_time.tv_sec - ((end_time.tv_usec - start_time.tv_usec < 0) ? 1 : 0); // subtract 1 if there was a usec rollover
	long elapsed_usecs = end_time.tv_usec - start_time.tv_usec + ((end_time.tv_usec - start_time.tv_usec < 0) ? 1000000 : 0); // bump usecs by 1 million usec for rollover
	printf("Elapsed time: %ld seconds %ld usecs.\n", elapsed_secs, elapsed_usecs);
	printf("estimated emulation speed: %fMhz\n", ((double)engine_z80_cycle_count() / ((double)elapsed_secs + (double)(elapsed_usecs / 1000000.0))) / 1000000.0);
	
	ctrlc(); // just use the ctrlc handler to shut everything down
	return 0;
}
