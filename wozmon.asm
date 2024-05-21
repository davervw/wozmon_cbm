; wozmon.asm
;
; Originally from Apple-1 Operation Manual, Steve Wozniak, 1976
; Revised 2024 May 8 for Commodore 64/VIC/128 by David R. Van Wagner davevw.com
; * Using C64 KERNAL (instead of MC6520 and KBD/CRT)
; * extra processing for expected mark parity, software caps lock, and revised newline/carriage return processing
; * revised to expect terminal line edit mode instead of echo off character processing
; * revised to acme syntax
; * different zero page usage
; * changed l/h to wl/wh because vice didn't like that symbol
; * reverse toggle instead of spaces only on vic-20 (like HESMON) because too few columns

; zero page usage - tape stuff on vic-20, 64, 128.  Needs to change for PET, TED, Plus/4, 16, etc.
xaml=$a3
xamh=$a4
stl=$a5
sth=$a6
wl=$a7
wh=$a8
ysav=$a9
mode=$aa

in=$200 ; same as Commodore uses, should be fine to copy from/to this, will probably use slightly less

;** C64, etc. support added by David R. Van Wagner davevw.com ***************************************
; Commodore KENRAL
CHROUT=$FFD2
CHRIN=$FFCF
;** C64 etc. support added by David R. Van Wagner davevw.com ***************************************

* = $cf00
START:
	cld
	cli
	jmp escape
	
;** C64, etc. support added by David R. Van Wagner davevw.com ***************************************
KBD_IN:
	sty $22
	jsr CHRIN ; note: full screen editor
	ldy $22
	rts
;** C64, etc. support added by David R. Van Wagner davevw.com ***************************************

notcr:
	cmp #$DF ; underscore or Commodore back arrow (rub out?)
	beq backspace
	cmp #$83
	beq escape
	iny
	bpl nextchar
escape:
	lda #$DC ; backslash
	jsr echo
getline:
	lda #13
	jsr echo
	ldy #1
backspace:
	dey
	bmi getline
nextchar:
	jsr KBD_IN
	ora #$80
	sta in, y
	;jsr echo - needed only if terminal echo off, line editing off
	cmp #$8D
	bne notcr
	ldy #$ff
	lda #$00
	tax
setstor:
	asl
setmode:
	sta mode
blskip:
	iny
nextitem:
	lda in, y
	cmp #$8D
	beq getline
	cmp #$AE ; period
	bcc blskip
	beq setmode
	cmp #$BA ; colon
	beq setstor
	cmp #$D2 ; R
	beq run
	stx wl
	stx wh
	sty ysav
nexthex:
	lda in, y
	eor #$B0
	cmp #$0A
	bcc dig
	adc #$88
	cmp #$FA
	bcc nothex
dig:
	asl
	asl
	asl
	asl
	ldx #4
hexshift:
	asl
	rol wl
	rol wh
	dex
	bne hexshift
	iny
	bne nexthex
nothex:
	cpy ysav
	beq escape
	bit mode
	bvc notstor
	lda wl
	sta (stl, x)
	inc stl
	bne nextitem
	inc sth
tonextitem:
	jmp nextitem
run:
	jmp (xaml)
notstor:
	bmi xamnext
	ldx #2
setadr:
	lda wl-1,x
	sta stl-1,x
	sta xaml-1,x
	dex
	bne setadr
nxtprnt:
	bne prdata
	lda #13
	jsr echo
	lda xamh
	jsr prbyte
	lda xaml
	jsr prbyte
	lda #$BA ; colon
	jsr echo
prdata:
	lda #32
	jsr echo
	lda (xaml,x)
	jsr prbyte
xamnext:
	stx mode
	lda xaml
	cmp wl
	lda xamh
	sbc wh
	bcs tonextitem
	inc xaml
	bne mod8chk
	inc xamh
mod8chk:
	lda xaml
	and #7
	bpl nxtprnt ; should always branch
prbyte:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr prhex
	pla
prhex:
	and #$0F
	ora #$B0
	cmp #$BA
	bcc echo
	adc #6
echo:
;** C64, etc. support added by David R. Van Wagner davevw.com ***************************************
	and #$7f ; strip mark bit
	cmp #32	; space?
	bne notspace
	lda $FF80 ; Commodore ROM version
	cmp #$16  ; VIC?
	bne notvic
	lda 199
	eor #18	; invert reverse state
	sta 199
	rts
notvic:
    lda #32
notspace:
	jmp CHROUT
;** C64, etc. support added by David R. Van Wagner davevw.com ***************************************
