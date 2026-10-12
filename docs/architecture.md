# Stage 1a architecture

The GUI consumes a small read-only VFS record interface. Navigation knows only
counts and indices; it does not know registers, filenames or storage devices.

| File | Responsibility / public interface |
| --- | --- |
| src/main.asm | BASIC 65 launcher, initialization, event loop, clean SYS return |
| gui/screen.asm | ROM screen setup, positioning, PETSCII drawing, standard BASIC exit |
| gui/panels.asm | Header, borders, titles, footer; panels_draw / panels_refresh |
| gui/filelist.asm | Render 16 rows for render_panel via VFS; filelist_draw |
| gui/input.asm | GETIN and dispatch; input_poll returns A=0 idle, 1 redraw, 2 exit |
| core/navigation.asm | active_panel, selected[2], scroll[2]; init/up/down/tab |
| core/vfs.asm | Record schema and mock enumeration; vfs_entry / vfs_read |
| data/mockfiles.asm | Two independent directories with 24 and 18 entries |
| drivers/fat32.asm | Future SD FAT32 backend; currently comments only |
| drivers/dos.asm | Future D81/internal/external DOS backend; currently comments only |
| drivers/iec.asm | Future IEC backend; currently comments only |

## Calling conventions

Unless stated otherwise routines destroy A/X/Y and arithmetic flags. They return
through RTS and leave the stack balanced. Calls are synchronous and non-reentrant.
No custom IRQ, memory manager or application zero-page allocation is needed.
ROM IRQs and keyboard service remain enabled under normal BASIC startup state.

screen_at takes X=row and Y=column. screen_text takes A/Y=low/high address of a
NUL-terminated PETSCII string shorter than 256 bytes. The program owns its writable
code/data; screen_text and vfs_entry patch absolute instruction operands to avoid
borrowing ROM zero page. ROM routines must not call these routines recursively.

Navigation preserves Y and clobbers A/X/flags. panel indices are 0/1, selection
and scroll are byte indices. Down clamps at count-1; Up clamps at zero. After a
move, scroll <= selection < scroll+16. TAB only toggles active_panel. Counts must
be nonzero, at most 255; handling empty directories is a later VFS requirement.

vfs_entry takes X=panel, A=valid index; preserves X, destroys A/Y/flags and sets
the operand used by vfs_read. vfs_read takes Y=record offset, returns A and
preserves X/Y. Callers check entry_counts before requesting a record.

Each 24-byte record contains type (0=file, 1=directory), flags (bit 0=read-only),
size in illustrative KiB (little-endian 16-bit, zero=unknown), and a 20-byte padded
uppercase PETSCII filename. The GUI uses type/name only. Real drivers will translate
names into this display encoding and publish bounded enumeration buffers; long
names, byte-accurate sizes, empty lists, backend errors and operations require a
future interface revision. GUI drawing must not acquire backend-specific logic.

## Display and return to BASIC

Stage 1a deliberately uses 80×25: it provides ample two-panel width while a
16-row viewport exercises scrolling in both mocks. It delegates VIC-IV geometry,
screen RAM and colour RAM locations to the native ROM using CHROUT ESC then 8.
PLOT positions the cursor, CHROUT draws PETSCII and GETIN reads keyboard events.
This is a VIC-IV text display, not a bitmap window system. Borders are ASCII
separators; drawing stays short of column 79 to avoid screen-editor line pushing.
Row 24 is unused to avoid bottom-line scrolling. Active title/selection use white
reverse text, inactive contents use cyan. The ROM background palette is retained.

No application MAP, CPU speed, VIC register, DMA, palette, IRQ vector or screen
pointer changes are made. ROM screen initialization owns its required hardware
changes. X calls KERNAL CINT ($FF81), explicitly requests 80×25, upper-case,
reverse-off, white text and clear/home, then returns through the original SYS
stack frame. Processor flags saved by the entry PHP are restored with PLP.
The previous screen contents, colours and 40/50-row mode are **not** restored;
the intentional fallback is a cleared standard BASIC display. Exit reliability
across supported ROM/core combinations still needs actual machine testing.
Do not confuse CINT with IOINIT: no storage initialization is invoked.

## Technical references

- [Official ROM changelog](https://github.com/MEGA65/mega65-rom-public/blob/main/CHANGELOG.md): ESC 4/5/8 text modes.
- [MEGA65 register map](https://github.com/MEGA65/mega65-core/blob/development/iomap.txt): VIC-IV and keyboard interfaces.
- [Official ROM transition examples](https://mega65.atlassian.net/wiki/spaces/MEGA65/pages/5603329/Transitioning+programs+to+use+ROM+920373): colour RAM changed with ROM 920373; hardcoded C64 addresses are unsuitable.
- [MEGA65 open-ROM status/jump table](https://github.com/MEGA65/open-roms/blob/master/STATUS.md): KERNAL entry points. The supported runtime here is native MEGA65 BASIC 65 ROM, not an untested alternative ROM.

## Validation and limitations

Source inspection checked module imports, entry counts/record widths, viewport
bounds and the absence of filesystem calls or device-register accesses. Navigation
was exercised with a temporary source-instruction interpreter for the actual
navigation routine (all valid selection/scroll states in both directories and
TAB preservation). This does not validate an assembled binary or ROM behavior.

Assembly succeeded using the supplied KickAss65CE02-5.25.jar after fixing forward
constant references. PRG header/launcher checks passed. XEMU and hardware tests
were not performed. Stage 1a acceptance remains pending until visible rendering,
keyboard codes, scroll preservation
and standard BASIC return are verified with the README checklist. Redrawing both
lists on navigation is intentionally simple and may need optimization if ROM
output produces visible flicker. No filesystem access, mouse support, sorting,
file operations or launch support is present.
