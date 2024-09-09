#include <stdio.h>

#include "mem_driver.h"

int main(int argc, char **argv)
{
	printf("starting up memory driver..\n");
	mem_driver_startup();
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();
	mem_driver_dispose_shared();
	return 0;
}

