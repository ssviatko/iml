#ifndef Z80_H
#define Z80_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "memio_driver.h"

int engine_z80_init();
void engine_z80_step();
long engine_z80_cycle_count();
int engine_z80_halted(); 

#endif // Z80_H
