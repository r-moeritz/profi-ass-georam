        ;; GEOram output module for Profi-Ass v2
        ;; =====================================
        ;; A plugin for Profi-Ass v2 to emit object code to GEOram.
        ;; Also provides a routine to copy to C64 memory.
        ;; 
        ;; Format:
        ;; +-------------+---------------+-------------+
        ;; |    WORD     |     WORD      |             |
        ;; | data length | start address | object code |
        ;; +-------------+---------------+-------------+
        ;;
        ;; Usage:
        ;; ------
        ;; Set GEOram starting block:
        ;;   SYS(49152) 0
        ;; 
        ;; Assemble to GEOram:
        ;;   .OPT P,O=$C020
        ;; 
        ;; Copy object code from GEOram to C64 memory:
        ;;   SYS49328

        ;; Constants
PA_START:       .equ $80        ;pa_len value indicating start of assembly
PA_STOP:        .equ $c0        ;pa_len value indicating end of assembly
MAX_PAGE:       .equ 64         ;last GEOram page +1
MAX_BLOCK:      .equ 32         ;last GEOram block +1

        ;; OS routines
newline:        .equ $aad7      ;print CRLF        
strout:         .equ $ab1e      ;print 0 terminated string in A (lo) and Y (hi)
frmnum:         .equ $ad8a      ;eval numeric expression
facwrd:         .equ $b7f7      ;convert FAC #1 to word at linnum
illqua:         .equ $b248      ;routine to trigger illegal quantity error
linprt:         .equ $bdcd      ;print 16-bit integer in X (lo) and A (hi)
        
        ;; OS memory
linnum:         .ezp $14        ;variable to store BASIC line number
        
        ;; GEOram registers
georam:         .equ $de00      ;first address mapped to GEOram
geoblock:       .equ $dfff      ;16K GEOram block selection register
geopage:        .equ $dffe      ;GEOram page selection register

        ;; Profi-Ass variables to read
pa_op:          .ezp $4b        ;BYTEx3 buffer containing first 3 bytes
pa_len:         .ezp $4e        ;BYTE number of bytes to emit -1
pa_adr:         .ezp $56        ;WORD object code starting address
pa_buf:         .equ $015b      ;buffer for remaining bytes beyond first 3

        ;; Working memory
datalen:        .ezp $a3        ;WORD total bytes written or left to copy
curblock:       .ezp $a5        ;BYTE current GEOram block (0-31)
curpage:        .ezp $a6        ;BYTE current GEOram page (0-63)
offset:         .ezp $a7        ;BYTE offset within page ($00-$ff)
c64addr:        .ezp $a7        ;WORD address to copy to in C64 main memory
first_block:    .ezp $a8        ;BYTE first GEOram block to write to / copy from

        ;; Set number of first block from user input.
        ;; Call from BASIC via SYS.
        ;; ------------------------------------------
        .org $c000
set_block:
        jsr getwrd
        lda linnum+1
        bne iqerr
        lda linnum
        cmp #MAX_BLOCK
        bcs iqerr        
        sta first_block
        rts
iqerr:  jmp illqua
        
        ;; Write object code to GEOram.
        ;; Called by Profi-Ass.
        ;; ----------------------------
        .align 4
write:  lda pa_len
        cmp #PA_STOP
        beq finwrt
        cmp #PA_START
        beq start
        ldy #0
        ldx offset
out:    lda pa_op,y
out1:   sta georam,x
        jsr inc_datalen          ;increment total bytes written
        inx
        bvs nextpage            ;overflow? next page!
        stx offset
chklen: cpy pa_len
        beq return
        iny
        cpy #3
        bcc out
        lda pa_buf-3,y
        jmp out1
nextpage:
        ldx #0
        stx offset
        inc curpage
        lda curpage
        cmp #MAX_PAGE
        beq nextblock           ;past page 63? next block!
        sta geopage
        jmp chklen
nextblock:
        lda #0
        sta curpage
        sta geopage
        inc curblock
        lda curblock
        cmp #MAX_BLOCK
        beq enomem
        sta geoblock
        jmp chklen
start:  jsr init
        ldx offset
        lda pa_adr
        sta georam,x
        inx
        lda pa_adr+1
        sta georam,x
        inx
        stx offset
return: rts        
        ;; Write data length to first word in first block of GEOram
finwrt: lda first_block
        sta geoblock
        sta curblock
        lda #0
        sta geopage
        sta curpage
        ldx #0
        lda datalen,x
        sta georam,x
        inx
        lda datalen,x
        sta georam,x
        jsr print_write_summary
        rts
enomem: jsr newline
        lda #<outofmem
        ldy #>outofmem
        jsr strout
        rts

        ;; Copy object code from GEOram to C64.
        ;; Call from BASIC via SYS.
        ;; ------------------------------------
        .align 4
read:   jsr init
        jsr read_header
        inx
        ;; Copy loop
        ldy #0
rloop:  lda georam,x
        sta (c64addr),y
        jsr dec_datalen
        lda datalen
        beq fincpy
        iny
        bvs incadr
chkpg:  inx
        bvs nxpag
        jmp rloop
incadr: jsr inc_c64addr
        jmp chkpg
nxpag:  inc curpage
        lda curpage
        cmp #MAX_PAGE
        beq nxblk               ;past page 63? next block!
        sta geopage
        jmp rloop
nxblk:  lda #0
        sta curpage
        sta geopage
        inc curblock
        lda curblock
        cmp #MAX_BLOCK
        beq enomem
        sta geoblock
        jmp rloop
fincpy: jsr read_header
        jsr print_copy_summary
        rts
        
        ;; Routine to initialize GEOram registers & working memory
init:   lda first_block
        sta geoblock
        sta curblock
        lda #0
        sta geopage
        sta curpage
        sta datalen
        sta datalen+1        
        lda #2                  ;set offset to 2 to leave space for data length
        sta offset
        rts
        
        ;; Routine to increment data length
inc_datalen:
        clc
        lda datalen
        adc #1
        sta datalen
        lda datalen+1
        adc #0
        sta datalen+1
        rts

        ;; Routine to print summary of data written
print_write_summary:
        jsr newline
        ldx datalen
        lda datalen+1
        jsr linprt
        lda #<write_summary
        ldy #>write_summary
        jsr strout
        ldx curblock
        lda #0
        jsr linprt
        rts

        ;; Routine to print summary of data copied
print_copy_summary:
        jsr newline
        ldx datalen
        lda datalen+1
        jsr linprt
        lda #<copy_summary
        ldy #>copy_summary
        jsr strout
        ldx c64addr
        lda c64addr+1
        jsr linprt
        rts

        ;; Routine to decrement data length
dec_datalen:
        sec
        lda datalen
        sbc #1
        sta datalen
        lda datalen+1
        sbc #0
        sta datalen+1
        rts

        ;; Routine to increment C64 address
inc_c64addr:
        clc
        lda c64addr
        adc #1
        sta c64addr
        lda c64addr+1
        adc #0
        sta c64addr+1
        rts

        ;; Routine to read data length & C64 address from GEOram
read_header:
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
        
write_summary:
        .string " BYTES WRITTEN TO GEORAM BLOCK "

copy_summary:
        .string " BYTES COPIED FROM GEORAM TO "

outofmem:
        .string "ERROR: GEORAM OUT OF MEMORY"
