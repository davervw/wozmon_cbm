;; vwas6502.asm - interactive console 6502 assembler
;;
;; >>> STATUS: work in progress, disassembles itself <<<
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MIT License
;;
;; Copyright (c) 2024 David R. Van Wagner
;; davevw.com
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

*=$c000

; kernal/system calls
charout=$ffd2

; zeropage
ptr1=$fb ; and $fc
ptr2=$fd ; and $fe
tmp=$ff
opidx=$22
inidx=$23
mode=$24
size=$25
ptr3=$26 ; and $27

; test
start:
    jmp +

test: ; all the addressing modes here for testing disassembly
    nop
    lda $1234
    lda $1234,x
    lda $1234,y
    asl
    lda #$12
    lda ($12,x)
    lda ($12),y
    jmp ($1234)
-   bne -
    lda $12
    lda $12,x
    ldx $12,y
    !byte $FF ; unknown

+   lda #<start
    ldx #>start
    sta ptr1
    stx ptr1+1
    lda #<end
    ldx #>end
    sta ptr2
    stx ptr2+1
    jsr disassemble
    lda ptr2
    ldx ptr2+1
    sta ptr1
    stx ptr1+1
    lda #<finish
    ldx #>finish
    sta ptr2
    stx ptr2+1
    jmp display_memory

disassemble:
-   ldy #0
    lda (ptr1),y
    jsr find_opcode
    jsr disp_current
    lda size
    bpl +
    lda #1
+   clc
    adc ptr1
    sta ptr1
    bcc +
    inc ptr1+1
+   jsr compareptrs
    bcc -
    rts

compareptrs:
    lda ptr1+1
    cmp ptr2+1
    bne +
    lda ptr1
    cmp ptr2
+   rts

find_opcode: ; INPUT: .A opcode byte, OUTPUT: C flag set if found, .A instruction index, .X opcode index, .Y mode, otherwise C clear, and .A/.X/.Y all $FF
; and properties updated in ZP globals size,inidx,opidx,mode
    ldy #1
    sty size
    ldy #nopcodes
    ldx #nopcodes-1
-   cmp opcodes,x
    beq +
    dex
    dey
    bne -
    clc
    lda #$FF
    tax
    tay
    bcc ++
+   lda instidx, x
    ldy modeidx, x
    cpy #2 // Immediate
    bcc +
    inc size
    cpy #9 // Absolute
    bcc +
    inc size
+   sec
++  sta inidx
    stx opidx
    sty mode
    rts

disp_opcode: ; .A opcode byte
    jsr find_opcode
    txa
    ; fall through to display instruction

dispinst: ; .A instruction index 0..55
    tax
    cpx #ninst
    bcs +
    lda inst0, x
    jsr charout
    lda inst1, x
    jsr charout
    lda inst2, x
    jmp charout
+   lda #'?'
    jsr charout
    jsr charout
    jsr charout
    rts

disp_current:
    lda ptr1
    ldx ptr1+1
    jsr disphexword
    lda #$20
    jsr charout
    ldy #0
    ldx size
-   lda (ptr1),y
    jsr disphexbyte
    lda #$20
    jsr charout
    iny
    dex
    bne -
-   cpy #3
    beq +
    lda #$20
    jsr charout
    jsr charout
    jsr charout
    iny
    bne -
+   lda inidx
    jsr dispinst
    lda #$20
    jsr charout
    jsr disp_mode
    lda #13
    jmp charout

disp_mode
    lda mode
    cmp #13
    bcs +
    asl
    tax
    lda mode_jmptable+1,x
    pha
    lda mode_jmptable,x
    pha
+   rts

dispModeAcc:
    lda #'A'
    jmp charout

dispModeNone:
    rts

dispModeImm:
    lda #'#'
    jsr charout
dispModeZP:
    lda #'$'
    jsr charout
    ldy #1
    lda (ptr1),y
    jmp disphexbyte

dispModeIndX:
    lda #'('
    jsr charout
    lda #'$'
    jsr charout
    ldy #1
    lda (ptr1),y
    jsr disphexbyte
    lda #','
    jsr charout
    lda #'X'
    jsr charout
    lda #')'
    jmp charout

