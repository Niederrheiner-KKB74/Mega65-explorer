# Stage 1b architecture

The stable Stage 1a reference is commit d4bf66207e900b756f96f67a12cf4e9f58da19ff;
its source is unchanged on the Stage 1a branch. The project owner confirmed both
XEMU and hardware testing. Future regular release testing requires XEMU only.

## Data flow and module interfaces

`HDOS → drivers/fat32.asm → core/vfs.asm → bounded records → gui/filelist.asm`.
The GUI never issues Hypervisor calls. Enumeration completes synchronously before
initial GUI rendering. No parallel list manager or dynamic allocation was added.

| Module | Responsibility |
| --- | --- |
| main.asm | Existing BASIC launcher and event loop; call VFS init/exit |
| gui/screen.asm | Unchanged ROM display initialization, drawing and BASIC exit |
| gui/panels.asm | Existing layout plus SD root title, version and VFS status |
| gui/filelist.asm | Existing rows/highlight/scroll rendering plus left size column |
| gui/input.asm | Unchanged GETIN dispatch for Up/Down/TAB/X |
| core/navigation.asm | Existing state/scroll logic; guard zero-entry panels |
| core/vfs.asm | Left FAT32 snapshot, right mock, counts and status/error |
| drivers/fat32.asm | Only place that issues HDOS traps; normalize one record |
| data/mockfiles.asm | Unchanged Stage 1a data, right directory still used |
| drivers/dos.asm, drivers/iec.asm | Unchanged inert placeholders |

Unless documented otherwise A/X/Y/arithmetic flags are clobbered, the stack is
balanced and calls are synchronous/non-reentrant. No application zero page,
custom IRQ, MAP changes, raw SD registers or writes are used. The ROM retains
ownership of the screen and keyboard. Existing writable instruction operands
provide record and string pointers without borrowing KERNAL zero page.

- `fat32_init`: reset state, only when no owned handle is open.
- `fat32_open_root`: select default HDOS partition/root, open; C=1 success,
  C=0 failure; error in `fat32_error`.
- `fat32_read_next`: A=0 record in `fat32_record`, 1=end, 2=error, 3=filtered.
- `fat32_close`: close only owned handle, idempotent; C=1 success, C=0 failure.
  Save the first error; retain failed handle for one further attempt on X.
- `vfs_init`: enumerate left snapshot, always attempt cleanup, publish count,
  `vfs_status` (0=OK, 1=empty, 2=truncated, 3=access/cleanup error) and `vfs_error`.
  Open failure yields zero entries; read failure can retain a partial list.
- `vfs_entry`: X=panel, A=valid index; select record operand. Preserves X,
  destroys A/Y/flags. Caller checks count first. VFS's private write operand
  is selected here too, and used only after its capacity check.
- `vfs_read`: Y=offset, A=byte; preserves X/Y.
- `vfs_close`: retry any still-owned handle on application exit.
- Navigation preserves Y, clobbers A/X/flags. Empty panels retain index/offset 0.
  Nonempty panels satisfy scroll <= selected < scroll+16. TAB only toggles panel.
- `screen_at`: X=row/Y=column; `screen_text`: A/Y=low/high NUL PETSCII pointer.

## Hypervisor ABI audit

Official sources consulted:

