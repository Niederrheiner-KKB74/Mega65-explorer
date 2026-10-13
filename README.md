# MEGA65 Explorer — Stage 1c (0.1c)

A two-panel file explorer for the MEGA65, written in KickAssembler assembly for
the 45GS02. Stage 1c adds read-only FAT32 subdirectory navigation to the left
panel. The right panel retains the existing mock directory.

The binding Stage 1b Stable base is its merge commit
[`7a837f9`](https://github.com/Niederrheiner-KKB74/Mega65-explorer/commit/7a837f9c768234caeba5261fe0fec7bd5436617f),
whose implementation and acceptance documentation are preserved. PR #2 was merged
into `feature/stage-1a-gui`; main currently contains Stage 1a. Stage 1c is based
on that stable merge and initially targets the same integration branch.
Stage 1b's build and XEMU checklist were confirmed by the project owner. Stage 1a
was also tested on hardware. XEMU is sufficient for future regular release tests.

## Implemented in Stage 1c

- Return opens a selected FAT32 directory; files and the right panel do nothing.
- Backspace returns to the parent, restoring selection/scroll where possible;
  Backspace at root does nothing.
- A central `/`-separated 8.3 path, shown in the left title. Long display paths
  show `...` plus their tail without changing the actual path.
- Fixed history: 8 levels below root. Paths: at most 96 characters including
  slashes, plus a terminator. Limits are checked before any filesystem action.
- Transactional enumeration into a second bounded 128-entry snapshot. A read
  error after CHDIR keeps the previous list/path/history and attempts cwd repair.
- If repair fails, reset to a freshly read root; if root/cleanup is unavailable,
  show `SD: ?`, hide stale records and disable SD navigation. TAB and X still work.
- Existing 80×25 layout, colour scheme, file sizes, attributes and scrolling.
- No file operations, mounting, raw SD access or filesystem writes.

Stage 1c is **not yet Stable**. Final approval requires an actual XEMU test and
explicit confirmation by the project owner. ASCII 8.3 aliases remain the navigation
interface; lossy aliases containing `?` are refused. HDOS LFN/Unicode limitations
remain. See [architecture](docs/architecture.md).

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

On 2026-10-12 Stage 1c assembled successfully with all **six memory assertions**
passing. Output is 11,009 bytes. All **22 binary-logic tests** passed: the nine
Stage 1b regressions plus 13 Stage 1c tests covering nested/empty/large directories,
input gating, restored state, path/title limits, CHDIR/read/close failures, rollback,
root fallback and offline handling. They execute the assembled code with simulated
HDOS/KERNAL, not real MEGA65 ROM or XEMU.

Optional tests require Python 3 and [py65](https://github.com/mnaberez/py65):

```sh
python3 -m pip install py65
make clean
make test KICKASS_JAR=/absolute/path/to/KickAss65CE02-5.25.jar
```

Exact executed command in this environment (py65 retrieved via GitHub integration):
`PYTHONPATH=/tmp/py65-local make test KICKASS_JAR=/workspace/attachments/1a813b32-80e6-4ad0-a9de-b319cc0f642a/KickAss65CE02-5.25.jar`.
Static review checked the read-only trap allowlist and unchanged Stage 1b screen,
file-row renderer, mock data, DOS/IEC placeholders and license.
**Stage 1c has not been executed in XEMU here and has no owner-confirmed runtime
result yet.** No hardware test is required.

## Keyboard controls

| Key | Action |
| --- | --- |
| Cursor Up / Down | Previous / next entry, clamped at either end |
| TAB | Switch panel, preserving both selections and offsets |
| Return | Open selected FAT32 directory in the active left panel |
| Backspace | Return to FAT32 parent in the active left panel |
| X | Close any remaining owned directory handle and return to standard BASIC |

## Manual testing

See [Stage 1c XEMU navigation checklist](docs/xemu-stage1c.md). Start in
native BASIC 65 with a bootable MEGA65 SD image and a legally obtained ROM,
preferably ROM 920373 or newer and core/Hyppo from release 0.97.2. Inject the PRG
using XEMU's **Inject program** menu, then `RUN` if necessary. A D81 LOAD/RUN is
also possible; the left panel still reads the SD FAT32 root, not the mounted D81.

The runtime reads only; preparing test files in a disposable image is a separate
host-side operation. The source neither formats nor writes SD images. On X it
clears to standard 80×25 BASIC, not the previous display snapshot. HDOS remains at the last successfully selected Explorer directory; the application
does not restore a working directory that existed before RUN. No mounted D81 is changed.

## Roadmap

1. Stage 1c: project-owner XEMU test and explicit Stable approval.
2. Richer VFS metadata/errors, refresh and long-name support.
3. D81/DOS browsing, internal/external drives and IEC.
4. Copy, rename, delete and launch with explicit error handling.

The existing GPL-3.0 LICENSE is retained.
