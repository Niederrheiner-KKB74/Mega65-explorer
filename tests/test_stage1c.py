"""Stage 1c assembled-code tests; simulated HDOS cwd/tree, not XEMU."""
import unittest
from test_stage1b import Machine, SYMS, entry


class TreeMachine(Machine):
    def __init__(self, tree, **kwargs):
        super().__init__(**kwargs)
        self.mem[self.guard:self.guard + 32] = [0] * 32
        self.guard = SYMS['vfs_staging_end']
        self.mem[self.guard:self.guard + 32] = [0xa5] * 32
        self.cwd = '/'
        self.tree = tree
        self.directory_ids = {i + 1: path for i, path in enumerate(tree)}
        self.faults = {}
        self.last_entry = None
        self.open_path = None
        self.read_index = 0

    def add_fault(self, op, cwd, *outcomes):
        self.faults[(op, cwd)] = list(outcomes)

    def hdos(self):
        c = self.cpu
        op = c.a
        self.calls.append(op)
        assert op in (2, 0x3c, 0x12, 0x14, 0x16, 0x0c), hex(op)
        c.p |= c.CARRY
        outcomes = self.faults.get((op, self.cwd), [])
        if outcomes:
            outcome = outcomes.pop(0)
            if outcome is not None:
                c.a = outcome
                c.p &= ~c.CARRY
                return
        if op == 2:
            c.a = 0
        elif op == 0x3c:
            assert c.x == 0 and not self.opened
            self.cwd = '/'
        elif op == 0x12:
            assert not self.opened
            self.opened = True
            self.open_path = self.cwd
            self.read_index = 0
            c.a = 2
        elif op == 0x14:
            assert self.opened and c.x == 2
            assert c.y * 256 == SYMS['fat32_transfer']
            records = self.tree[self.open_path]
            if self.read_index >= len(records):
                c.a = 0xff
                c.p &= ~c.CARRY
            else:
                alias, attr, size = records[self.read_index]
                self.read_index += 1
                b = entry(alias, attr, size)
                path = self.open_path.rstrip('/') + '/' + alias.upper()
                if attr & 16 and path in self.tree:
                    number = next(n for n, p in self.directory_ids.items() if p == path)
                    b[0x4e:0x52] = number.to_bytes(4, 'little')
                self.last_entry = b
                start = c.y * 256
                self.mem[start:start + 87] = b
        elif op == 0x16:
            assert self.opened and c.x == 2
            self.opened = False
        elif op == 0x0c:
            assert not self.opened, 'CHDIR must not leak enumeration descriptor'
            assert self.last_entry and self.last_entry[0x56] & 16
            number = int.from_bytes(self.last_entry[0x4e:0x52], 'little')
            self.cwd = self.directory_ids[number]

    def path(self):
        address = SYMS['vfs_path']
        raw = bytes(self.mem[address:address + 97]).split(b'\x00', 1)[0]
        return raw.decode()

    def record(self, index=0):
        address = self.mem[SYMS['directory_lo']] + 256 * self.mem[SYMS['directory_hi']]
        return self.mem[address + 24 * index:address + 24 * (index + 1)]

    def start(self):
        self.call('vfs_init')
        self.call('navigation_init')
        return self