- [User Guide HDOS reference and examples](https://github.com/MEGA65/mega65-user-guide/blob/master/appendix-hypervisor-calls.tex).
- [Released core HDOS implementation](https://github.com/MEGA65/mega65-core/blob/release-0.97.2/src/hyppo/dos.asm).
- [Released core directory structure and return/copy implementation](https://github.com/MEGA65/mega65-core/blob/release-0.97.2/src/hyppo/main.asm).
- [mega65-libc directory wrapper](https://github.com/MEGA65/mega65-libc/blob/master/src/cc65/dirent.s), consulted but not copied.

Every call is `LDA #service : STA $D640 : CLV`. The trap is a CPU Hypervisor
transition, not JSR. Execution resumes after STA; CLV must be harmless because
some core versions skip that byte. C=1 success; C=0 error in A. Registers other
than documented outputs are preserved by HDOS. The wrappers conservatively
advertise A/X/Y/flags as clobbered. No version query that alters Z is needed.

| Service | A input | Other input | Output / side effects |
| --- | --- | --- | --- |
| getdefaultdrive | $02 | — | A=boot-selected HDOS partition |
| cdrootdir | $3C | X=partition | Select partition and change HDOS cwd to root |
| opendir | $12 | — | A=owned directory descriptor |
| readdir | $14 | X=descriptor, Y=transfer page | 87 bytes into mapped user RAM |
| closedir | $16 | X=descriptor | Release only that descriptor |

No closeall, setname, loadfile, writefile, delete, rename, mount or raw-sector
service is called. cdrootdir changes in-memory HDOS state only. The program does
not restore the old HDOS directory because getcwd is documented unimplemented.
Native BASIC 65 mappings and enhanced I/O are prerequisites; GO64/custom MAP
startup is not supported. No additional setup-transfer-area call is required:
readdir takes its page in Y each time and initializes the copy region itself.

Errors include $80 no drive, $84 descriptors exhausted, $87 not a directory,
$89 invalid descriptor, $07 timeout, $08 partition error, $10 bad transfer address
and $20 read error. The guide's example uses $85 for directory end; the released
implementation returns $FF EOF. Both are accepted on readdir only. $FF on root
selection/open is reported as an access error (including unsupported service).
The $85 EOF convention cannot distinguish a corrupt cluster reported with that
same code; test with a known-good filesystem. Service availability is checked by
its result, not by a guessed version threshold: released core constants still
report Hyppo 1.2 despite the guide describing cdrootdir as added in 1.16.

## Dirent format, names and attributes

The audited release-0.95, release-0.96.0 and release-0.97.2 structure matches the
87-byte layout documented in the guide:

| Offset | Data |
| --- | --- |
| $00–$3F | HDOS long-name storage, up to 64 bytes |
| $40 | Long-name length |
| $41–$4B | Raw 8+3 alias, space padded; no separator |
| $4C–$4D | Reserved short-name storage; not read |
| $4E–$51 | First cluster, LE32; not used |
| $52–$55 | File length in bytes, LE32 |
| $56 | FAT attributes |

Some libc wrappers assume size at $51 and attributes at $55; their cluster-copy
code also has an inconsistent address. These were not used. Offsets $52/$56 are
confirmed by counting the actual reserved bytes in released `main.asm` and by
`trap_dos_readdir` copying that entire structure. Older/different ABIs are not
silently guessed; use the documented released format for the initial test.

Stage 1b intentionally displays only the 8.3 alias: trim spaces, insert a dot
when an extension exists, uppercase ASCII a–z. Unsupported extended glyphs and
controls become '?'. Dot entries, volume labels/raw LFN entries, empty/deleted
aliases are filtered. Hidden/system entries are shown. Attributes 0–5 are
preserved: read-only, hidden, system, volume, directory, archive. The directory
bit determines the existing [DIR] marker. No new permission operations exist.

The original VFS record remains 24 bytes: type byte (0=file, 1=directory), flags
byte, size LE16 KiB, 20-byte padded PETSCII name. The FAT bits occupy flags 0–5;
bit 6 marks known file size, bit 7 marks saturation. Sizes are floor(bytes/1024),
saturated at 65535; files under 1 KiB and zero-byte files show 0K. Directories
have no displayed size. The right mock rendering remains unchanged.

LFN display/Unicode are not implemented. HDOS only retains the low UTF-16 byte,
and may skip entries with long names exceeding its ~63-character limit before
returning even their alias. The explorer cannot recover omitted entries through
this API. The name buffer cannot overflow: an alias is at most 12 display bytes.

## Memory and bounds

The PRG owns all its code/data and reserved buffers in bank 0. No ROM, screen,
Hypervisor-private memory or unrelated BASIC zero page is used as scratch.

| Area in validated build | Address | Bytes |
| --- | --- | --- |
| BASIC launcher, code, globals, mocks, alignment padding | $2001–$2BFF | 3071 |
| HDOS transfer page | $2C00–$2CFF | 256 |
| VFS snapshot, 128 × 24 | $2D00–$38FF | 3072 |

The loaded memory span is 6399 bytes; the PRG adds a two-byte load address.
The driver also has a 24-byte normalized record and four-byte size scratch inside
the code/data area. The Hypervisor's 87-byte transfer fits inside its private
256-byte page. Assembler assertions enforce alignment, legal transfer address
<= $7E00 and total buffer end <= $8000. Addresses are symbol-derived, not fixed
runtime scratch addresses; the assertions protect subsequent changes.

Every cache write checks count < 128 first. At 128 entries a further *displayable*
record produces a truncation notice; EOF immediately after entry 128 does not.
Filtered records do not consume capacity. Count never wraps; selection is byte
based and the maximum selection is 127. All file rows check count before reads.
Binary tests use canaries immediately after the buffer and exercise 127/128/129
and 200 entries. No second list implementation or unbounded allocation exists.

## Validation and limits

Assembly passed; three memory assertions passed. Nine py65 binary-logic tests
passed with simulated HDOS/KERNAL results, including CLV executed/skipped,
cleanup/error priority, EOF, empty state, bounded caching, names, sizes and
navigation/event-loop handling. They execute the real PRG's 6502-subset code but
are not tests of MEGA65 memory mapping, ROM, Hypervisor or SD behavior.

Stage 1b has not been executed in XEMU in this environment, and has no
project-owner runtime confirmation yet. Final Stage 1b Stable approval remains
pending the [manual XEMU checklist](xemu-stage1b.md). No hardware test is required.
Enumeration blocks initial GUI drawing; a slow SD card can delay startup.
There is no refresh, sorting, directory descent, retry key, file operation or
mouse support. X retries cleanup then uses the unchanged Stage 1a standard BASIC
screen exit. If the Hypervisor itself persistently refuses closedir, the error is
reported, but the program cannot guarantee that the handle was released.
