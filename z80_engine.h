#ifndef Z80_H
#define Z80_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "memio_driver.h"

int engine_z80_init();
void engine_z80_reset();
void engine_z80_step();
long engine_z80_cycle_count();
int engine_z80_halted();
int engine_z80_irq(uint8_t data); // maskable interrupt; returns 1 if accepted
void engine_z80_nmi(); // non-maskable interrupt

#endif // Z80_H
