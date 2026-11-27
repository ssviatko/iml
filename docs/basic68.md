Proposal for 68000 BASIC interpreter

A BASIC interpreter will be written and assembled to sit in memory at the next even $1000 address above the existing 68000 monitor. When in doubt about how to implement something, standard Microsoft BASIC conventions will be used that were common to machines made in the 1980's.

The interpreter will be assembled in its own file (basic.s) and assembled to a separate object file. This BASIC object file will be loaded into memory above the monitor by the m68k.c program.

Interpreter will have two entry points, a warm start and a cold start entry point. The warm start will preserve the program and variables and the cold start will initialize the entire system. A command(s) will be added to the monitor to call the cold and/or warm start of the BASIC interpreter. The BASIC interpreter will have a BASIC keyword that exists the the monitor, preserving the program in memory.

All memory between $10000 and $16ffff will be available to a basic program and its variables. The variable table will start at the top of memory and work down, while the program will start at the bottom and work up. A LOMEM and HIMEM command will be enabled which will take 24 bit address arguments.

Variable types: examples using the letter "A" for the variable name:

Strings (A$), capable of holding up to 64k of string data in UIF-8 single byte characters
Floating point: (A), using Intel 10-byte extended precision, calculated using the floating point functions in the memio_driver using soft switches.
Long Integer: (A&), 64 bit values created by combining two 68000 long words.
Integer: (A%), standard 32 bit integer

Structured programming constructs: Support for IF/ELSE/ENDIF, WHILE/WEND, REPEAT/UNTIL, SWItCH/CASE, and any other advanced structured constructs supported by the Sharp PC-G850.

PEEK/POKE take a 24 bit address argument and an 8 byte data argument/return value. CALL will take a 24 bit address argument and will return the value in D0, e.g. A% = CALL(102080h) will place the contents of D0 in A% when the routine returns.

24 bit limit on array sizes.

Implicit conversion between integer types; if converting from 64 bit to 32 bit, return the 32 bit modulus.
INT() command converts floating point variables as well as strings. Strings with non-digits or nonsense characters convert to 0.
STR$() command converts floating point and all integer types to strings.

BASIC internal data area should be placed at the start of the BASIC program buffer (at LOMEM) so that the entire buffer can be saved and restored using bsave and bload. This will also enable multiple programs to be placed in memory by changing LOMEM and HIMEM. NEW should initialize a BASIC buffer with all pointers and internal data needed to function.

PRINT statement should allow printing hexadecimal numbers up to 64 bits in width as decimal using the &H prefix, e.g. PRINT &HFE will print 254. There will be a DEC("HEX STRING") which will return up to a 64 bit decimal value in response to a hexadecimal string. The hex string argument need not be prefixed by a $, a 0x, or suffixed with a h or H. There will be a HEX$(number) function which will convert a decimal number into a hex string.

All common trig functions available to operate on floating point numbers (SIN, COS, TAN, ATN). Exponential, Base 10 log, natural log as well as raising a number to a power and nth root.


