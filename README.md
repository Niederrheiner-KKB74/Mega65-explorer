# MEGA65 Explorer — Stage 1b Stable (0.1b)

A two-panel file explorer for the MEGA65, written in KickAssembler assembly for
the 45GS02. Stage 1b reads the **default HDOS SD partition's FAT32 root** into
the left panel. The right panel retains Stage 1a's mock directory.

Stage 1a Stable is preserved at commit
[`d4bf662`](https://github.com/Niederrheiner-KKB74/Mega65-explorer/commit/d4bf66207e900b756f96f67a12cf4e9f58da19ff).
The project owner confirmed the Stage 1a README checklist in XEMU and on real
MEGA65 hardware. For future releases XEMU is sufficient; hardware tests are
optional. Stage 1b is based on that commit, with its PR initially targeting
`feature/stage-1a-gui` because PR #1 has not been merged into main.

## Implemented in Stage 1b

- Read-only HDOS root enumeration; directories and files use the existing VFS.
- Safe uppercase 8.3 aliases, FAT attributes and file sizes displayed as KiB
  rounded down. Sizes beyond 65,535 KiB display `>=65535K`.
- A bounded 128-entry snapshot; excess entries produce a visible truncation notice.
- Empty directories and open/read/close failures handled without mock fallback.
  On a read error, already collected entries remain visible and marked incomplete.
- The existing 80×25 layout, colours, 16-row viewport, selection and panel state.
- No file operations, mounting, raw SD access or filesystem writes.

**Stage 1b Stable:** on 2026-10-12 the project owner confirmed the completed
XEMU acceptance checklist and working build for implementation commit
[`577e7fa`](https://github.com/Niederrheiner-KKB74/Mega65-explorer/commit/577e7fa5fa4d6eae73054134d2dda94f52a6b5bb). Subdirectory navigation, LFN display, sorting and refresh are planned.
HDOS may omit entries whose long names exceed its own limit, even if they have
an 8.3 alias; see [architecture](docs/architecture.md).

## Build

Dependencies: GNU Make, Java (OpenJDK 21 used), KickAssembler 5.25. The supplied
`KickAss65CE02-5.25.jar` was used; the jar is not committed. Its SHA-256 is
`5d8544280dae2d018c79151d8c7b877eca1fb994096e54ca380b26d0cd79f847`.
The code uses the 6502-compatible subset of the native 45GS02.

```sh
make KICKASS_JAR=/absolute/path/to/KickAss65CE02-5.25.jar
```

The exact successful command in the implementation environment was:

```sh
make KICKASS_JAR=/workspace/attachments/1a813b32-80e6-4ad0-a9de-b319cc0f642a/KickAss65CE02-5.25.jar
```

Make runs `java -jar "$(KICKASS_JAR)" src/main.asm -o
build/mega65-explorer.prg -symbolfile`. Output is `build/mega65-explorer.prg`;
the symbol map is `src/main.sym`. The PRG starts at $2001 with `10 SYS 8224`,
code at $2020. `make clean` removes generated outputs. No PRG, jar or ROM is in Git.

## Validation

On 2026-10-12 the Stage 1b source assembled with zero errors and all three
memory assertions passed. Nine binary-logic tests passed, including buffer
capacity/overflow canaries, empty directories, error cleanup, both documented EOF
codes, safe filename conversion, file sizes, navigation and the complete event
loop with mocked HDOS/KERNAL calls. This is not a MEGA65 ROM or XEMU test.

Optional automated tests require Python 3 and [py65](https://github.com/mnaberez/py65):

```sh
python3 -m pip install py65
make clean
make test KICKASS_JAR=/absolute/path/to/KickAss65CE02-5.25.jar
```

In the implementation environment py65 source was retrieved through the GitHub
integration into `/tmp/py65-local`; the exact executed test command was:
`PYTHONPATH=/tmp/py65-local make test KICKASS_JAR=/workspace/attachments/1a813b32-80e6-4ad0-a9de-b319cc0f642a/KickAss65CE02-5.25.jar`.
The agent did not execute XEMU or hardware tests. On 2026-10-12 the project owner
confirmed that the XEMU acceptance checklist was completed and the build works.
This is owner-reported runtime validation; XEMU/core/ROM versions were not supplied.
Hardware testing is optional under project policy.

## Keyboard controls

| Key | Action |
| --- | --- |
| Cursor Up / Down | Previous / next entry, clamped at either end |
| TAB | Switch panel, preserving both selections and offsets |
| X | Close any remaining owned directory handle and return to standard BASIC |

## Manual testing

See [XEMU FAT32 setup and acceptance checklist](docs/xemu-stage1b.md). Start in
native BASIC 65 with a bootable MEGA65 SD image and a legally obtained ROM,
preferably ROM 920373 or newer and core/Hyppo from release 0.97.2. Inject the PRG
using XEMU's **Inject program** menu, then `RUN` if necessary. A D81 LOAD/RUN is
also possible; the left panel still reads the SD FAT32 root, not the mounted D81.

The runtime reads only; preparing test files in a disposable image is a separate
host-side operation. The source neither formats nor writes SD images. On X it
clears to standard 80×25 BASIC, not the previous display snapshot. HDOS remains
at the default partition's root; it does not restore a previous HDOS working
directory. No mounted D81 is changed.

## Roadmap

1. Stage 1b Stable: build and project-owner XEMU acceptance confirmed.
2. Subdirectory navigation and richer VFS metadata/errors.
3. D81/DOS browsing, internal/external drives and IEC.
4. Copy, rename, delete and launch with explicit error handling.

The existing GPL-3.0 LICENSE is retained.
