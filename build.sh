#!/bin/sh -x
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export VICE=${USERPROFILE}/Downloads/GTK3VICE-3.8-win64/bin
${ACME}/acme -f cbm -o wozmon.prg -l wozmon.lbl -r wozmon.lst wozmon.asm \
&& ${VICE}/c1541 wozmon.d64 -attach wozmon.d64 8 -delete "wozmon sys5120" -write wozmon.prg "wozmon sys5120" \
&& ${VICE}/x64sc -moncommands wozmon.lbl -autostart wozmon.d64 >/dev/null 2>&1 &
