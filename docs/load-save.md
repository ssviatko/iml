Proposal for binary load/save commands

There shall be two command for binary loading/saving directly to shared memory:

Saving:

bsave --address <24 bit address> --length <24 bit length> filename-to-output

Loading:

bload --address <24 bit address> filename-to-load

24 bit values for the address and length can be specified as hexadecimal numbers by prefixing the number with a "$", or else they are treated as decimal values.

These two programs, which will be named bsave.c and bload.c, will parse the command line and check for out of bounds values (greater than 16MB, less than zero, etc), file existence and sane length, and throw necessary errors. Then they will connect to the shared memory segment and load the data/save the data directly out of memory.

If the shared memory segment is not loaded, or if there is any other error accessing the shared memory segment, then the program(s) will gracefully notify the user and exit. There shall be no stray ipcs left over (as shown by the ipcs command) if the program(s) have to terminate abnormally.


