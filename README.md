This is a plugin for the C64 assembler Profi-Ass v2 published by Data
Becker in 1984. This plugin enables Profi-Ass to emit object code to
GEOram (as opposed to disk or C64 main memory). Also provided are
routines to read from GEOram to C64 memory and load a PRG file to
GEOram.

Usage
---

Set GEOram starting block and page:

    SYS(49152) 0,2 REM BLOCK 0, PAGE 2

Assemble to GEOram:

    .OPT P,O=$C030

Read object code from GEOram to C64 memory:

    SYS49344

Load PRG file to GEOram:

    SYS(49424) "FILENAME"

Copying
---

Copyright (c) 2025 Ralph Moeritz. MIT license. See file COPYING for
details.
