// MEGA65 Explorer Stage 1a, 2026-10-12. GPL-3.0; see LICENSE.
// Uses the 6502-compatible subset of the 45GS02, native BASIC 65 ROM.
.encoding "petscii_upper"
.const CHROUT = $ffd2
.const GETIN = $ffe4
.const PLOT = $fff0
.const VISIBLE = 16
* = $2001 "BASIC 65 launcher"
.word basicEnd
.word 10
.byte $9e
.text "8224"
.byte 0
basicEnd: .word 0
* = $2020 "Explorer"
main:
    php
    cld
    jsr screen_init
    jsr navigation_init
    jsr panels_draw
main_loop:
    jsr input_poll
    cmp #2
    beq main_exit
    cmp #1
    bne main_loop
    jsr panels_refresh
    jmp main_loop
main_exit:
    jsr screen_exit
    plp
    rts
#import "gui/screen.asm"
#import "core/vfs.asm"
#import "core/navigation.asm"
#import "gui/panels.asm"
#import "gui/filelist.asm"
#import "gui/input.asm"
#import "drivers/fat32.asm"
#import "drivers/dos.asm"
#import "drivers/iec.asm"
#import "data/mockfiles.asm"
