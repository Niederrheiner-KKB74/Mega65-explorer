// Hardware-independent state: panel X=0/1; byte indices (max 255 entries).
// Routines clobber A/X/flags, preserve Y. Up/down clamp, never wrap.
navigation_init:
    lda #0
    sta active_panel
    sta selected
    sta selected+1
    sta scroll
    sta scroll+1
    rts
navigation_tab:
    lda active_panel
    eor #1
    sta active_panel
    rts
navigation_up:
    ldx active_panel
    lda entry_counts,x
    beq navigation_done
    lda selected,x
    beq navigation_done
    dec selected,x
    jmp navigation_visible
navigation_down:
    ldx active_panel
    lda entry_counts,x
    beq navigation_done
    lda selected,x
    clc
    adc #1
    cmp entry_counts,x
    bcs navigation_done
    sta selected,x
navigation_visible:
    lda selected,x
    cmp scroll,x
    bcs navigation_bottom
    sta scroll,x
    rts
navigation_bottom:
    sec
    sbc scroll,x
    cmp #VISIBLE
    bcc navigation_done
    lda selected,x
    sec
    sbc #VISIBLE-1
    sta scroll,x
navigation_done:
    rts
active_panel: .byte 0
selected: .byte 0,0
scroll: .byte 0,0

// New directory keys only act on the FAT32 panel. GETIN repeat stays unchanged.
// Return A=0 no action, 1 redraw (also on a controlled navigation error).
navigation_enter:
    lda active_panel
    bne navigation_no_action
    jmp vfs_enter
navigation_parent:
    lda active_panel
    bne navigation_no_action
    jmp vfs_parent
navigation_no_action:
    lda #0
    rts
