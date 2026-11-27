#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <signal.h>

#include "memio_driver.h"
#include "m68k_engine.h"

void ctrlc(int)
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
	FILE *mrom;
	if ((mrom = fopen("mrom.bin", "r")) == NULL)
	{
		fprintf(stderr, "Cannot open ROM file.\nA file named \"mrom.bin\" must exist in this directory.\n");
		exit(-1);
	}
	size_t l_romsize = fread(mem + M68K_ROM_BASE, 1, M68K_ROM_SIZE, mrom);
	printf("read $%lx bytes.\n", l_romsize);
	fclose(mrom);

	// BASIC goes at the next $100 boundary above the monitor (where the monitor's B and W
	// commands expect it). basic.bin says where it was assembled for, at offset 16
	uint32_t l_basic = M68K_ROM_BASE + ((l_romsize + 0xff) & ~0xff);
	FILE *brom;
	if ((brom = fopen("basic.bin", "r")) == NULL) {
		fprintf(stderr, "m68k: no basic.bin, so no BASIC.\n");
	} else {
		size_t l_room = M68K_ROM_BASE + M68K_ROM_SIZE - l_basic;
		uint8_t *l_b = mem + l_basic;
		size_t l_bsize = fread(l_b, 1, l_room, brom);
		fclose(brom);
		uint32_t l_org = (l_b[16] << 24) | (l_b[17] << 16) | (l_b[18] << 8) | l_b[19];
		if ((l_bsize < 20) || memcmp(l_b + 8, "IMLBASIC", 8) || (l_org != l_basic)) {
			fprintf(stderr, "m68k: basic.bin isn't a BASIC assembled for $%06X (rebuild it with make), not loaded.\n", l_basic);
			memset(l_b, 0, l_bsize);
		} else {
			printf("read $%lx bytes of BASIC at $%06X.\n", l_bsize, l_basic);
		}
	}
	// the 68000 takes its reset vectors from address 0: copy the ROM's vector table there
	memcpy(mem, mem + M68K_ROM_BASE, M68K_VECTORS_SIZE);
	
	struct timeval start_time;
	struct timeval end_time;
	gettimeofday(&start_time, NULL);
	engine_m68k_init();
	
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
				printf("m68k: warm reset request received, resetting 68000...\n");
				memcpy(mem, mem + M68K_ROM_BASE, M68K_VECTORS_SIZE);
				engine_m68k_reset();
			}
		}
			// start executing at PC
		if (!engine_m68k_halted()) {
			// run a batch of instructions between checks of the message queue
			for (int i = 0; i < 1000 && !engine_m68k_halted(); ++i)
				engine_m68k_step();
		} else {
			// nighty night
			ts.tv_sec = 0;
			ts.tv_nsec = 10000000;
			nanosleep(&ts, NULL);			
		}
	}
	gettimeofday(&end_time, NULL);
	printf("Executed %ld cycles.\n", engine_m68k_cycle_count());
	long elapsed_secs = end_time.tv_sec - start_time.tv_sec - ((end_time.tv_usec - start_time.tv_usec < 0) ? 1 : 0); // subtract 1 if there was a usec rollover
	long elapsed_usecs = end_time.tv_usec - start_time.tv_usec + ((end_time.tv_usec - start_time.tv_usec < 0) ? 1000000 : 0); // bump usecs by 1 million usec for rollover
	printf("Elapsed time: %ld seconds %ld usecs.\n", elapsed_secs, elapsed_usecs);
	printf("estimated emulation speed: %fMhz\n", ((double)engine_m68k_cycle_count() / ((double)elapsed_secs + (double)(elapsed_usecs / 1000000.0))) / 1000000.0);
	
	ctrlc(0); // just use the ctrlc handler to shut everything down
	return 0;
}
