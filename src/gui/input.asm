// ROM GETIN: PETSCII cursor codes, real TAB, either case of X.
// A=0 no action, 1 redraw, 2 exit. Clobbers X/Y/flags.
input_poll:
    jsr GETIN
    cmp #$91
    beq input_up
    cmp #$11
    beq input_down
    cmp #$0d
    beq input_enter
    cmp #$14
    beq input_parent
    cmp #9
    beq input_tab
    cmp #'X'
    beq input_exit
    cmp #$78
    beq input_exit
    lda #0
    rts
input_up:
    jsr navigation_up
    jmp input_changed
input_down:
    jsr navigation_down
    jmp input_changed
input_tab:
    jsr navigation_tab
input_changed:
    lda #1
    rts
input_exit:
    lda #2
    rts

input_enter:
    jmp navigation_enter
input_parent:
    jmp navigation_parent
