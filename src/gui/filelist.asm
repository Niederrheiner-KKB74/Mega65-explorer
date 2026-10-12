// Draw exactly VISIBLE rows for render_panel; data supplied only by VFS.
// Fixed 37-character rows clear old text/highlights without touching borders.
filelist_draw:
    lda #0
    sta list_row
filelist_row:
    lda #146
    jsr CHROUT
    lda #159
    jsr CHROUT
    ldx render_panel
    lda scroll,x
    clc
    adc list_row
    sta list_index
    cmp entry_counts,x
    bcs filelist_position
    lda list_index
    cmp selected,x
    bne filelist_position
    lda render_panel
    cmp active_panel
    bne filelist_position
    lda #5
    jsr CHROUT
    lda #18
    jsr CHROUT
filelist_position:
    lda list_row
    clc
    adc #5
    tax
    ldy #2
    lda render_panel
    beq filelist_at
    ldy #41
filelist_at:
    jsr screen_at
    ldx render_panel
    lda list_index
    cmp entry_counts,x
    bcs filelist_blank
    jsr vfs_entry
    ldy #0
    jsr vfs_read
    cmp #TYPE_DIR
    beq filelist_dir
    lda #<file_prefix
    ldy #>file_prefix
    jmp filelist_prefix
filelist_dir:
    lda #<dir_prefix
    ldy #>dir_prefix
filelist_prefix:
    jsr screen_text
    lda #4
    sta name_offset
filelist_name:
    ldy name_offset
    jsr vfs_read
    jsr CHROUT
    inc name_offset
    lda name_offset
    cmp #ENTRY_SIZE
    bne filelist_name
    lda render_panel
    bne filelist_no_size
    jsr filelist_size
    lda #3
    jmp filelist_spaces
filelist_no_size:
    lda #11
    jmp filelist_spaces
filelist_blank:
    lda #37
filelist_spaces:
    sta spaces_left
filelist_space:
    lda #' '
    jsr CHROUT
    dec spaces_left
    bne filelist_space
    lda #146
    jsr CHROUT
    inc list_row
    lda list_row
    cmp #VISIBLE
    beq filelist_done
    jmp filelist_row
filelist_done:
    rts
list_row: .byte 0
list_index: .byte 0
name_offset: .byte 0
spaces_left: .byte 0
dir_prefix: .text "[DIR] "
.byte 0
file_prefix: .text "      "
.byte 0

// 8-character size column for left files. Right stays identical to Stage 1a.
filelist_size:
    ldy #1
    jsr vfs_read
    and #FLAG_SIZE_KNOWN
    bne filelist_size_known
    jmp filelist_size_unknown
filelist_size_known:
    ldy #1
    jsr vfs_read
    and #FLAG_SIZE_SATURATED
    beq filelist_size_normal
    jmp filelist_size_large
filelist_size_normal:
    ldy #2
    jsr vfs_read
    sta size_value
    iny
    jsr vfs_read
    sta size_value+1
    lda #$20
    jsr CHROUT
    lda #$20
    jsr CHROUT
    lda #0
    sta size_digit_index
    sta size_started
filelist_decimal_digit:
    ldx size_digit_index
    lda #0
    sta size_digit
filelist_decimal_subtract:
    lda size_value+1
    cmp decimal_hi,x
    bcc filelist_decimal_emit
    bne filelist_decimal_take
    lda size_value
    cmp decimal_lo,x
    bcc filelist_decimal_emit
filelist_decimal_take:
    sec
    lda size_value
    sbc decimal_lo,x
    sta size_value
    lda size_value+1
    sbc decimal_hi,x
    sta size_value+1
    inc size_digit
    jmp filelist_decimal_subtract
filelist_decimal_emit:
    lda size_digit
    bne filelist_decimal_visible
    lda size_started
    bne filelist_decimal_visible
    cpx #4
    beq filelist_decimal_visible
    lda #$20
    jmp filelist_decimal_output
filelist_decimal_visible:
    lda #1
    sta size_started
    lda size_digit
    clc
    adc #$30
filelist_decimal_output:
    jsr CHROUT
    inc size_digit_index
    lda size_digit_index
    cmp #5
    bne filelist_decimal_digit
    lda #'K'
    jmp CHROUT
filelist_size_unknown:
    lda #<size_blank
    ldy #>size_blank
    jmp screen_text
filelist_size_large:
    lda #<size_large
    ldy #>size_large
    jmp screen_text
size_value: .word 0
size_digit: .byte 0
size_digit_index: .byte 0
size_started: .byte 0
decimal_lo: .byte <10000,<1000,<100,<10,<1
decimal_hi: .byte >10000,>1000,>100,>10,>1
size_blank: .text "        "
.byte 0
size_large: .text ">=65535K"
.byte 0
