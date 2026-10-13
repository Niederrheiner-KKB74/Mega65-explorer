# Stage 1c architecture

Stage 1c uses only the Stage 1b Stable merge commit
7a837f9c768234caeba5261fe0fec7bd5436617f as its development base. Its tree includes
owner-confirmed Stage 1b acceptance. It was merged into feature/stage-1a-gui,
while main currently contains Stage 1a. The stable commit is preserved; all new
source changes are isolated on feature/stage-1c-navigation. XEMU is the regular
release test platform; hardware testing is optional.

## Data flow and module interfaces

`HDOS → drivers/fat32.asm → core/vfs.asm → bounded records → gui/filelist.asm`.
The GUI never issues Hypervisor calls. Enumeration completes synchronously before
initial GUI rendering and during directory transitions. No parallel list manager or dynamic allocation was added.

| Module | Responsibility |
| --- | --- |
| main.asm | Existing BASIC launcher and event loop; call VFS init/exit |
| gui/screen.asm | Unchanged ROM display initialization, drawing and BASIC exit |
| gui/panels.asm | Existing layout plus dynamic path/title, version and VFS status |
| gui/filelist.asm | Existing rows/highlight/scroll rendering plus left size column |
| gui/input.asm | Existing GETIN dispatch plus Return and Backspace |
| core/navigation.asm | State/scroll logic and left-only directory event gating |
| core/vfs.asm | Transactional FAT32 snapshots, path/history, right mock, status/error |
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

No closeall, setname, findfile, loadfile, writefile, delete, rename, mount or
raw-sector service is called. CHDIR $0C is the only added trap. cdrootdir changes in-memory HDOS state only. The program does
not restore a pre-RUN HDOS directory because getcwd is documented unimplemented.
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

The renderer intentionally displays only the 8.3 alias: trim spaces, insert a dot
when an extension exists, uppercase ASCII a–z. Unsupported extended glyphs and
controls become '?'. Dot entries, volume labels/raw LFN entries, empty/deleted
aliases are filtered. Hidden/system entries are shown. Attributes 0–5 are
preserved: read-only, hidden, system, volume, directory, archive. The directory
bit determines the existing [DIR] marker. No new permission operations exist.

The Stage 1b VFS record remains 24 bytes: type byte (0=file, 1=directory), flags
byte, size LE16 KiB, 20-byte padded PETSCII name. The FAT bits occupy flags 0–5;
bit 6 marks known file size, bit 7 marks saturation. Sizes are floor(bytes/1024),
saturated at 65535; files under 1 KiB and zero-byte files show 0K. Directories
have no displayed size. The right mock rendering remains unchanged.

LFN display/Unicode are not implemented. HDOS only retains the low UTF-16 byte,
and may skip entries with long names exceeding its ~63-character limit before
returning even their alias. The explorer cannot recover omitted entries through
this API. The name buffer cannot overflow: an alias is at most 12 display bytes.

## Directory lookup and cwd synchronization

