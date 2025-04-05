.PHONY: default clean

profimon_prg := dist/profi-ass-64-v2.prg dist/profi-mon-64-v2.prg
routines_src := $(wildcard src/*.asm)
routines_prg := $(patsubst src/%.asm,dist/%.prg,$(routines_src))
routines_lst := $(patsubst %.prg,%.lst,$(routines_prg))
d64 := dist/profi-ass-georam.d64

default: $(d64)

# Target to create disk image
$(d64): $(profimon_prg) $(routines_prg)
	c1541 -format 'profi-ass georam',pg d64 $@ 8
	c1541 -attach $@ $(foreach prg,$^,-write $(prg) $(patsubst dist/%.prg,%,$(prg)))

clean:
	rm -f $(d64) $(routines_prg) $(routines_lst)

# Implicit rules
dist/%.prg: src/%.asm
	vasm6502_oldstyle -cbm-prg -Fbin -chklabels -nocase -dotdir $< \
-o $@ -L $(patsubst %.prg,%.lst,$@)
