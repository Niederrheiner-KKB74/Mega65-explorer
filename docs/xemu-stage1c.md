# Stage 1c XEMU acceptance — tests A–I

Stage 1c is awaiting a real XEMU run and explicit project-owner Stable approval.
Use the same native BASIC 65 ROM/core configuration that passed Stage 1b, with a
**disposable copy** of the working SD image. Do not edit the working image.
[Stage 1b setup](xemu-stage1b.md) documents FAT32 partition offsets, mtools and
`xmega65 -sdimg /path/to/copy.img`. The Explorer itself remains read-only;
host-side fixture preparation writes only the copy. Quit XEMU before editing it.

## Prepare a directory tree

Using your preferred FAT32 host tool, create this tree in the boot-default FAT32
partition. With mtools, `mmd -i copy.img@@OFFSET ::GAMES` and analogous commands
create each path; `mcopy -i copy.img@@OFFSET hostfile ::GAMES/ARCADE/NAME.PRG`
copies files. Replace OFFSET with the partition byte offset from the Stage 1b guide.

```text
/
  GAMES/
    ARCADE/
      SHOOTERS/
        HELLO.PRG
      EMPTY/
      LONG/
        F0000000.PRG ... F0000029.PRG
      HUGE/
        F0000000.PRG ... F0000139.PRG
    START.PRG
```

For visible parent-state restoration, add at least 20 files before an additional
subdirectory in a parent (FAT insertion order is used, not sorting). For depth
bounds, create a chain of at least 9 short-named directories (`A/A/...`). For
path bounds, create repeated 12-character aliases (`ABCDEFGH.XYZ/...`): seven
components produce 91 path characters; an eighth exceeds 96 and must be refused.
Seven such components followed by `/LAST` give exactly 96 and should work.
Use 8.3 directory names; an LFN may display an alias and HDOS can omit overlong LFNs.

Build/inject `build/mega65-explorer.prg`, then RUN if needed. A D81 LOAD/RUN is also
possible; the left panel still navigates the SD FAT32 partition, not that D81.

## Test A — Root

Start the Explorer. Expect V0.1C, `SD: /`, the real root listing, existing colours
and file sizes, and unchanged right mock data. Backspace at root has no effect.
Return on a normal file has no effect; no program is launched.

## Test B — Open a child

Select GAMES and press Return. Expect `/GAMES`, its own contents, and selection
at its first entry. Open ARCADE. Expect `/GAMES/ARCADE`. When the path exceeds
33 title characters, expect `SD: ...` with the tail; navigate back to confirm
that only its display was shortened.

## Test C — Parent and restored state

Scroll a parent until its selected subdirectory is beyond the first 16 entries.
Open it and press Backspace. Expect the same parent, prior selected directory
and prior scroll position. Repeat. The selected row must remain visible.

## Test D — Multiple levels

Open GAMES/ARCADE/SHOOTERS, then go back one level at a time to root. Each list
must match its title. Repeat Return/Backspace cycles to detect descriptor leaks.

## Test E — Long and truncated directory

Open LONG; scroll both ways, checking clamps at each end. Open HUGE: only the
first 128 displayable entries are cached and a truncation notice appears. Return
and Backspace must still work. An exactly 128-entry directory is not truncated.

## Test F — Empty child

Open EMPTY. Expect the correct path, no phantom entries or reversed blank
selection. Up/Down and Return are harmless. Backspace restores ARCADE's state.

## Test G — Panel switching

Select/scroll in both panels and repeatedly TAB between them. Return/Backspace
in the right panel must leave the SD path/list unchanged and perform no FAT32
navigation. Switch left, navigate and come back; right state must be preserved.

## Test H — BASIC return

After several directory transitions, press X. Expect a standard BASIC screen;
`PRINT 123` must work. Repeat RUN/navigate/X to check cleanup. No files or disk
images are opened for writing or mounted by the Explorer.

## Test I — Bounds and controlled errors

Traverse eight short-name levels. The ninth Return must report the depth limit
without changing list/path; Backspace must still work. For 12-character names,
attempt the eighth component after a 91-character prefix: expect the path-limit
notice and unchanged state. An exactly 96-character path must be accepted.

For optional debugger-assisted fault tests, use `src/main.sym` and emulate a
failed read result after CHDIR (clear C and return $20 from the readdir trap).
Expect old path/list/history restored. If replay of the old path also fails,
expect a freshly read root or an empty error-marked root. If root selection or
cleanup cannot be restored, expect `SD: ?`, no stale SD rows and disabled SD
navigation; TAB/right navigation/X must still work. These fault cases are also
covered by binary-logic tests; do not corrupt the working image to test them.

Record XEMU/core/Hyppo/ROM versions and tests A–I results. Stage 1c Stable requires
a successful actual XEMU test and explicit project-owner confirmation. Hardware
testing remains optional. No automatic merge is performed.
