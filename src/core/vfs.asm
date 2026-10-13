// Stage 1c: left=bounded FAT32 snapshot, right=unchanged mock directory.
// Record: type byte, flags byte, size LE16 (KiB; 0=unknown), name[20].
.const MAX_ENTRIES = 128
.const RIGHT_COUNT = 18
.const ENTRY_SIZE = 24
.const TYPE_FILE = 0
.const TYPE_DIR = 1
.const FLAG_READONLY = 1
.const FLAG_SIZE_KNOWN = $40
.const FLAG_SIZE_SATURATED = $80
// X=panel, A=index. Returns vfs_read operand pointing to record.
// Clobbers A/Y/flags, preserves X. Valid index required; caller checks count.
vfs_entry:
    sta vfs_index
    lda directory_lo,x
    sta vfs_read+1
    lda directory_hi,x
    sta vfs_read+2
    ldy vfs_index
    beq vfs_ready
vfs_advance:
    clc
    lda vfs_read+1
    adc #ENTRY_SIZE
    sta vfs_read+1
    bcc vfs_no_carry
    inc vfs_read+2
vfs_no_carry:
    dey
    bne vfs_advance
vfs_ready:
    lda vfs_read+1
    sta vfs_store+1
    lda vfs_read+2
    sta vfs_store+2
    rts
// Y=record offset (0..23), returns A, preserves X/Y.
vfs_read:
    lda $ffff,y
    rts
vfs_index: .byte 0
entry_counts: .byte 0, RIGHT_COUNT
directory_lo: .byte <vfs_buffer, <mock_right
directory_hi: .byte >vfs_buffer, >mock_right

// Initialize/cache left directory before GUI. No false mock fallback on failure.
// Status: 0=OK, 1=empty, 2=truncated, 3=error (may retain partial listing).
vfs_init:
    jsr vfs_reset_path
    lda #0
    sta vfs_cache_slot
    sta vfs_context_valid
    lda #<vfs_buffer
    sta directory_lo
    lda #>vfs_buffer
    sta directory_hi
    lda #0
    sta entry_counts
    sta vfs_status
    sta vfs_error
    jsr fat32_init
    jsr fat32_open_root
    bcc vfs_load_error
    lda #1
    sta vfs_context_valid
    jmp vfs_load_next
// Reuse Stage 1b enumeration for an already selected directory.
vfs_read_directory:
    lda #0
    sta entry_counts
    sta vfs_status
    sta vfs_error
    sta fat32_error
    jsr fat32_open_directory
    bcc vfs_load_error
vfs_load_next:
    jsr fat32_read_next
    cmp #3
    beq vfs_load_next
    cmp #1
    beq vfs_load_end
    cmp #2
    beq vfs_load_error
    lda entry_counts
    cmp #MAX_ENTRIES
    bcs vfs_load_truncated
    ldx #0
    jsr vfs_entry
    ldy #0
vfs_copy_record:
    lda fat32_record,y
    jsr vfs_store
    iny
    cpy #ENTRY_SIZE
    bne vfs_copy_record
    inc entry_counts
    jmp vfs_load_next
vfs_load_truncated:
    lda #2
    sta vfs_status
    jmp vfs_load_close
vfs_load_end:
    lda entry_counts
    bne vfs_load_close
    lda #1
    sta vfs_status
    jmp vfs_load_close
vfs_load_error:
    lda #3
    sta vfs_status
vfs_load_close:
    jsr fat32_close
    bcs vfs_error_copy
    lda #3
    sta vfs_status
vfs_error_copy:
    lda fat32_error
    sta vfs_error
    rts
// Called on X; idempotent, retries a failed initial close once.
vfs_close:
    jmp fat32_close
// Private write operand selected by vfs_entry. Guarded by MAX_ENTRIES check.
vfs_store:
    sta $ffff,y
    rts
vfs_status: .byte 0
vfs_error: .byte 0

// Central committed path and bounded history. A candidate exists only during
// a transaction. 8.3 components <=12; root '/' counts toward MAX_PATH=96.
.const MAX_DEPTH = 8
.const MAX_PATH = 96
vfs_reset_path:
    lda #$2f
    sta vfs_path
    lda #0
    sta vfs_path+1
    sta vfs_depth
    lda #1
    sta vfs_path_length
    rts
vfs_copy_candidate:
    ldx #0
vfs_copy_candidate_loop:
    lda vfs_path,x
    sta vfs_candidate,x
    inx
    cmp #0
    bne vfs_copy_candidate_loop
    rts
vfs_commit_path:
    ldx #0
