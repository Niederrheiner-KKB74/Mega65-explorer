"""Execute the assembled 6502-subset PRG with mocked HDOS/KERNAL.
Requires py65. This checks application logic, NOT XEMU/ROM/SD integration.
Run: python3 tests/test_stage1b.py
"""
import re
import unittest
from pathlib import Path
from py65.devices.mpu6502 import MPU

ROOT = Path(__file__).resolve().parents[1]
SYMS = {n: int(v, 16) for n, v in re.findall(
    r'\.label (\w+)=\$([0-9a-fA-F]+)', (ROOT / 'src/main.sym').read_text())}
PRG = (ROOT / 'build/mega65-explorer.prg').read_bytes()
LOAD = int.from_bytes(PRG[:2], 'little')


def entry(alias='HELLO.PRG', attr=0x20, size=1234):
    b = bytearray(87)
    name, _, ext = alias.partition('.')
    b[0x41:0x4c] = (name.ljust(8)[:8] + ext.ljust(3)[:3]).encode('latin1')
    b[0x52:0x56] = size.to_bytes(4, 'little')
    b[0x56] = attr
    return b


class Machine:
    def __init__(self, entries=(), eof=0xff, fail=None, skip_clv=False, keys=()):
        self.cpu = MPU()
        self.mem = self.cpu.memory
        self.mem[LOAD:LOAD + len(PRG) - 2] = PRG[2:]
        self.entries = list(entries)
        self.eof, self.fail, self.skip_clv = eof, fail or {}, skip_clv
        self.calls, self.keys = [], list(keys)
        self.opened = False
        self.screen = [[' '] * 80 for _ in range(25)]
        self.row = self.col = 0
        self.escape = False
        self.output = []
        self.initial_screen = None
        self.guard = SYMS['vfs_buffer_end']
        self.mem[self.guard:self.guard + 32] = [0xa5] * 32

    def byte(self, label):
        return self.mem[SYMS[label]]

    def hdos(self):
        c = self.cpu
        op = c.a
        self.calls.append(op)
        assert op in (0x02, 0x3c, 0x12, 0x14, 0x16), hex(op)
        c.p |= c.CARRY
        if op in self.fail:
            c.a = self.fail[op]
            c.p &= ~c.CARRY
            return
        if op == 2:
            c.a = 0
        elif op == 0x3c:
            assert c.x == 0
        elif op == 0x12:
            assert not self.opened
            self.opened = True
            c.a = 2
        elif op == 0x14:
            assert self.opened and c.x == 2
            assert c.y * 256 == SYMS['fat32_transfer']
            if not self.entries:
                c.a = self.eof
                c.p &= ~c.CARRY
            else:
                b = self.entries.pop(0)
                if isinstance(b, int):
                    c.a = b
                    c.p &= ~c.CARRY
                else:
                    start = c.y * 256
                    self.mem[start:start + len(b)] = b
        elif op == 0x16:
            assert self.opened and c.x == 2
            self.opened = False

    def return_from_rom(self):
        self.cpu.pc = (self.cpu.stPopWord() + 1) & 0xffff

    def step(self):
        c = self.cpu
        if self.mem[c.pc:c.pc + 3] == [0x8d, 0x40, 0xd6]:
            self.hdos()
            c.pc += 4 if self.skip_clv else 3
            return
        if c.pc == 0xfff0:
            self.row, self.col = c.x, c.y
            assert 0 <= self.row < 25 and 0 <= self.col < 80
            self.return_from_rom()
        elif c.pc == 0xffd2:
            b = c.a
            if self.escape:
                assert b == ord('8')
                self.escape = False
            elif b == 27:
                self.escape = True
            elif b == 147:
                self.screen = [[' '] * 80 for _ in range(25)]
                self.row = self.col = 0
            elif b not in (5, 18, 142, 146, 159):
                self.output.append(b)
                assert 0x20 <= b <= 0x7e, hex(b)
                assert self.col < 79, 'ROM line-pushing hazard'
                self.screen[self.row][self.col] = chr(b)
                self.col += 1
            self.return_from_rom()
        elif c.pc == 0xffe4:
            if self.initial_screen is None:
                self.initial_screen = ["".join(row) for row in self.screen]
            assert self.keys, 'Application did not exit after input'
            c.a = self.keys.pop(0)
            self.return_from_rom()
        elif c.pc == 0xff81:
            self.return_from_rom()
        else:
            assert c.disassemble[self.mem[c.pc]][0] != '???'
            c.step()

    def call(self, label, a=0, x=0, y=0):
        c = self.cpu
        c.a, c.x, c.y = a, x, y
        c.pc = SYMS[label]
        c.stPushWord(0xffff)
        for _ in range(1000000):
            if c.pc == 0:
                assert c.sp == 0xff
                assert self.mem[self.guard:self.guard + 32] == [0xa5] * 32
                return c.a
            self.step()
        raise AssertionError('Execution budget exceeded')

    def record(self, index=0):
        start = SYMS['vfs_buffer'] + 24 * index
        return self.mem[start:start + 24]


