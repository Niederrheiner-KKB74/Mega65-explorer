// MEGA65 Explorer Stage 1c, 2026-10-12. GPL-3.0; see LICENSE.
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
    jsr vfs_init
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
    jsr vfs_close
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

// All application buffers live in the loaded PRG, bank 0, below $8000.
.align $100
fat32_transfer: .fill 256,0
fat32_transfer_end:
vfs_buffer: .fill MAX_ENTRIES*ENTRY_SIZE,0
vfs_buffer_end:
vfs_staging: .fill MAX_ENTRIES*ENTRY_SIZE,0
vfs_staging_end:
.assert "Page-aligned HDOS transfer", 0, fat32_transfer & $ff
.assert "Transfer fits documented range", true, fat32_transfer <= $7e00
.assert "Directory buffer remains below $8000", true, vfs_staging_end <= $8000
