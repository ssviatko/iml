#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <signal.h>

#include "memio_driver.h"
#include "65816_engine.h"

void ctrlc(int)
{
	printf("65816: shutting down memory and io driver...\n");
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
		fprintf(stderr, "65816: fatal error: can't catch SIGINT");
		exit(-1);
	}

	printf("65816: starting up memory and io driver..\n");
	mem_driver_startup();
	printf("65816: started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	io_driver_startup();
	printf("65816: started up io driver, qid_forward = %d qid_backchannel = %d\n", io_driver_qid_forward(), io_driver_qid_backchannel());
	unsigned char *mem = mem_driver_buffer();
	// wait for client to connect
	io_driver_post_forward(IO_CMD_SERVERALIVE, 0);
	printf("65816: waiting for client to connect...\n");
	io_message_t msg;
	while (io_driver_wait_backchannel(&msg) == -1) {
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000;
		nanosleep(&ts, NULL);
	}
	if (msg.address == IO_CMD_CLIENTALIVE) {
		printf("65816: client alive. running server.\n");
	} else {
		fprintf(stderr, "65816: unexpected message from client: %04X/%02X\n", msg.address, msg.byte);
		exit(-1);
	}
	
	// load ROMs
	FILE *e4rom, *x1crom;
	if ((e4rom = fopen("e4.o", "r")) == NULL)
	{
		fprintf(stderr, "65816: Cannot open ROM file.\nA file named \"e4.o\" must exist in this directory.\n");
		exit(-1);
	}
	if (fread(mem + E400ROMSTART, 1, 0x1c00, e4rom) != 0x1c00)
	{
		fprintf(stderr, "65816: Cannot read ROM file. It may be corrupted.\n");
		exit(-1);
	}
	fclose(e4rom);
	if ((x1crom = fopen("1c.o", "r")) == NULL)
	{
		fprintf(stderr, "65816: Cannot open ROM file.\nA file named \"1c.o\" must exist in this directory.\n");
		exit(-1);
	}
	if (fread(mem + X1CROMSTART, 1, 0xffff, x1crom) != 0xffff)
	{
		fprintf(stderr, "65816: Cannot read ROM file. It may be corrupted.\n");
		exit(-1);
	}
	fclose(x1crom);
	
	struct timeval start_time;
	struct timeval end_time;
	gettimeofday(&start_time, NULL);
	engine_65816_init(mem, 0);
	
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
			if (msg.address == IO_CMD_WARMRESET) {
				printf("65816: warm reset request received, resetting 65816...\n");
				engine_65816_reset();
			}
		}
			// start executing at PC
		if (!engine_65816_halted()) {
			engine_65816_step();
		} else {
			// nighty night
			ts.tv_sec = 0;
			ts.tv_nsec = 10000000;
			nanosleep(&ts, NULL);			
		}
	}
	gettimeofday(&end_time, NULL);
	printf("65816: Executed %ld cycles.\n", engine_65816_cycle_count());
	long elapsed_secs = end_time.tv_sec - start_time.tv_sec - ((end_time.tv_usec - start_time.tv_usec < 0) ? 1 : 0); // subtract 1 if there was a usec rollover
	long elapsed_usecs = end_time.tv_usec - start_time.tv_usec + ((end_time.tv_usec - start_time.tv_usec < 0) ? 1000000 : 0); // bump usecs by 1 million usec for rollover
	printf("65816: Elapsed time: %ld seconds %ld usecs.\n", elapsed_secs, elapsed_usecs);
	printf("65816: estimated emulation speed: %fMhz\n", ((double)engine_65816_cycle_count() / ((double)elapsed_secs + (double)(elapsed_usecs / 1000000.0))) / 1000000.0);
	
	ctrlc(0); // just use the ctrlc handler to shut everything down
	return 0;
}
