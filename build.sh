#!/usr/bin/env bash

NAME=georam-out

vasm6502_oldstyle -cbm-prg -Fbin -chklabels -nocase -dotdir \
                  src/$NAME.asm -o dist/$NAME.prg -L dist/$NAME.lst