vfs_commit_path_loop:
    lda vfs_candidate,x
    sta vfs_path,x
    inx
    cmp #0
    bne vfs_commit_path_loop
    lda vfs_new_length
    sta vfs_path_length
    rts
vfs_enter:
    lda vfs_context_valid
    beq vfs_enter_idle
    lda selected
    cmp entry_counts
    bcs vfs_enter_idle
    ldx #0
    jsr vfs_entry
    ldy #0
    jsr vfs_read
    cmp #TYPE_DIR
    bne vfs_enter_idle
    lda vfs_depth
    cmp #MAX_DEPTH
    bcc vfs_enter_name
    lda #4
    jmp vfs_limit
vfs_enter_idle:
    lda #0
    rts
vfs_enter_name:
    lda #20
    sta vfs_name_length
vfs_trim_name:
    lda vfs_name_length
    clc
    adc #3
    tay
    jsr vfs_read
    cmp #$20
    bne vfs_name_trimmed
    dec vfs_name_length
    bne vfs_trim_name
    jmp vfs_bad_name
vfs_name_trimmed:
    lda vfs_name_length
    cmp #13
    bcs vfs_bad_name
    clc
    adc vfs_path_length
    ldx vfs_depth
    beq vfs_enter_length
    adc #1
vfs_enter_length:
    cmp #MAX_PATH+1
    bcc vfs_enter_prepare
    lda #5
    jmp vfs_limit
vfs_enter_prepare:
    sta vfs_new_length
    jsr vfs_copy_candidate
    ldx vfs_path_length
    lda vfs_depth
    beq vfs_append_name_start
    lda #$2f
    sta vfs_candidate,x
    inx
vfs_append_name_start:
    ldy #4
vfs_append_name:
    jsr vfs_read
    cmp #$3f                 // lossy Stage 1b alias is not safe to navigate
    beq vfs_bad_name
    cmp #$2f
    beq vfs_bad_name
    sta vfs_candidate,x
    inx
    iny
    tya
    sec
    sbc #4
    cmp vfs_name_length
    bne vfs_append_name
    lda #0
    sta vfs_candidate,x
    jsr vfs_transition
    bcc vfs_enter_redraw
    ldx vfs_depth
    lda selected
    sta vfs_history_selected,x
    lda scroll
    sta vfs_history_scroll,x
    lda vfs_path_length
    sta vfs_history_length,x
    inc vfs_depth
    jsr vfs_commit_path
    lda #0
    sta selected
    sta scroll
vfs_enter_redraw:
    lda #1
    rts
vfs_bad_name:
    lda #6
vfs_limit:
    sta vfs_status
    lda #1
    rts
vfs_parent:
    lda vfs_context_valid
    bne vfs_parent_context
    jmp vfs_enter_idle
vfs_parent_context:
    ldx vfs_depth
    bne vfs_parent_prepare
    jmp vfs_enter_idle
vfs_parent_prepare:
    dex
    lda vfs_history_length,x
    sta vfs_new_length
    jsr vfs_copy_candidate
    ldx vfs_new_length
    lda #0
    sta vfs_candidate,x
    jsr vfs_transition
    bcc vfs_enter_redraw
    dec vfs_depth
    jsr vfs_commit_path
    ldx vfs_depth
    lda vfs_history_selected,x
    sta selected
    lda vfs_history_scroll,x
    sta scroll
    lda entry_counts
    beq vfs_parent_empty
    lda selected
    cmp entry_counts
    bcc vfs_parent_visible
    lda entry_counts
    sec
    sbc #1
    sta selected
vfs_parent_visible:
    ldx #0
    jsr navigation_visible
    jmp vfs_enter_redraw
vfs_parent_empty:
    lda #0
    sta selected
    sta scroll
    jmp vfs_enter_redraw

// Resolve an absolute VFS alias path from root, one safe component at a time.
// A/Y=path pointer. Registers/flags clobbered; C=1 resolved, C=0 error.
// Replaying a prefix replaces dependence on FAT '..' entries and getcwd.
vfs_walk_path:
    sta vfs_walk_read+1
    sty vfs_walk_read+2
    jsr fat32_close
    bcc vfs_walk_return
    lda #0
    sta fat32_error
    jsr fat32_select_root
    bcc vfs_walk_return
    lda #1
    sta vfs_walk_index
vfs_walk_next:
    ldx vfs_walk_index
    jsr vfs_walk_read
    beq vfs_walk_complete
    ldx #19
    lda #$20
vfs_walk_clear:
    sta fat32_component,x
    dex
    bpl vfs_walk_clear
    lda #0
    sta vfs_component_index
