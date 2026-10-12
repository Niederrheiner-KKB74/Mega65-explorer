// Stage 1b: left=bounded FAT32 snapshot, right=unchanged mock directory.
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
    lda #0
    sta entry_counts
    sta vfs_status
    sta vfs_error
    jsr fat32_init
    jsr fat32_open_root
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
