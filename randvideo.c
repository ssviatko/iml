#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

#include "mem_driver.h"

void ctrlc()
{
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();
	mem_driver_dispose_shared();
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

	printf("starting up memory driver..\n");
	mem_driver_startup();
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	while (1) {
		randvideo();
		sleep(1);
	}
	return 0;
}