vfs_walk_component:
    ldx vfs_walk_index
    jsr vfs_walk_read
    beq vfs_walk_component_end
    cmp #$2f
    beq vfs_walk_separator
    ldx vfs_component_index
    cpx #12
    bcs vfs_walk_bad
    sta fat32_component,x
    inc vfs_component_index
    inc vfs_walk_index
    jmp vfs_walk_component
vfs_walk_separator:
    inc vfs_walk_index
vfs_walk_component_end:
    lda vfs_component_index
    beq vfs_walk_bad
    jsr fat32_change_directory
    bcc vfs_walk_return
    jmp vfs_walk_next
vfs_walk_bad:
    lda #$81
    sta fat32_error
    clc
vfs_walk_return:
    rts
vfs_walk_complete:
    sec
    rts
vfs_walk_read:
    lda $ffff,x
    rts

// Stage in the inactive cache. Commit pointer/count only on complete reading
// (explicit truncation is successful); never overwrite the current snapshot.
vfs_try_snapshot:
    lda entry_counts
    sta vfs_old_count
    lda directory_lo
    sta vfs_old_lo
    lda directory_hi
    sta vfs_old_hi
    lda vfs_cache_slot
    eor #1
    tax
    lda vfs_cache_lo,x
    sta directory_lo
    lda vfs_cache_hi,x
    sta directory_hi
    jsr vfs_read_directory
    lda vfs_status
    cmp #3
    beq vfs_snapshot_failed
    lda vfs_cache_slot
    eor #1
    sta vfs_cache_slot
    sec
    rts
vfs_snapshot_failed:
    lda vfs_old_count
    sta entry_counts
    lda vfs_old_lo
    sta directory_lo
    lda vfs_old_hi
    sta directory_hi
    clc
    rts

// Transaction: cwd candidate -> staged list -> commit. Failure: replay original
// cwd, keeping the old snapshot/path/history. If restoration fails, reset root;
// if even root is unavailable, disable SD navigation in an explicit offline state.
vfs_transition:
    lda #<vfs_candidate
    ldy #>vfs_candidate
    jsr vfs_walk_path
    bcc vfs_transition_walk_failed
    jsr vfs_try_snapshot
    bcc vfs_transition_read_failed
    sec
    rts
vfs_transition_walk_failed:
    lda fat32_error
    sta vfs_error
vfs_transition_read_failed:
    lda vfs_error
    sta vfs_first_error
    lda #<vfs_path
    ldy #>vfs_path
    jsr vfs_walk_path
    bcc vfs_recover_root
    lda #3
    sta vfs_status
    lda vfs_first_error
    sta vfs_error
    clc
    rts
vfs_recover_root:
    jsr fat32_close
    bcc vfs_context_lost
    lda #0
    sta fat32_error
    jsr fat32_select_root
    bcc vfs_context_lost
    jsr vfs_reset_path
    lda #0
    sta selected
    sta scroll
    jsr vfs_try_snapshot
    bcs vfs_root_recovered
    lda #0                 // no stale non-root records under the root title
    sta entry_counts
vfs_root_recovered:
    lda #3
    sta vfs_status
    lda vfs_first_error
    sta vfs_error
    clc
    rts
vfs_context_lost:
    jsr vfs_reset_path
    lda #$3f
    sta vfs_path
    lda #0
    sta vfs_context_valid
    sta selected
    sta scroll
    sta entry_counts
    lda #7
    sta vfs_status
    lda vfs_first_error
    sta vfs_error
    clc
    rts
vfs_depth: .byte 0
vfs_path_length: .byte 1
vfs_path: .byte $2f,0
.fill MAX_PATH-1,0
vfs_path_end:
vfs_candidate: .fill MAX_PATH+1,0
vfs_candidate_end:
vfs_history_length: .fill MAX_DEPTH,0
vfs_history_selected: .fill MAX_DEPTH,0
vfs_history_scroll: .fill MAX_DEPTH,0
vfs_history_end:
vfs_new_length: .byte 0
vfs_name_length: .byte 0
vfs_walk_index: .byte 0
vfs_component_index: .byte 0
vfs_context_valid: .byte 0
vfs_cache_slot: .byte 0
vfs_old_count: .byte 0
vfs_old_lo: .byte 0
vfs_old_hi: .byte 0
vfs_first_error: .byte 0
vfs_cache_lo: .byte <vfs_buffer,<vfs_staging
vfs_cache_hi: .byte >vfs_buffer,>vfs_staging

.assert "Committed path capacity", MAX_PATH+1, vfs_path_end-vfs_path
.assert "Candidate path capacity", MAX_PATH+1, vfs_candidate_end-vfs_candidate
.assert "History capacity", MAX_DEPTH*3, vfs_history_end-vfs_history_length