dispModeIndY:
    lda #'('
    jsr charout
    lda #'$'
    jsr charout
    ldy #1
    lda (ptr1),y
    jsr disphexbyte
    lda #')'
    jsr charout
    lda #','
    jsr charout
    lda #'Y'
    jmp charout

dispModeRel:
    lda #'$'
    jsr charout
    clc
    lda ptr1
    adc #2
    sta ptr3
    lda ptr1+1
    adc #0
    sta ptr3+1
    ldy #1
    lda (ptr1),y
    bpl +
    ; I'm not sure how to successfully navigate page boundries adding signed byte to unsigned byte, so I'm subtracting unsigned bytes instead
    eor #$FF ; inverse
    clc
    adc #1 ; complete getting absolute value from two's complement
    sta tmp
    sec
    lda ptr3
    sbc tmp
    sta ptr3
    bcs ++
    dec ptr3+1
    bcc ++
+   clc ; simple case of adding
    adc ptr3
    sta ptr3
    bcc ++
    inc ptr3+1
++  lda ptr3
    ldx ptr3+1
    jmp disphexword

dispModeZPX:
    jsr dispModeZP
    lda #','
    jsr charout
    lda #'X'
    jmp charout

dispModeZPY:
    jsr dispModeZP
    lda #','
    jsr charout
    lda #'Y'
    jmp charout

dispModeAbs:
    lda #'$'
    jsr charout
    ldy #1
    lda (ptr1),y
    pha
    iny
    lda (ptr1),y
    tax
    pla
    jmp disphexword

dispModeAbsX:
    jsr dispModeAbs
    lda #','
    jsr charout
    lda #'X'
    jmp charout

dispModeAbsY:
    jsr dispModeAbs
    lda #','
    jsr charout
    lda #'Y'
    jmp charout

dispModeInd:
    lda #'('
    jsr charout
    jsr dispModeAbs
    lda #')'
    jmp charout

disphexword: ; .A low, .X high, 0000..FFFF
    pha
    txa
    jsr disphexbyte
    pla
    ;fall through to call again

disphexbyte: ; .A 00..FF
    pha
    lsr
    lsr
    lsr
    lsr
    jsr disphexnybble
    pla
    ;fall through to call again

disphexnybble: ; .A 0..F
    and #$0F
    ora #$30
    cmp #$3A
    bcc +
    adc #$06
+   jmp charout

display_memory:
--  lda ptr1
    ldx ptr1+1
    jsr disphexword
    lda #$20
    jsr charout
-   jsr compareptrs
    bcs +
    ldy #0
    lda (ptr1),y
    jsr disphexbyte
    lda #$20
    jsr charout
+   inc ptr1
    bne +
    inc ptr1+1
+   lda ptr1
    and #$07
    bne -
    lda #13
    jsr charout
    jsr compareptrs
    bcc --
    rts

; charout: ; for debugging, wait for scan line to pass over entire screen at least once
;     jsr $ffd2
;     pha
; -   lda $d011
;     bpl -
; -   lda $d011
;     bmi -
; -   lda $d011
;     bpl -
; -   lda $d011
;     bmi -
;     pla
;     rts

end: brk

; instruction textual mnuemonic first, second, third letters (read down in source)
ninst = 56
inst0 !text "AAABBBBBBBBBBCCCCCCCDDDEIIIJJLLLLNOPPPPRRRRSSSSSSSTTTTTT"
inst1 !text "DNSCCEIMNPRVVLLLLMPPEEEONNNMSDDDSORHHLLOOTTBEEETTTAASXXY"
inst2 !text "CDLCSQTIELKCSCDIVPXYCXYRCXYPRAXYRPAAPAPLRISCCDIAXYXYXASA"