[Official CHDIR documentation](https://github.com/MEGA65/mega65-user-guide/blob/master/appendix-hypervisor-calls.tex)
confirms `$0C` changes HDOS's in-memory cwd to the last found directory entry,
including entries found through readdir. It is not a pathname-taking trap.
The guide's setname/findfile example can depend on LFN case behavior; Stage 1c
instead re-enumerates the current directory and compares its normalized 8.3 alias
and directory type. `fat32_change_directory` closes its own enumeration descriptor
before issuing CHDIR. Released `dos_closefile` frees the descriptor without
replacing the HDOS dirent; this ordering is verified in
[release-0.97.2 dos.asm](https://github.com/MEGA65/mega65-core/blob/release-0.97.2/src/hyppo/dos.asm).
CHDIR may internally use a temporary descriptor, so releasing ours first also
avoids unnecessarily exhausting HDOS's small descriptor pool.

Driver interfaces: `fat32_select_root` selects root without opening a handle;
`fat32_open_root` retains its Stage 1b behavior; `fat32_open_directory` opens the
existing HDOS cwd; `fat32_change_directory` takes `fat32_component`, a padded
20-byte safe alias, and returns C=1 success/C=0 error. Existing read_next and
close are reused. All Hypervisor calls remain in the driver and use STA/CLV.
Only $02/$3C/$12/$14/$16/$0C occur; none modifies FAT32 contents.

Parent navigation is implemented by resolving the saved parent path from root,
not by depending on a FAT `..` entry. The logical VFS parent operation replaces
a separate driver parent operation. Similarly read-directory reuses the same
Stage 1b enumeration loop, not a second implementation.

`vfs_walk_path` selects root and resolves each path component through the driver.
It is used for both target navigation and rollback. This guarantees the source
of each transition without relying on getcwd or the global dirent from the last
snapshot. Merely calling CHDIR against the cached selection would be incorrect:
HDOS's last dirent after enumeration is not necessarily the selected entry.

## Path, history and transactions

The VFS owns `vfs_path`, `vfs_path_length` and `vfs_depth`. Root is `/`.
Maximum depth is 8 below root. Maximum full path is 96 ASCII characters including
slashes; both path buffers allocate 97 bytes including NUL. Each component is an
8.3 alias of at most 12 display bytes. The Hypervisor is given one component at
a time; the overall 96-character bound is the application's safe fixed limit.
Lossy display aliases containing `?` are refused before any HDOS action.

A candidate path is scratch for a transition, not a second committed cwd.
The 24-byte history has eight parent-prefix lengths, eight selection indices and
eight scroll offsets. Child transitions append a component to the committed
prefix only after lookup, reading and cleanup succeed. Parent transitions truncate
the candidate at the saved prefix length and pop history only on success.
Parent selections are restored and clamped if a directory changed externally;
empty parents reset selection/scroll to zero. Right-panel state is untouched.
No synthetic `..` entry is needed.

The GUI derives a 37-character title from the committed path: `SD: ` plus up to
33 path characters. If longer, `...` plus the last 30 characters are copied into
the existing title render buffer. This never shortens the actual VFS path.

Two 128-entry buffers implement a transaction using the existing record renderer.
The visible directory pointer/count are saved, enumeration targets the inactive
buffer, and only success (including empty/truncated) swaps the committed slot.
Partial read/close failure restores the old pointer/count. This avoids copying
large buffers or drawing a new path above old-directory records.

Failure recovery proceeds in a fixed sequence, never an unbounded retry loop:

1. Save the first error and replay the old committed path from root.
2. If successful, retain path/history/selection/snapshot and display the error.
3. If repair fails, try root and a new root snapshot; reset left history/state.
   If root reading fails, show an empty root list with an error, never stale rows.
4. If cleanup or root selection itself fails, show `SD: ?`, count zero and
   disable SD navigation. TAB, right-panel navigation and X remain available;
   X makes the existing final owned-handle close attempt.

Status values extend Stage 1b: 0 OK, 1 empty, 2 truncated, 3 access/recovery error,
4 depth limit, 5 path limit, 6 unsupported alias, 7 unavailable context. Status
rows are cleared before redrawing so shorter messages leave no artifacts.

## Memory and bounds

| Validated Stage 1c area | Address | Bytes |
| --- | --- | --- |
| Launcher, code/data, paths/history, mocks and alignment | $2001–$31FF | 4607 |
| HDOS transfer page | $3200–$32FF | 256 |
| Snapshot A | $3300–$3EFF | 3072 |
| Snapshot B | $3F00–$4AFF | 3072 |

The PRG is 11,009 bytes including its two-byte load address. All application
memory remains in loaded bank-0 RAM below $8000. No screen/colour memory, ROM or
Hypervisor-private memory is borrowed. The two 97-byte paths, 24-byte history
and scalar bookkeeping live within the code/data area. Six assembler assertions
check both path capacities, history capacity, transfer alignment/legal address
and the full snapshot end below $8000. Labels determine addresses automatically.
The transfer page still fits the verified 87-byte HDOS record.

Every cache write retains Stage 1b's count <128 check; names/types/size conversion
and record width are unchanged. Return checks count/type, then depth/path/name
limits before calling HDOS. A non-directory, empty selection, right-panel Return
or Backspace, and root Backspace have no filesystem effects. Existing GETIN
repeat behavior is retained; Backspace is PETSCII $14, Return $0D.

## Validation and remaining limitations

Stage 1c assembled with six successful assertions. All 22 py65 binary tests
passed: nine untouched Stage 1b tests plus 13 Stage 1c tests. Coverage includes
multiple levels, exact 96-character path, depth/path rejection, tail title,
selection/scroll restoration, empty/large directories, inactive-panel gating,
full keyboard event loop and failures before/after CHDIR, rollback, root fallback
and persistent cleanup failure. Tests emulate the assembled 6502 subset with
HDOS/KERNAL stubs and memory canaries; they do not execute MEGA65 ROM or XEMU.

Stage 1c has not been executed in XEMU by the agent and has no owner-confirmed
runtime result yet. Final Stage 1c Stable approval requires an actual XEMU run
and explicit owner confirmation of [tests A–I](xemu-stage1c.md).

HDOS LFN omission, ASCII alias-only display, KiB-floor/saturated sizes, EOF
ambiguity $85 and native BASIC mappings remain as in Stage 1b. Re-enumeration and
path replay are synchronous and can delay redraw on large/slow directories.
External renames/removal can prevent replay; recovery handles this with the
stated fallback. There is no file launch, refresh, sorting, LFN navigation,
mouse support or file operation. X preserves the existing standard BASIC display
exit and leaves HDOS at the last selected Explorer cwd; a persistent Hypervisor
close failure cannot be forcibly repaired without interfering with other handles.
