#include "z80_engine.h"

int engine_z80_init()
{
	z80_driver_startup();
	z80_mem_read(0x100);
	z80_mem_read(0x78bc);
	z80_io_write(IO_Z80_WINDOW_8, 0x13);
	z80_mem_read(0x9dbf);
	z80_mem_read(0xe111);
	z80_io_write(IO_VIDMODE, 8);
	z80_io_write(IO_CON_CURSORH, 0);
	z80_io_write(IO_CON_CURSORV, 0);
	z80_io_write(IO_CON_COLOR, 0x07);
	z80_io_write(IO_CON_CHAROUT, 0x20);
	z80_io_write(IO_CON_CLS, 0);
	z80_io_write(IO_CON_CHAROUT, 0x41);
	z80_io_write(IO_CON_REGISTER, 0);
	z80_io_write(IO_CON_CR, 0);
	z80_mem_write(0xe080, 0x07);
	z80_mem_write(0xe081, 0x07);
	return 0;
}

void engine_z80_step()
{
	
}

long engine_z80_cycle_count()
{
	return 0;
}

int engine_z80_halted()
{
	return 1;
}