class Stage1c(unittest.TestCase):
    def tree(self):
        return {'/': [('GAMES', 16, 0), ('FILE.PRG', 32, 123)],
                '/GAMES': [('ARCADE', 16, 0)],
                '/GAMES/ARCADE': [('SHOOTERS', 16, 0)],
                '/GAMES/ARCADE/SHOOTERS': []}

    def test_nested_empty_parent_and_root_noop(self):
        m = TreeMachine(self.tree()).start()
        before = list(m.calls)
        self.assertEqual(m.call('navigation_parent'), 0)
        self.assertEqual(m.calls, before)
        for path in ('/GAMES', '/GAMES/ARCADE', '/GAMES/ARCADE/SHOOTERS'):
            self.assertEqual(m.call('navigation_enter'), 1)
            self.assertEqual(m.path(), path)
            self.assertEqual(m.cwd, path)
            self.assertEqual(m.byte('selected'), 0)
            self.assertFalse(m.opened)
        self.assertEqual(m.byte('entry_counts'), 0)
        self.assertEqual(m.byte('vfs_status'), 1)
        for path in ('/GAMES/ARCADE', '/GAMES', '/'):
            m.call('navigation_parent')
            self.assertEqual(m.path(), path)
            self.assertEqual(m.cwd, path)
        self.assertEqual(m.byte('vfs_depth'), 0)

    def test_parent_restores_selection_scroll_and_right_state(self):
        tree = {'/': [(f'F{i:07}.PRG', 32, 0) for i in range(20)] + [('SUB', 16, 0)],
                '/SUB': [('A.PRG', 32, 0)]}
        m = TreeMachine(tree).start()
        for _ in range(20):
            m.call('navigation_down')
        self.assertEqual((m.byte('selected'), m.byte('scroll')), (20, 5))
        m.mem[SYMS['selected'] + 1] = 17
        m.mem[SYMS['scroll'] + 1] = 2
        m.call('navigation_enter')
        m.call('navigation_parent')
        self.assertEqual((m.byte('selected'), m.byte('scroll')), (20, 5))
        self.assertEqual(m.mem[SYMS['selected'] + 1], 17)
        self.assertEqual(m.mem[SYMS['scroll'] + 1], 2)

    def test_files_and_inactive_panel_have_no_hdos_effect(self):
        m = TreeMachine(self.tree()).start()
        m.call('navigation_down')
        before = list(m.calls)
        self.assertEqual(m.call('navigation_enter'), 0)
        m.call('navigation_tab')
        self.assertEqual(m.call('navigation_enter'), 0)
        self.assertEqual(m.call('navigation_parent'), 0)
        self.assertEqual(m.calls, before)

    def test_maximum_depth_and_path_length(self):
        for component, limit, expected_status in [('A', 8, 4), ('ABCDEFGH.XYZ', 7, 5)]:
            tree = {}
            path = '/'
            for _ in range(10):
                tree[path] = [(component, 16, 0)]
                path = path.rstrip('/') + '/' + component
            tree[path] = []
            m = TreeMachine(tree).start()
            for _ in range(limit):
                m.call('navigation_enter')
                self.assertEqual(m.path(), m.cwd)
            self.assertEqual(m.byte('vfs_depth'), limit)
            old_path, calls = m.path(), list(m.calls)
            m.call('navigation_enter')
            self.assertEqual(m.byte('vfs_status'), expected_status)
            self.assertEqual(m.path(), old_path)
            self.assertEqual(m.calls, calls)
            self.assertLessEqual(len(m.path()), 96)
            for _ in range(limit):
                m.call('navigation_parent')
            self.assertEqual(m.path(), '/')

    def test_exact_96_character_path_and_closedir_failure(self):
        tree = {}
        path = '/'
        for component in ['ABCDEFGH.XYZ'] * 7 + ['LAST']:
            tree[path] = [(component, 16, 0)]
            path = path.rstrip('/') + '/' + component
        tree[path] = []
        m = TreeMachine(tree).start()
        for _ in range(8):
            m.call('navigation_enter')
        self.assertEqual(len(m.path()), 96)
        self.assertEqual(m.path(), m.cwd)
        m.call('navigation_parent')
        self.assertEqual(len(m.path()), 91)
        # Persistent cleanup failures disable navigation, retaining handle for X.
        m = TreeMachine(self.tree()).start()
        m.add_fault(0x16, '/', 0x89, 0x89, 0x89)
        m.call('navigation_enter')
        self.assertEqual(m.byte('vfs_context_valid'), 0)
        self.assertTrue(m.opened)
        m.call('vfs_close')
        self.assertFalse(m.opened)

    def test_unsupported_alias_is_rejected(self):
        m = TreeMachine({'/': [('BAD\x01', 16, 0)]}).start()
        calls = list(m.calls)
        m.call('navigation_enter')
        self.assertEqual(m.byte('vfs_status'), 6)
        self.assertEqual(m.path(), '/')
        self.assertEqual(m.calls, calls)

    def test_failed_chdir_preserves_snapshot_and_path(self):
        m = TreeMachine(self.tree()).start()
        record = m.record()
        m.add_fault(0x0c, '/', 0x87)
        m.call('navigation_enter')
        self.assertEqual(m.path(), '/')
        self.assertEqual(m.cwd, '/')
        self.assertEqual(m.byte('vfs_depth'), 0)
        self.assertEqual(m.record(), record)
        self.assertEqual(m.byte('vfs_error'), 0x87)
        self.assertFalse(m.opened)

    def test_read_failure_after_chdir_rolls_back(self):
        for op in (0x12, 0x14, 0x16):
            m = TreeMachine(self.tree()).start()
            before = (m.record(), m.byte('entry_counts'))
            m.add_fault(op, '/GAMES', 0x20)
            m.call('navigation_enter')
            self.assertEqual(m.path(), '/')
            self.assertEqual(m.cwd, '/')
            self.assertEqual((m.record(), m.byte('entry_counts')), before)
            self.assertEqual(m.byte('vfs_depth'), 0)
            self.assertEqual(m.byte('vfs_error'), 0x20)
            self.assertFalse(m.opened)

    def test_failed_parent_read_keeps_child_and_history(self):
        m = TreeMachine(self.tree()).start()
        m.call('navigation_enter')
        old = (m.path(), m.record(), m.byte('vfs_depth'))
        # Parent has no components; its first open is the parent reload.
        m.add_fault(0x12, '/', 0x20)
        m.call('navigation_parent')
        self.assertEqual((m.path(), m.record(), m.byte('vfs_depth')), old)
        self.assertEqual(m.cwd, '/GAMES')
        m.call('navigation_parent')
        self.assertEqual(m.path(), '/')

    def test_failed_rollback_falls_back_to_root(self):
        m = TreeMachine(self.tree()).start()
        m.call('navigation_enter')
        m.add_fault(0x14, '/GAMES/ARCADE', 0x20)
        m.add_fault(0x0c, '/', None, 0x88)
        m.call('navigation_enter')
        self.assertEqual(m.path(), '/')
        self.assertEqual(m.cwd, '/')
        self.assertEqual(m.byte('vfs_depth'), 0)
        self.assertEqual(m.byte('selected'), 0)
        self.assertEqual(bytes(m.record()[4:]).decode().strip(), 'GAMES')
        self.assertEqual(m.byte('vfs_error'), 0x20)

    def test_root_recovery_failure_disables_navigation(self):
        m = TreeMachine(self.tree()).start()
        m.add_fault(0x14, '/GAMES', 0x20)
        m.add_fault(0x3c, '/GAMES', 0x80, 0x80)
        m.call('navigation_enter')
        self.assertEqual(m.path(), '?')
        self.assertEqual(m.byte('vfs_context_valid'), 0)
        self.assertEqual(m.byte('entry_counts'), 0)
        calls = list(m.calls)
        self.assertEqual(m.call('navigation_enter'), 0)
        self.assertEqual(m.call('navigation_parent'), 0)
        self.assertEqual(m.calls, calls)
        m.call('vfs_close')
        self.assertFalse(m.opened)

    def test_large_child_and_clv_variants(self):
        for count in (20, 128, 129):
            for skip in (False, True):
                tree = {'/': [('SUB', 16, 0)],
                        '/SUB': [(f'F{i:07}.PRG', 32, 1024) for i in range(count)]}
                m = TreeMachine(tree, skip_clv=skip).start()
                m.call('navigation_enter')
                self.assertEqual(m.byte('entry_counts'), min(128, count))
                self.assertEqual(m.byte('vfs_status'), 2 if count > 128 else 0)
                for _ in range(30):
                    m.call('navigation_down')
                self.assertGreater(m.byte('scroll'), 0)
                m.call('navigation_parent')
                self.assertEqual(m.path(), '/')

    def test_tail_title_and_full_input_event_loop(self):
        m = TreeMachine(self.tree(), keys=[13, 13, 13, 20, 20, 20, 9, 13, 20, ord('X')])
        m.call('main')
        self.assertEqual(m.cwd, '/')
        self.assertEqual(m.path(), '/')
        self.assertFalse(m.opened)
        self.assertEqual(m.byte('active_panel'), 1)
        # Render a full-width shortened title without changing the internal path.
        path = '/ABCDEFGH.XYZ/ABCDEFGH.XYZ/ABCDEFGH.XYZ'
        m.mem[SYMS['vfs_path']:SYMS['vfs_path'] + len(path) + 1] = list(path.encode()) + [0]
        m.mem[SYMS['vfs_path_length']] = len(path)
        m.call('panels_build_title')
        title = bytes(m.mem[SYMS['left_title']:SYMS['left_title'] + 37]).decode()
        self.assertEqual(title, 'SD: ...' + path[-30:])
        self.assertEqual(m.path(), path)


if __name__ == '__main__':
    unittest.main(verbosity=2)
