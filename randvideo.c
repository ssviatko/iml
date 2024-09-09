#include <stdio.h>

#include "mem_driver.h"

int main(int argc, char **argv)
{
	printf("starting up memory driver..\n");
	mem_driver_startup();
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();
	return 0;
}

