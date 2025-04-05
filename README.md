This is a plugin for the C64 assembler Profi-Ass v2 published by Data
Becker in 1984. This plugin enables Profi-Ass to emit object code to
GEOram (as opposed to disk or C64 main memory). Also provided are
routines to read from GEOram to C64 memory and load a PRG file from
disk to GEOram.

The idea is to reduce the amount of disk access required via a
workflow similar to the following:

1. Load assembler, monitor, source code, and any assets from disk to
   GEOram.
2. Write some code.
3. Assemble to GEOram.
4. Exit the assembler.
5. Load your object code and any assets from GEOram.
6. Test your program.
7. Soft-reset the C64.
8. Load assembler, monitor, and source code from GEOram.
9. Go to step 2.

This plugin has been designed to work hand-in-hand with both Profi-Ass
and Profi-Mon and sits in RAM from $CC00 to $CEBF. That means you can
have all 3 programs loaded without issue.

I've included cracked copies of both Profi-Ass and Profi-Mon, as well
as a manual in German.

Building
---

    make

Usage
---

First load the routines:

    LOAD"GEORAM-ROUTINES",8,1

Set GEOram starting block to 0, page 1:

    SYS(52224) 0,1

Assemble to GEOram:

    .OPT P,O=$CC2E

Read object code from GEOram to C64 memory:

    SYS52376

Load PRG file from disk device #8 to GEOram:

    SYS(52432) "PROFI-ASS-64-V2",8

Copying
---

Copyright (c) 2025 Ralph Moeritz. MIT license. See file COPYING for
details.
