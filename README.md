# MEGA65 Explorer — 0.1a

A two-panel file explorer for the MEGA65, written in KickAssembler assembly for
the 45GS02. Stage 1a adds a **mock-data GUI prototype**. The source assembles successfully; machine validation is still pending.

Implemented in source: native 80×25 text screen, cyan text, white reversed active
panel title and selection, independent directories (24/18 records), cursor
navigation, scrolling with 16 visible entries, TAB switching and X return to BASIC.
No filesystem routines or device writes are implemented. Names, types, read-only
flags and illustrative sizes are structured data, not embedded in GUI code.

## Build

Dependencies: GNU Make, Java (21 available in the implementation environment),
KickAssembler 5.25 (validated with the supplied KickAss65CE02-5.25.jar; not
bundled). The upstream distribution is at https://theweb.dk/KickAssembler/.
Only ordinary 6502 opcodes are used; these run on the native 45GS02.
Extract KickAss.jar and its distribution files outside the repository, then:

```sh
make KICKASS_JAR=/absolute/path/to/KickAss.jar
```

The exact assembler command generated is:

```sh
java -jar /absolute/path/to/KickAss.jar src/main.asm -o build/mega65-explorer.prg
```

The PRG starts at $2001 with a BASIC 65 `10 SYS 8224` launcher; code is at $2020.
`make clean` removes generated outputs. Build artifacts and downloaded tools are
ignored by Git. No ROM image is distributed.

**Validation on 2026-10-12:** the initial build was blocked by a missing jar
and failed proxy download. After KickAss65CE02-5.25.jar was supplied, this exact
command succeeded (exit 0, no reported errors/warnings):

```sh
make KICKASS_JAR=/workspace/attachments/1a813b32-80e6-4ad0-a9de-b319cc0f642a/KickAss65CE02-5.25.jar
```

Output: `build/mega65-explorer.prg`, 2,024 bytes. A clean rebuild was byte-identical.
Validated jar SHA-256:
`5d8544280dae2d018c79151d8c7b877eca1fb994096e54ca380b26d0cd79f847`.
PRG SHA-256:
`5d769ca331572e712a555595053c2a167c5a6acdf397e5dfed0751e6cce420cb`. Its $2001 load address, BASIC
SYS launcher and $2020 entry opcode were checked. 864 source-instruction
navigation cases passed, plus record/import checks. XEMU is absent and real
hardware is unavailable; rendering, real keyboard input and exit are unverified.
See docs/architecture.md and the manual checklist below.

## Launch and manual acceptance test

Use XEMU's MEGA65 target (`xmega65`), configured with a legally obtained MEGA65
ROM, preferably ROM 920373 or later. Start in native BASIC 65, not C64 mode.
Use XEMU's context menu **Inject program** to select `build/mega65-explorer.prg`,
then `RUN` if injection does not start it. Menu names can vary by XEMU version.
Alternatively copy the PRG onto a test D81, mount it and use:

```basic
LOAD "MEGA65-EXPLORER",8
RUN
```

On real MEGA65 hardware, copy the PRG onto a test D81 with your normal host-side
image tool, mount that image as unit 8 and use the same LOAD/RUN commands.
Loading the application is outside its mock-only runtime; it never opens files.

| Key | Action |
| --- | --- |
| Cursor Up / Down | Previous / next entry, clamped at either end |
| TAB | Switch active panel, preserving both selections and offsets |
| X | Clear to a standard 80×25 BASIC screen and return from SYS |

Check the title/version, both directories and a reversed left selection. Press
Down at least 20 times: the left list must scroll; the selected row stays visible.
Switch with TAB, move Down at least 17 times and check right scrolling. Switch
back and verify the left selection and viewport survived. Move above/below each
boundary and check no wraparound. Press X: BASIC must accept and display `PRINT
123` normally. Repeat RUN and test exit after scrolling both panels. Test startup
from BASIC's 40×25, 80×25 and 80×50 modes, on PAL and NTSC when available.
No entry opens, mounts, renames, deletes, copies or launches anything.

## Roadmap

1. Stage 1a validation: assemble, run in XEMU, verify exit on real hardware.
2. Define backend enumeration/error handling and replace mock records via VFS.
3. Read-only FAT32 SD and D81/DOS browsing, then internal/external drives and IEC.
4. Copy, rename, delete and launch operations with explicit error handling.

See [architecture](docs/architecture.md). The existing GPL-3.0 LICENSE is retained.
