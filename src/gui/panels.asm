// Fixed layout: header 0..2, titles 3, separator 4, entries 5..20,
// separator 21, shortcuts 22, status 23. Row 24 is left blank.
panels_draw:
    ldx #0
    jsr screen_line
    ldx #1
    ldy #2
    jsr screen_at
    lda #<header
    ldy #>header
    jsr screen_text
    ldx #2
    jsr screen_line
    ldx #4
    jsr screen_line
    ldx #21
    jsr screen_line
    ldx #22
    ldy #2
    jsr screen_at
    lda #<shortcuts
    ldy #>shortcuts
    jsr screen_text
    ldx #23
    ldy #2
    jsr screen_at
    jsr panels_status
    lda #3
    sta border_row
panels_border:
    ldx border_row
    ldy #0
    jsr screen_at
    lda #'!'
    jsr CHROUT
    ldx border_row
    ldy #39
    jsr screen_at
    lda #'!'
    jsr CHROUT
    ldx border_row
    ldy #78
    jsr screen_at
    lda #'!'
    jsr CHROUT
    inc border_row
    lda border_row
    cmp #21
    bne panels_border
panels_refresh:
    jsr panels_build_title
    lda #0
    sta render_panel
panels_each:
    lda #146
    jsr CHROUT
    lda #159
    jsr CHROUT
    lda render_panel
    cmp active_panel
    bne panels_title
    lda #5
    jsr CHROUT
    lda #18
    jsr CHROUT
panels_title:
    ldx #3
    ldy #2
    lda render_panel
    beq panels_title_at
    ldy #41
panels_title_at:
    jsr screen_at
    ldx render_panel
    lda title_lo,x
    ldy title_hi,x
    jsr screen_text
    lda #146
    jsr CHROUT
    jsr filelist_draw
    inc render_panel
    lda render_panel
    cmp #2
    bne panels_each
    jmp panels_status_at
render_panel: .byte 0
border_row: .byte 0
title_lo: .byte <left_title,<right_title
title_hi: .byte >left_title,>right_title
header: .text "MEGA65 EXPLORER                                                   V0.1C"
.byte 0
left_title: .text "SD: /                                "
.byte 0
right_title: .text "D81: UNIT 8                          "
.byte 0
shortcuts: .text "TAB PANEL  UP/DOWN SELECT  RETURN OPEN  BACKSPACE PARENT  X EXIT"
.byte 0
// Status text consumes only row 23; no HDOS calls in the GUI.
panels_status:
    ldx vfs_status
    lda status_lo,x
    ldy status_hi,x
    jsr screen_text
    lda vfs_status
    cmp #3
    bne panels_status_done
    lda vfs_error
    lsr
    lsr
    lsr
    lsr
    tax
    lda hex_digits,x
    jsr CHROUT
    lda vfs_error
    and #$0f
    tax
    lda hex_digits,x
    jsr CHROUT
panels_status_done:
    rts
status_lo: .byte <status_ok,<status_empty,<status_truncated,<status_error
.byte <status_depth,<status_path,<status_name,<status_offline
status_hi: .byte >status_ok,>status_empty,>status_truncated,>status_error
.byte >status_depth,>status_path,>status_name,>status_offline
status_ok: .text "SD DIR: READ ONLY | 8.3 NAMES | SIZES: KIB FLOOR | RIGHT: MOCK"
.byte 0
status_empty: .text "SD DIR: EMPTY (NO DISPLAYABLE ENTRIES) | RIGHT: MOCK | X EXIT"
.byte 0
status_truncated: .text "SD DIR: LIST TRUNCATED TO 128 ENTRIES | READ ONLY | RIGHT: MOCK"
.byte 0
status_error: .text "SD ACCESS ERROR (LIST MAY BE INCOMPLETE) | X EXIT | HDOS $"
.byte 0
hex_digits: .text "0123456789ABCDEF"

status_depth: .text "SD: MAXIMUM DIRECTORY DEPTH (8) REACHED | BACKSPACE PARENT"
.byte 0
status_path: .text "SD: PATH EXCEEDS 96 CHARACTERS | BACKSPACE PARENT"
.byte 0
status_name: .text "SD: UNSUPPORTED DIRECTORY ALIAS | SELECT AN ASCII 8.3 DIRECTORY"
.byte 0
status_offline: .text "SD CONTEXT UNAVAILABLE: NAVIGATION DISABLED | X EXIT"
.byte 0
// Clear the status row so shorter subsequent messages leave no artifacts.
panels_status_at:
    lda #146
    jsr CHROUT
    lda #159
    jsr CHROUT
    ldx #23
    ldy #2
    jsr screen_at
    lda #76
    sta status_spaces
panels_status_clear:
    lda #$20
    jsr CHROUT
    dec status_spaces
    bne panels_status_clear
    ldx #23
    ldy #2
    jsr screen_at
    jmp panels_status
status_spaces: .byte 0
// Only a render buffer is duplicated, never the authoritative VFS path.
// 33 chars available after 'SD: '; long paths show '...' plus final 30 chars.
panels_build_title:
    ldx #32
    lda #$20
panels_title_clear:
    sta left_title+4,x
    dex
    bpl panels_title_clear
    ldy #4
    ldx #0
    lda vfs_path_length
    cmp #34
    bcc panels_path_copy
    lda #$2e
    sta left_title+4
    sta left_title+5
    sta left_title+6
    ldy #7
    lda vfs_path_length
    sec
    sbc #30
    tax
panels_path_copy:
    lda vfs_path,x
    beq panels_path_done
    sta left_title,y
    inx
    iny
    jmp panels_path_copy
panels_path_done:
    rts
