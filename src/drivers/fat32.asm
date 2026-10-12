// Read-only HDOS directory backend. GPL-3.0; see LICENSE.
// ABI verified against MEGA65 core release-0.97.2 and User Guide.
// All calls clobber A/X/Y/flags. Native BASIC 65 mappings/I/O required.
// No application MAP/zero-page use. No global closeall, no write traps.
.const HDOS = $d640
.const HDOS_SHORT = $41
.const HDOS_SIZE = $52
.const HDOS_ATTR = $56
// Initialize state; must only be called when no owned handle is open.
fat32_init:
    lda #$ff
    sta fat32_handle
    lda #0
    sta fat32_error
    rts
// C=1 opened, C=0 error (fat32_error=A). Select default SD partition/root.
fat32_open_root:
    lda #$02                 // getdefaultdrive, A=HDOS partition (not unit 8)
    sta HDOS
    clv
    bcc fat32_fail
    tax
    lda #$3c                 // cdrootdir, X=partition
    sta HDOS
    clv
    bcc fat32_fail
    lda #$12                 // opendir, A=descriptor
    sta HDOS
    clv
    bcc fat32_fail
    sta fat32_handle
    sec
    rts
fat32_fail:
    sta fat32_error
    clc
    rts
// A=0 record ready in fat32_record, 1=end, 2=error, 3=filtered record.
// Errors are saved before any cleanup; $85 and $FF are documented EOF variants.
fat32_read_next:
    ldx fat32_handle
    ldy #>fat32_transfer
    lda #$14
    sta HDOS
    clv
    bcs fat32_convert
    cmp #$ff
    beq fat32_end
    cmp #$85
    beq fat32_end
    sta fat32_error
    lda #2
    rts
fat32_end:
    lda #1
    rts
fat32_convert:
    lda fat32_transfer+HDOS_ATTR
    and #$08                 // Volume labels (includes raw LFN attribute $0f)
    beq fat32_check_1
    jmp fat32_skip
fat32_check_1:
    lda fat32_transfer+HDOS_SHORT
    bne fat32_check_2
    jmp fat32_skip
fat32_check_2:
    cmp #$e5                 // deleted alias / unsupported extended character
    bne fat32_check_3
    jmp fat32_skip
fat32_check_3:
    cmp #$2e                 // . and ..; root only
    bne fat32_check_4
    jmp fat32_skip
fat32_check_4:
    cmp #$20
    bne fat32_check_5
    jmp fat32_skip
fat32_check_5:
    lda #0
    sta fat32_record
    sta fat32_record+2
    sta fat32_record+3
    lda fat32_transfer+HDOS_ATTR
    and #$3f                 // preserve all defined FAT attribute bits
    sta fat32_record+1
    and #$10
    beq fat32_file_size
    lda #TYPE_DIR
    sta fat32_record
    jmp fat32_name
fat32_file_size:
    lda fat32_record+1
    ora #FLAG_SIZE_KNOWN
    sta fat32_record+1
    ldx #3
fat32_size_copy:
    lda fat32_transfer+HDOS_SIZE,x
    sta fat32_size,x
    dex
    bpl fat32_size_copy
    ldx #10                  // floor(bytes/1024), then saturate at 65535 KiB
fat32_size_shift:
    lsr fat32_size+3
    ror fat32_size+2
    ror fat32_size+1
    ror fat32_size
    dex
    bne fat32_size_shift
    lda fat32_size+2
    ora fat32_size+3
    beq fat32_size_fits
    lda #$ff
    sta fat32_record+2
    sta fat32_record+3
    lda fat32_record+1
    ora #FLAG_SIZE_SATURATED
    sta fat32_record+1
    jmp fat32_name
fat32_size_fits:
    lda fat32_size
    sta fat32_record+2
    lda fat32_size+1
    sta fat32_record+3
fat32_name:
    ldx #19
    lda #$20
fat32_name_clear:
    sta fat32_record+4,x
    dex
    bpl fat32_name_clear
    // Copy trimmed 8+3 alias, insert period only when extension exists.
    lda #8
    sta fat32_base_length
fat32_trim_base:
    ldx fat32_base_length
    dex
    lda fat32_transfer+HDOS_SHORT,x
    cmp #$20
    bne fat32_copy_base_start
    dec fat32_base_length
    bne fat32_trim_base
    jmp fat32_skip
fat32_copy_base_start:
    ldx #0
    ldy #0
fat32_copy_base:
    lda fat32_transfer+HDOS_SHORT,x
    jsr fat32_printable
    sta fat32_record+4,y
    iny
    inx
    cpx fat32_base_length
    bne fat32_copy_base
    lda #3
    sta fat32_extension_length
fat32_trim_extension:
    ldx fat32_extension_length
    dex
    lda fat32_transfer+HDOS_SHORT+8,x
    cmp #$20
    bne fat32_copy_extension_start
    dec fat32_extension_length
    bne fat32_trim_extension
    jmp fat32_ready
fat32_copy_extension_start:
    lda #$2e
    sta fat32_record+4,y
    iny
    ldx #0
fat32_copy_extension:
    lda fat32_transfer+HDOS_SHORT+8,x
    jsr fat32_printable
    sta fat32_record+4,y
    iny
    inx
    cpx fat32_extension_length
    bne fat32_copy_extension
fat32_ready:
    lda #0
    rts
fat32_skip:
    lda #3
    rts
// ASCII to safe uppercase PETSCII: never emit control codes from disk data.
// Preserves X/Y; unsupported glyphs become '?'. No Unicode/LFN conversion.
fat32_printable:
    cmp #$61
    bcc fat32_ascii_range
    cmp #$7b
    bcs fat32_ascii_range
    sec
    sbc #$20
fat32_ascii_range:
    cmp #$20
    bcc fat32_ascii_bad
    cmp #$5c                 // backslash and higher have different PETSCII glyphs
    bcs fat32_ascii_bad
    rts
fat32_ascii_bad:
    lda #$3f
    rts
// Close only our handle. C=1 closed/already closed, C=0 failed.
// Preserve first error. Failed close retains handle for one retry on X.
fat32_close:
    ldx fat32_handle
    cpx #$ff
    beq fat32_closed
    lda #$16
    sta HDOS
    clv
    bcs fat32_close_success
    pha
    lda fat32_error
    bne fat32_close_keep_error
    pla
    sta fat32_error
    clc
    rts
fat32_close_keep_error:
    pla
    clc
    rts
fat32_close_success:
    lda #$ff
    sta fat32_handle
fat32_closed:
    sec
    rts
fat32_handle: .byte $ff
fat32_error: .byte 0
fat32_base_length: .byte 0
fat32_extension_length: .byte 0
fat32_size: .fill 4,0
fat32_record: .fill ENTRY_SIZE,0
