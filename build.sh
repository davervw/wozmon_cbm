#!/bin/sh -x
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export VICE=${USERPROFILE}/Downloads/GTK3VICE-3.8-win64/bin
${ACME}/acme -f cbm -o wozmon.prg -l wozmon.lbl -r wozmon.lst wozmon.asm \
&& ${ACME}/acme -f cbm -o vwas6502.prg -l vwas6502.lbl -r vwas6502.lst vwas6502.asm \
&& cat wozmon.lbl vwas6502.lbl > debug.lbl \
&& ${VICE}/c1541 wozmon.d64 -attach wozmon.d64 8 -delete "wozmon sys5120" -write wozmon.prg "wozmon sys5120" \
&& ${VICE}/c1541 wozmon.d64 -attach wozmon.d64 8 -delete "vwas6502" -write vwas6502.prg "vwas6502" \
&& ${VICE}/x64sc -moncommands debug.lbl -autostart wozmon.d64 >/dev/null 2>&1 &
