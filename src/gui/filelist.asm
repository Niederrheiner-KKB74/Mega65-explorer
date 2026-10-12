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
    lda #11
    bne filelist_spaces
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
