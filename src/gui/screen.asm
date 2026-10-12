// ROM owns VIC-IV geometry, screen/colour pointers and memory mappings.
// All routines clobber A/X/Y and flags. No application zero-page allocation.
screen_init:
    lda #27
    jsr CHROUT
    lda #'8'                 // documented BASIC 65 80x25 escape sequence
    jsr CHROUT
    lda #147                // clear independently of prior BASIC text
    jsr CHROUT
    lda #142                // upper-case character set
    jsr CHROUT
    lda #146                // reverse off
    jsr CHROUT
    lda #159                // cyan
    jmp CHROUT
screen_exit:
    // Standard BASIC display, not a snapshot of the previous screen.
    // CINT is screen-editor initialization, NOT IOINIT (no drive access).
    jsr $ff81
    lda #27
    jsr CHROUT
    lda #'8'
    jsr CHROUT
    lda #146
    jsr CHROUT
    lda #142
    jsr CHROUT
    lda #5                  // white text
    jsr CHROUT
    lda #147
    jmp CHROUT
// X=row (0..24), Y=column (0..79).
screen_at:
    clc
    jmp PLOT
// A=low, Y=high of NUL-terminated PETSCII string (<256 bytes).
// Self-modifying operand avoids borrowing ROM zero page; not reentrant.
screen_text:
    sta screen_read+1
    sty screen_read+2
    lda #0
    sta screen_index
screen_next:
    ldx screen_index
screen_read:
    lda $ffff,x
    beq screen_done
    jsr CHROUT
    inc screen_index
    jmp screen_next
screen_done:
    rts
screen_index: .byte 0
// Horizontal separator at X=row. 78 chars, avoids wrapping/line pushing.
screen_line:
    ldy #1
    jsr screen_at
    lda #78
    sta screen_remaining
screen_line_loop:
    lda #'-'
    jsr CHROUT
    dec screen_remaining
    bne screen_line_loop
    rts
screen_remaining: .byte 0
