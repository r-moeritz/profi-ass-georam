        ;; GEOram output module for Profi-Ass v2
        ;; =====================================
        ;; 
        ;; Copyright (c) 2025 Ralph Moeritz. MIT license. See file
        ;; COPYING for details.
        ;; ________________________________________________________
        ;; 
        ;; A plugin for Profi-Ass v2 to emit object code to GEOram. 
        ;; Also provided are routines to read from GEOram to C64 
        ;; memory and load a PRG file to GEOram.
        ;; 
        ;; Data Format
        ;; -----------
        ;;
        ;; +-------------+---------------+-------------+
        ;; |    $de00    |     $de02     |  $de04 ...  |
        ;; +-------------+---------------+-------------+
        ;; | data length | start address | object code |
        ;; +-------------+---------------+-------------+
        ;;
        ;; Usage
        ;; -----
        ;; 
        ;; Set GEOram starting block & page:
        ;; 
        ;;     SYS(49152) 0,2 REM BLOCK 0, PAGE 2
        ;; 
        ;; Assemble to GEOram:
        ;; 
        ;;     .OPT P,O=$C030
        ;; 
        ;; Read object code from GEOram to C64 memory:
        ;; 
        ;;     SYS49344
        ;;
        ;; Load PRG file to GEOram:
        ;; 
        ;;     SYS(49424) "FILENAME

        ;; Constants
PA_START:       .equ $80        ;pa_len value indicating start of assembly
PA_STOP:        .equ $c0        ;pa_len value indicating end of assembly
MAX_PAGE:       .equ 64         ;last GEOram page +1
MAX_BLOCK:      .equ 32         ;last GEOram block +1

        ;; OS routines
let:            .equ $a9b1      ;part of routine for BASIC let command
newline:        .equ $aad7      ;print CRLF        
strout:         .equ $ab1e      ;print 0 terminated string in A (lo) and Y (hi)
frmnum:         .equ $ad8a      ;eval numeric expression
comma:          .equ $aefd      ;detect comma in BASIC line
facwrd:         .equ $b7f7      ;convert FAC #1 to word at linnum
illqua:         .equ $b248      ;routine to trigger illegal quantity error
linprt:         .equ $bdcd      ;print 16-bit integer in X (lo) and A (hi)
setlfs:         .equ $ffba      ;set file, device, and secondary address
setnam:         .equ $ffbd      ;set filename
open:           .equ $ffc0      ;open file
close:          .equ $ffc3      ;close file in A
chrout:         .equ $ffd2      ;print a character in A
chkin:          .equ $ffc6      ;take input from file in A
clrchn:         .equ $ffcc      ;clear channel, restore default device
chrin:          .equ $ffcf      ;read char from file into A
        
        ;; OS memory
valtyp:         .ezp $0d        ;BYTE BASIC datatype ($ff string, $00 numeric)
intflg:         .ezp $0e        ;BYTE BASIC datatype ($80 int, $00 float)
linnum:         .ezp $14        ;WORD BASIC line number
forptr:         .ezp $49        ;BYTE,WORD pointer for BASIC for/next loop
status:         .ezp $90        ;BYTE kernal I/O status
        
        ;; GEOram registers
georam:         .equ $de00      ;PAGE first address of page mapped to GEOram
geopage:        .equ $dffe      ;BYTE GEOram page selection register
geoblock:       .equ $dfff      ;BYTE 16K GEOram block selection register

        ;; Profi-Ass variables to read
pa_op:          .ezp $4b        ;BYTEx3 buffer containing first 3 bytes
pa_len:         .ezp $4e        ;BYTE number of bytes to emit -1
pa_adr:         .ezp $56        ;WORD object code starting address
pa_buf:         .equ $015b      ;buffer for remaining bytes beyond first 3

        ;; Working memory        
curblock:       .ezp $92        ;BYTE current GEOram block (0-31)
datalen:        .ezp $96        ;WORD total bytes written or left to copy
curpage:        .ezp $a5        ;BYTE current GEOram page (0-63)        
offset:         .ezp $a7        ;BYTE offset within page ($00-$ff)
c64addr:        .ezp $a8        ;WORD address to copy to in C64 main memory
firstpage:      .ezp $f7        ;BYTE first GEORAM page to write to / copy from
firstblock:     .ezp $f8        ;BYTE first GEOram block to write to / copy from
strlen:         .ezp $f9        ;BYTE string length
strptr:         .ezp $fa        ;WORD string pointer

        ;; Set first block and page from user input.
        ;; Call from BASIC via:
        ;;     SYS(49152) BLOCK,PAGE
        ;; ------------------------------------------
        .org $c000
