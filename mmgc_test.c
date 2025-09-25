#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "mmgc.h"

int main(int argc, char **argv)
{
	char buff[255];
	uint8_t l_mychar;
	uint8_t l_funcolor = 0x01;
	
	mmgc_startup(3, "MMGC Test");
//	mmgc_vidmode(9);
	sprintf(buff, "This is a test of the\rMemory-mapped Graphics Context.\r");
	mmgc_puts(buff);
	while (mmgc_close_requested() == ERROR_NONE) {
		l_mychar = mmgc_getc();
		if (l_mychar == 0xff)
			break; // user wants to close
		mmgc_con_color(l_funcolor++);
		mmgc_putc(l_mychar);
		if (l_funcolor > 15)
			l_funcolor = 1;
	}
	mmgc_shutdown();
	return 0;
}
