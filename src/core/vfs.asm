// Stage 1a read-only mock VFS. No open/read/write device operations.
// Record: type byte, flags byte, size LE16 (KiB; 0=unknown), name[20].
.const LEFT_COUNT = 24
.const RIGHT_COUNT = 18
.const ENTRY_SIZE = 24
.const TYPE_FILE = 0
.const TYPE_DIR = 1
.const FLAG_READONLY = 1
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
    rts
// Y=record offset (0..23), returns A, preserves X/Y.
vfs_read:
    lda $ffff,y
    rts
vfs_index: .byte 0
entry_counts: .byte LEFT_COUNT, RIGHT_COUNT
directory_lo: .byte <mock_left, <mock_right
directory_hi: .byte >mock_left, >mock_right