setfirst:
        jsr getwrd
        lda linnum+1
        bne iqerr
        lda linnum
        cmp #MAX_BLOCK
        bcs iqerr
        sta firstblock
        jsr comma
        jsr getwrd
        lda linnum+1
        bne iqerr
        lda linnum
        cmp #MAX_PAGE
        bcs iqerr
        sta firstpage
        rts
iqerr:  jmp illqua
        
        ;; Write object code to GEOram.
        ;; Call from Profi-Ass via:
        ;;     .OPT P,O=$C030
        ;; ----------------------------
        .align 4
write:  lda pa_len
        cmp #PA_STOP
        beq finwrt
        cmp #PA_START
        beq wrstrt
        ldy #0
        ldx offset
wrout:  lda pa_op,y
wrout1: sta georam,x
        jsr inc_datalen         ;increment total bytes written
        inx
        beq wrnxpg              ;overflow? next page!
        stx offset
wrchln: cpy pa_len
        beq wrfin
        iny
        cpy #3
        bcc wrout
        lda pa_buf-3,y
        jmp wrout1
wrnxpg: ldx #0
        stx offset
        inc curpage
        lda curpage
        cmp #MAX_PAGE
        beq wrnxbk              ;past page 63? next block!
        sta geopage
        jmp wrchln
wrnxbk: lda #0
        sta curpage
        sta geopage
        inc curblock
        lda curblock
        cmp #MAX_BLOCK          ;past page 31? out of memory!
        beq enomem
        sta geoblock
        jmp wrchln
wrstrt: jsr init
        ldx offset
        lda pa_adr
        sta georam,x
        inx
        lda pa_adr+1
        sta georam,x
        inx
        stx offset
wrfin:  rts        
        ;; Write data length to first block & page of GEOram
finwrt: lda firstblock
        sta geoblock
        sta curblock
        lda firstpage
        sta geopage
        sta curpage
        lda datalen
        sta georam
        lda datalen+1
        sta georam+1
        jsr print_wrtmsg
        rts
enomem: jsr newline
        lda #<oommsg
        ldy #>oommsg
        jsr strout
        rts

        ;; Read object code from GEOram.
        ;; Call from BASIC via:
        ;;     SYS49344
        ;; ------------------------------------
        .align 4
read:   jsr read_header
        inx
        ldy #0
rdloop: lda georam,x
        sta (c64addr),y
        jsr dec_datalen         ;decrement remaining bytes
        lda datalen+1
        bne :+
        lda datalen
        beq rdfin               ;exit if remaining bytes == 0
:       iny
        beq incadr
rdchpg: inx
        beq rdnxpg
        jmp rdloop
incadr: inc c64addr+1
        jmp rdchpg
rdnxpg: ldx #0
        inc curpage
        lda curpage
        cmp #MAX_PAGE
        beq rdnxbk              ;past page 63? next block!
        sta geopage
        jmp rdloop
rdnxbk: lda #0
        sta curpage
        sta geopage
        inc curblock
        lda curblock
        cmp #MAX_BLOCK          ;past block 31? out of memory!
        beq enomem
        sta geoblock
        jmp rdloop
rdfin:  jsr read_header
        jsr print_rdmsg
        rts

        ;; Load PRG file contents to GEOram.
        ;; Call from BASIC via:
        ;;     SYS(49424) "FILENAME"
        ;; ---------------------------------
        .align 4
ldprg:  jsr getstr              ;read string from BASIC
        lda strlen
        beq ldfin               ;short circuit exit if strlen == 0
        jsr init                ;init GEOram registers & working memory
        jsr cpyfnm              ;copy string to filename buffer
        lda #1
        ldx #8
        ldy #2
        jsr setlfs              ;set file #, device #, secondary address
        lda strlen
        clc
        adc #6                  ;add 6 to length for '0:' prefix and ',p,r' suffix
        ldx #<fnmbuf
        ldy #>fnmbuf
        jsr setnam              ;setup filename
        jsr open                ;open file for reading
        ldx #1
        jsr chkin               ;take input from file #1
        ;; Copy PRG address (first two bytes)
        jsr chrin
        ldx offset              ;leave space for data length
        sta georam,x
        inx
        jsr chrin
        sta georam,x
        inx
