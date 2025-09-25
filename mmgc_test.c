#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "mmgc.h"

int main(int argc, char **argv)
{
	char buff[255];
	
	mmgc_startup(2, "MMGC Test");
	sprintf(buff, "This is a test of the\rMemory-mapped Graphics Context.\r");
	mmgc_puts(buff);
	while (mmgc_close_requested() == ERROR_NONE) {
		sleep(1);
	}
	mmgc_shutdown();
	return 0;
}
