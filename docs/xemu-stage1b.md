# Stage 1b XEMU FAT32 test

Use native MEGA65 mode, a legally obtained ROM (920373 or newer recommended) and
a recent compatible core/Hyppo (release 0.97.2 is the audited reference). HDOS
requires a recognized, valid FAT32 SD partition. A mounted D81 alone does not
supply FAT32 contents. Default HDOS partition means the partition selected at
boot, not Commodore unit 8. Older Hyppo without cdrootdir produces an error.

No existing XEMU installation or SD image is present in the agent environment;
these instructions are for the project owner's setup. Stage 1a was already
confirmed on XEMU and real hardware. On 2026-10-12 the project owner confirmed
completion of this Stage 1b checklist and the working build of commit
577e7fa5fa4d6eae73054134d2dda94f52a6b5bb. Stage 1b is Stable. This is
owner-reported testing; the agent did not execute XEMU. Test versions were not supplied.

## Use a disposable copy

Quit XEMU before copying/editing its SD image. Preserve your working image:

```sh
cp --reflink=auto /path/to/working-sd.img /path/to/stage1b-test.img
xmega65 -sdimg /path/to/stage1b-test.img
```

Use the same ROM/core configuration as your working installation. `-sdimg` is
XEMU's documented SD-image override in its
[configuration source](https://github.com/lgblgblgb/xemu/blob/master/targets/mega65/configdb.c).
Boot the copy once to confirm native BASIC, then quit before adding fixtures.
If no working image exists, use XEMU's normal SD setup wizard on a **new** image
and supply your ROM. XEMU's
[SD setup implementation](https://github.com/lgblgblgb/xemu/blob/master/targets/mega65/sdcontent.c)
creates a FAT32 user partition and a system partition. Do not format the working
image or remove required ROM/system files to manufacture an empty directory.

## Add test data to the FAT32 partition, not a D81

Use your preferred host-side FAT32 image tool. One option is mtools, which supports
partition byte offsets without mounting or root permissions. Identify the FAT32
partition offset in the copied image's MBR (type $0B/$0C):

```sh
python3 - /path/to/stage1b-test.img <<'PY'
import sys
with open(sys.argv[1], 'rb') as f:
    mbr = f.read(512)
assert mbr[510:512] == b'\x55\xaa'
for i in range(4):
    part = mbr[446 + i * 16:462 + i * 16]
    if part[4] in (0x0b, 0x0c):
        print('Partition', i + 1, 'byte offset:', int.from_bytes(part[8:12], 'little') * 512)
PY
```

If several FAT32 partitions exist, use the boot-default one. Replace `OFFSET`
below with that printed decimal byte offset; all commands target the disposable
copy. These fixture-preparation commands **write the test image**, while the
Explorer runtime is read-only.

```sh
mkdir -p fixtures
python3 - <<'PY'
from pathlib import Path
p = Path('fixtures')
for i in range(30):
    (p / f'T{i:07}.PRG').write_bytes(b'X' * (i * 1024))
(p / 'README.TXT').write_text('Stage 1b FAT32 fixture\n')
(p / 'A long filename.txt').write_text('Expect the FAT-generated 8.3 alias\n')
PY
mmd -i /path/to/stage1b-test.img@@OFFSET ::ARCADE
mcopy -i /path/to/stage1b-test.img@@OFFSET fixtures/* ::/
mdir -i /path/to/stage1b-test.img@@OFFSET ::/
```

mtools may need installation on the host. It should create an alias for the long
name; the Explorer intentionally displays that alias. Zero-byte files should be
shown as 0K. Known 1024-byte files show 1K. Subdirectories display [DIR], not size.
For truncation use a second disposable copy and add >128 visible root entries;
existing ROM/system entries also count. Directory order is FAT order, not sorted.

## Launch

Boot XEMU with the edited copy. Use **Inject program** to select
`build/mega65-explorer.prg`, then `RUN` if needed. Menu labels vary by version.
Alternatively load the PRG from a test D81 using `LOAD "MEGA65-EXPLORER",8` then
`RUN`; this does not change the SD partition used by the left panel.

## Acceptance checklist

1. Header says V0.1B; left title is SD: /; right is D81: UNIT 8.
2. Left lists the real SD root, including ARCADE and test files; right retains
   Stage 1a mock names. No left mock fallback should appear on failure.
3. Files/directories are distinguished; alias names and KiB-floor sizes match
   the fixtures. Control/unsupported bytes never cause cursor movement.
4. Up/Down clamp at each end and scroll after 16 rows; the selected row stays visible.
5. TAB preserves both panels' selection and scroll offsets, including right mock scrolling.
6. X returns to BASIC; `PRINT 123` works. Repeat RUN/X several times to check
   descriptors are not leaked. Preserve the existing Stage 1a exit behavior.
7. With >128 displayable root entries, exactly 128 are cached, a truncation
   notice appears, and navigation cannot read past the end. An exactly 128-entry
   directory must not be marked truncated.
8. Verify no card contents changed due to Explorer runtime. Compare host-side
   directory listings before/after. A bytewise image comparison is meaningful
   only when unrelated emulator/ROM activity is excluded.

An actually empty root cannot normally boot if it also holds the required ROM
files. Empty/filtered-only directories and injected open/read/close errors are
covered by the binary tests, without deleting system files. For an optional
manual error test using the debugger, force X=$FF immediately before the
`cdrootdir` trap; this selects a nonexistent HDOS partition and should produce
an error notice while TAB/navigation/X remain responsive. Use symbols from
`src/main.sym`; do not change the service number or issue write/mount traps.

Report XEMU version, core/Hyppo/ROM versions, which SD partition was used and the
checklist result when reporting future tests. The project owner confirmed Stage 1b
Stable through completion of this checklist on 2026-10-12.
Real hardware testing is optional under the project's updated release policy.
