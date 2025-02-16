This is a plugin for the C64 assembler Profi-Ass v2 published by Data
Becker in 1984. This plugin enables Profi-Ass to emit object code to
GEOram (as opposed to disk or C64 main memory). Also provides a
routine to copy from GEOram to C64 memory.

Usage
---

Set GEOram starting block:

    SYS(49152) 0

Assemble to GEOram:

    .OPT P,O=$C020

Copy object code from GEOram to C64 memory:

    SYS49328
