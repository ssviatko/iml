#ifndef M68K_H
#define M68K_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "memio_driver.h"

int engine_m68k_init();
void engine_m68k_reset();
void engine_m68k_step();
long engine_m68k_cycle_count();
int engine_m68k_halted(); // stopped (STOP instruction) or halted (double bus fault)
void engine_m68k_irq(int level); // request an autovectored interrupt at level 1-7 (0 = none)

#endif // M68K_H