class Stage1b(unittest.TestCase):
    def test_prg_layout(self):
        self.assertEqual(LOAD, 0x2001)
        self.assertEqual(PRG[6:12], b'\x9e8224\x00')
        self.assertEqual(SYMS['fat32_transfer'] % 256, 0)
        self.assertLessEqual(SYMS['fat32_transfer'], 0x7e00)
        self.assertEqual(SYMS['vfs_buffer_end'] - SYMS['vfs_buffer'], 128 * 24)
        self.assertLessEqual(SYMS['vfs_buffer_end'], 0x8000)

    def test_empty_and_clv_variants(self):
        for eof in (0xff, 0x85):
            for skip in (False, True):
                m = Machine(eof=eof, skip_clv=skip)
                m.call('vfs_init')
                self.assertEqual(m.byte('entry_counts'), 0)
                self.assertEqual(m.byte('vfs_status'), 1)
                self.assertFalse(m.opened)
                m.call('navigation_init')
                m.call('navigation_up')
                m.call('navigation_down')
                self.assertEqual(m.byte('selected'), 0)
                self.assertEqual(m.byte('scroll'), 0)

    def test_open_and_read_errors(self):
        for op in (2, 0x3c, 0x12):
            m = Machine(fail={op: 0x80})
            m.call('vfs_init')
            self.assertEqual(m.byte('vfs_status'), 3)
            self.assertEqual(m.byte('vfs_error'), 0x80)
            self.assertNotIn(0x16, m.calls)
        for records in ([0x20], [entry(), 0x20]):
            m = Machine(records)
            m.call('vfs_init')
            self.assertEqual(m.byte('vfs_status'), 3)
            self.assertEqual(m.byte('vfs_error'), 0x20)
            self.assertFalse(m.opened)

    def test_close_retry_preserves_original_error(self):
        m = Machine([0x20], fail={0x16: 0x89})
        m.call('vfs_init')
        self.assertEqual(m.byte('vfs_error'), 0x20)
        self.assertTrue(m.opened)
        del m.fail[0x16]
        m.call('vfs_close')
        self.assertFalse(m.opened)
        m.call('vfs_close')
        self.assertEqual(m.calls.count(0x16), 2)
        m = Machine(fail={0x16: 0x89})
        m.call('vfs_init')
        self.assertEqual(m.byte('vfs_error'), 0x89)
        self.assertEqual(m.byte('vfs_status'), 3)

    def test_capacity_exact_and_overflow(self):
        for count in (1, 127, 128, 129, 200):
            m = Machine([entry(f'F{i:07}.PRG') for i in range(count)])
            m.call('vfs_init')
            self.assertEqual(m.byte('entry_counts'), min(count, 128))
            self.assertEqual(m.byte('vfs_status'), 2 if count > 128 else 0)
            self.assertFalse(m.opened)
            self.assertEqual(m.calls.count(0x14), min(count + 1, 129))

    def test_filter_and_safe_ascii(self):
        records = [entry('VOL', 8), entry('LFN', 15), entry('', 0),
                   entry('\xe5BAD', 0), entry('\x2e', 16),
                   entry('lower.txt', 0x27), entry('DIR', 0x16),
                   entry('\x01BAD.EXT', 0x20)]
        m = Machine(records)
        m.call('vfs_init')
        self.assertEqual(m.byte('entry_counts'), 3)
        self.assertEqual(bytes(m.record()[4:]).decode(), 'LOWER.TXT'.ljust(20))
        self.assertEqual(m.record()[1] & 0x3f, 0x27)
        self.assertEqual(m.record(1)[0], 1)
        self.assertEqual(m.record(1)[1], 0x16)
        self.assertEqual(bytes(m.record(2)[4:]).decode(), '?BAD.EXT'.ljust(20))

    def test_sizes_and_rendering(self):
        for size in (0, 1023, 1024, 1234567, 65535 * 1024, 65536 * 1024, 0xffffffff):
            m = Machine([entry('LONGNAME.EXT', size=size)])
            m.call('vfs_init')
            r = m.record()
            self.assertEqual(r[2] + 256 * r[3], min(size // 1024, 65535))
            self.assertEqual(bool(r[1] & 128), size // 1024 > 65535)
            m.call('vfs_entry')
            m.call('filelist_size')
            expected = '>=65535K' if size // 1024 > 65535 else f'  {size // 1024:5}K'
            self.assertEqual(bytes(m.output).decode(), expected)

    def test_navigation(self):
        m = Machine()
        for count in (1, 18, 128):
            m.mem[SYMS['entry_counts']] = count
            for selected in range(count):
                for top in (max(0, selected - 15), selected):
                    for routine, expect in [('navigation_up', max(0, selected - 1)),
                                            ('navigation_down', min(count - 1, selected + 1))]:
                        m.call('navigation_init')
                        m.mem[SYMS['selected']] = selected
                        m.mem[SYMS['scroll']] = top
                        m.call(routine)
                        self.assertEqual(m.byte('selected'), expect)
                        self.assertLessEqual(m.byte('scroll'), expect)
                        self.assertLess(expect, m.byte('scroll') + 16)
                        before = (m.byte('selected'), m.byte('scroll'))
                        m.call('navigation_tab')
                        self.assertEqual(m.byte('active_panel'), 1)
                        self.assertEqual(before, (m.byte('selected'), m.byte('scroll')))

    def test_complete_app_with_rom_stubs(self):
        keys = [0x11] * 20 + [9] + [0x11] * 17 + [9, 0x91, ord('X')]
        m = Machine([entry(f'F{i:07}.PRG') for i in range(24)], keys=keys)
        m.call('main')
        self.assertIn('SD: /', m.initial_screen[3])
        self.assertIn('F0000000.PRG', m.initial_screen[5])
        self.assertIn('HELLO.PRG', m.initial_screen[5][41:])
        self.assertIn('READ ONLY', m.initial_screen[23])
        self.assertEqual(m.byte('selected'), 19)
        self.assertEqual(m.byte('scroll'), 5)
        self.assertEqual(m.mem[SYMS['selected'] + 1], 17)
        self.assertEqual(m.mem[SYMS['scroll'] + 1], 2)
        self.assertFalse(m.opened)
        self.assertEqual(m.calls.count(0x16), 1)
        # Full application also exits gracefully after root-open failure.
        m = Machine(fail={0x3c: 0x82}, keys=[0x11, 9, 0x11, ord('X')])
        m.call('main')
        self.assertEqual(m.byte('selected'), 0)
        self.assertEqual(m.mem[SYMS['selected'] + 1], 1)
        self.assertIn('SD ACCESS ERROR', m.initial_screen[23])
        self.assertIn('$82', m.initial_screen[23])


if __name__ == '__main__':
    unittest.main(verbosity=2)