; 6502 addressing modes by index number and number of bytes per instruction shown at end of comment
mode_jmptable:
!word dispModeAcc-1; 0 Accumulator 1
!word dispModeNone-1 ; 1 None 1
!word dispModeImm-1 ; 2 Immediate 2
!word dispModeIndX-1 ; 3 IndirectX 2
!word dispModeIndY-1 ; 4 IndirectY 2
!word dispModeRel-1 ; 5 Relative 2
!word dispModeZP-1 ; 6 ZeroPage 2
!word dispModeZPX-1 ; 7 ZeroPageX 2
!word dispModeZPY-1 ; 8 ZeroPageY 2
!word dispModeAbs-1 ; 9 Absolute 3
!word dispModeAbsX-1 ; 10 AbsoluteX 3
!word dispModeAbsY-1 ; 11 AbsoluteY 3
!word dispModeInd-1 ; 12 Indirect 3

; opcode table of byte values (opcodes), instructions, and addressing modes
nopcodes = 151
opcodes !byte $00,$01,$05,$06,$08,$09,$0A,$0D,$0E,$10,$11,$15,$16,$18,$19,$1D,$1E,$20,$21,$24,$25,$26,$28,$29,$2A,$2C,$2D,$2E,$30,$31,$35,$36,$38,$39,$3D,$3E,$40,$41,$45,$46,$48,$49,$4A,$4C,$4D,$4E,$50,$51,$55,$56,$58,$59,$5D,$5E,$60,$61,$65,$66,$68,$69,$6A,$6C,$6D,$6E,$70,$71,$75,$76,$78,$79,$7D,$7E,$81,$84,$85,$86,$88,$8A,$8C,$8D,$8E,$90,$91,$94,$95,$96,$98,$99,$9A,$9D,$A0,$A1,$A2,$A4,$A5,$A6,$A8,$A9,$AA,$AC,$AD,$AE,$B0,$B1,$B4,$B5,$B6,$B8,$B9,$BA,$BC,$BD,$BE,$C0,$C1,$C4,$C5,$C6,$C8,$C9,$CA,$CC,$CD,$CE,$D0,$D1,$D5,$D6,$D8,$D9,$DD,$DE,$E0,$E1,$E4,$E5,$E6,$E8,$E9,$EA,$EC,$ED,$EE,$F0,$F1,$F5,$F6,$F8,$F9,$FD,$FE
instidx !byte $0A,$22,$22,$02,$24,$22,$02,$22,$02,$09,$22,$22,$02,$0D,$22,$22,$02,$1C,$01,$06,$01,$27,$26,$01,$27,$06,$01,$27,$07,$01,$01,$27,$2C,$01,$01,$27,$29,$17,$17,$20,$23,$17,$20,$1B,$17,$20,$0B,$17,$17,$20,$0F,$17,$17,$20,$2A,$00,$00,$28,$25,$00,$28,$1B,$00,$28,$0C,$00,$00,$28,$2E,$00,$00,$28,$2F,$31,$2F,$30,$16,$35,$31,$2F,$30,$03,$2F,$31,$2F,$30,$37,$2F,$36,$2F,$1F,$1D,$1E,$1F,$1D,$1E,$33,$1D,$32,$1F,$1D,$1E,$04,$1D,$1F,$1D,$1E,$10,$1D,$34,$1F,$1D,$1E,$13,$11,$13,$11,$14,$1A,$11,$15,$13,$11,$14,$08,$11,$11,$14,$0E,$11,$11,$14,$12,$2B,$12,$2B,$18,$19,$2B,$21,$12,$2B,$18,$05,$2B,$2B,$18,$2D,$2B,$2B,$18
modeidx !byte $01,$03,$06,$06,$01,$02,$00,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A,$09,$03,$06,$06,$06,$01,$02,$00,$09,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A,$01,$03,$06,$06,$01,$02,$00,$09,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A,$01,$03,$06,$06,$01,$02,$00,$0C,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A,$03,$06,$06,$06,$01,$01,$09,$09,$09,$05,$04,$07,$07,$08,$01,$0B,$01,$0A,$02,$03,$02,$06,$06,$06,$01,$02,$01,$09,$09,$09,$05,$04,$07,$07,$08,$01,$0B,$01,$0A,$0A,$0B,$02,$03,$06,$06,$06,$01,$02,$01,$09,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A,$02,$03,$06,$06,$06,$01,$02,$01,$09,$09,$09,$05,$04,$07,$07,$01,$0B,$0A,$0A

finish = *