ldloop: jsr chrin
        sta georam,x
        jsr inc_datalen
        lda status
        bne ldfin
        inx
        beq ldnxpg              ;overflow? next page!
        jmp ldloop
ldnxpg: ldx #0
        inc curpage
        lda curpage
        cmp #MAX_PAGE
        beq ldnxbl
        sta geopage
        jmp ldloop
ldnxbl: ldx #0
        stx curpage
        stx geopage
        inc curblock
        lda curblock
        cmp #MAX_BLOCK          ;past page 31? out of memory!
        beq ldnomem
        sta geoblock
        jmp ldloop
ldnomem:
        jsr newline
        lda #<oommsg
        ldy #>oommsg
        jsr strout
ldfin:  lda #1
        jsr close               ;close file in A
        jsr clrchn              ;clear channels, restore default devices
        ;; Write data length to first word of first block+page
        lda firstblock
        sta curblock
        sta geoblock
        lda firstpage
        sta curpage
        sta geopage
        lda datalen
        sta georam
        lda datalen+1
        sta georam+1
        jsr print_wrtmsg
        rts
        
        ;; Routine to initialize GEOram registers & working memory
init:   lda firstblock
        sta geoblock
        sta curblock
        lda firstpage
        sta geopage
        sta curpage
        lda #0
        sta datalen
        sta datalen+1        
        lda #2                  ;set offset to 2 to leave space for data length
        sta offset
        rts
        
        ;; Routine to increment data length
inc_datalen:
        inc datalen
        bne :+
        inc datalen+1
:       rts

        ;; Routine to decrement data length
dec_datalen:
        dec datalen
        lda datalen
        cmp #$ff
        bne :+
        dec datalen+1
:       rts
        
        ;; Routine to print summary of data written
print_wrtmsg:
        jsr newline
        ldx datalen
        lda datalen+1
        jsr linprt
        lda #<wrtmsg
        ldy #>wrtmsg
        jsr strout
        ldx curblock
        lda #0
        jsr linprt
        lda #','
        jsr chrout
        ldx curpage
        lda #0
        jsr linprt
        rts

        ;; Routine to print summary of data copied
print_rdmsg:
        jsr newline
        ldx datalen
        lda datalen+1
        jsr linprt
        lda #<rdmsg
        ldy #>rdmsg
        jsr strout
        ldx c64addr
        lda c64addr+1
        jsr linprt
        rts

        ;; Routine to read data length & C64 address from GEOram
read_header:
        jsr init
        ldx #0
        ;; Read data length
        lda georam,x
        sta datalen
        inx
        lda georam,x
        sta datalen+1
        inx
        ;; Read C64 address
        lda georam,x
        sta c64addr
        inx
        lda georam,x
        sta c64addr+1
        rts

        ;; Read word from BASIC
getwrd: jsr frmnum
        jmp facwrd

        ;; Read string from BASIC
getstr: lda #$ff
        sta valtyp
        sta intflg
        lda #<strlen
        ldx #>strlen
        sta forptr
        stx forptr+1
        jmp let

        ;; Routine to copy string to filename buffer
cpyfnm: ldx strlen
        inx
        inx
        lda #","
        sta fnmbuf,x
        inx
        lda #"P"
        sta fnmbuf,x
        inx
        lda #","
        sta fnmbuf,x
        inx
        lda #"R"
        sta fnmbuf,x
        lda strlen
        tax
        sec
        sbc #1
        tay
        inx
:       bmi :+
        lda (strptr),y
        sta fnmbuf,x
        dex
        dey
        jmp :-
:       rts

        ;; Filename buffer
fnmbuf: .text "0:"
        .blk 20

        ;; Message for write operation
wrtmsg: .string " BYTES WRITTEN TO GEORAM "

        ;; Message for read operation
rdmsg:  .string " BYTES READ FROM GEORAM TO "

        ;; Out of memory error message
oommsg: .string "ERROR: GEORAM OUT OF MEMORY"
