"""Run from the kitty config dir: python3 -m unittest workspaces.test_workspaces -v

No kitty needed: kitten @ calls are mocked where they occur.
"""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from unittest import mock

from workspaces import actions, kitty_cmd as kc, kitty_remote as kr, ops, storage
from workspaces.models import STATE_DETACHED, STATE_OPEN, Tab, Window, Workspace


class _StoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self._env = mock.patch.dict(
            os.environ, {"KITTY_WORKSPACES_DIR": self._tmp.name}
        )
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()


class StorageTests(_StoreTest):
    def test_roundtrip(self) -> None:
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", "/tmp")
        ops.add_window(ws, "logs", None)
        storage.save(ws)
        self.assertEqual(storage.load(ws.id), ws)

    def test_one_file_per_workspace(self) -> None:
        a, b = ops.new_workspace("a"), ops.new_workspace("b")
        storage.save(a)
        storage.save(b)
        self.assertEqual(
            sorted(os.listdir(self._tmp.name)), sorted([f"{a.id}.json", f"{b.id}.json"])
        )

    def test_list_is_sorted_by_label(self) -> None:
        storage.save(ops.new_workspace("zeta"))
        storage.save(ops.new_workspace("Alpha"))
        self.assertEqual([w.label for w in storage.list_all()], ["Alpha", "zeta"])

    def test_missing_dir_and_missing_file(self) -> None:
        self.assertEqual(storage.list_all(), [])
        self.assertIsNone(storage.load("ws-00000000"))

    def test_rejects_bad_ids(self) -> None:
        for bad in ["../x", "ws-zz", "api", "", "ws-1234567", "win-12345678/../x"]:
            with self.subTest(id=bad), self.assertRaises(ValueError):
                storage.validate_id(bad)

    def test_rejects_unknown_schema_version(self) -> None:
        path = os.path.join(self._tmp.name, "ws-00000001.json")
        with open(path, "w") as f:
            json.dump({"version": 99, "id": "ws-00000001", "label": "x", "tabs": []}, f)
        with self.assertRaises(ValueError):
            storage.load("ws-00000001")

    def test_save_is_atomic_no_tmp_left(self) -> None:
        ws = ops.new_workspace("ws")
        storage.save(ws)
        self.assertEqual(os.listdir(self._tmp.name), [f"{ws.id}.json"])

    def test_delete(self) -> None:
        ws = ops.new_workspace("ws")
        storage.save(ws)
        self.assertTrue(storage.delete(ws.id))
        self.assertFalse(storage.delete(ws.id))


class OpsTests(unittest.TestCase):
    def test_new_ids_are_valid(self) -> None:
        ws = ops.new_workspace("x")
        storage.validate_id(ws.id)
        win = ops.add_window(ws, "w", None)
        storage.validate_id(win.id)
        storage.validate_id(ws.tabs[0].id)

    def test_add_window_starts_new_tab_then_joins_tab(self) -> None:
        ws = ops.new_workspace("x")
        first = ops.add_window(ws, "a", None)
        tab_id = ws.tabs[0].id
        second = ops.add_window(ws, "b", None, tab_id=tab_id)
        self.assertEqual(len(ws.tabs), 1)
        self.assertEqual([w.id for w in ws.tabs[0].windows], [first.id, second.id])
        ops.add_window(ws, "c", None)
        self.assertEqual(len(ws.tabs), 2)

    def test_new_windows_are_open(self) -> None:
        ws = ops.new_workspace("x")
        self.assertEqual(ops.add_window(ws, "a", None).state, STATE_OPEN)

    def test_set_state_and_find(self) -> None:
        ws = ops.new_workspace("x")
        win = ops.add_window(ws, "a", None)
        self.assertTrue(ops.set_state(ws, win.id, STATE_DETACHED))
        self.assertEqual(ops.find_window(ws, win.id)[1].state, STATE_DETACHED)
        self.assertFalse(ops.set_state(ws, "win-00000000", STATE_OPEN))

    def test_tab_detached_only_when_all_windows_detached(self) -> None:
        tab = Tab(
            "tab-00000001",
            "t",
            [
                Window("win-00000001", "a", state=STATE_DETACHED),
                Window("win-00000002", "b", state=STATE_OPEN),
            ],
        )
        self.assertFalse(tab.detached)
        tab.windows[1].state = STATE_DETACHED
        self.assertTrue(tab.detached)

    def test_remove_window_drops_empty_tab(self) -> None:
        ws = ops.new_workspace("x")
        a = ops.add_window(ws, "a", None)
        b = ops.add_window(ws, "b", None, tab_id=ws.tabs[0].id)
        ops.add_window(ws, "c", None)
        self.assertTrue(ops.remove_window(ws, a.id))
        self.assertEqual(len(ws.tabs), 2)
        self.assertTrue(ops.remove_window(ws, b.id))
        self.assertEqual(len(ws.tabs), 1)  # tab with only c remains
        self.assertFalse(ops.remove_window(ws, b.id))

    def test_rename_keeps_id(self) -> None:
        ws = ops.new_workspace("old")
        before = ws.id
        ops.rename(ws, "new")
        self.assertEqual((ws.id, ws.label), (before, "new"))


# A captured-shape `kitten @ ls`, trimmed to the keys we read.
LS = [
    {
        "id": 1,
        "is_focused": False,
        "tabs": [
            {
                "id": 10,
                "title": "other",
                "windows": [{"id": 99, "cwd": "/elsewhere", "user_vars": {}}],
            },
        ],
    },
    {
        "id": 2,
        "is_focused": True,
        "tabs": [
            {
                "id": 20,
                "title": "editor",
                "windows": [
                    {
                        "id": 5,
                        "cwd": "/src/app",
                        "user_vars": {
                            "kitty_workspace": "ws-aaaaaaaa",
                            "kitty_window": "win-11111111",
                        },
                    },
                    {
                        "id": 7,
                        "cwd": "/src/app",
                        "user_vars": {
                            "kitty_workspace": "ws-aaaaaaaa",
                            "kitty_window": "win-22222222",
                        },
                    },
                ],
            },
            {
                "id": 21,
                "title": "shell",
                "windows": [{"id": 8, "cwd": None, "user_vars": {}}],
            },
        ],
    },
]


class KittyRemoteTests(unittest.TestCase):
    def test_launch_argv_os_window_with_title_and_cwd(self) -> None:
        argv = kc.launch_argv(
            kind="os-window",
            cmd=["zmx", "attach", "win-1"],
            cwd="/tmp",
            tab_title="api",
        )
        self.assertEqual(
            argv,
            [
                "launch",
                "--type=os-window",
                "--tab-title",
                "api",
                "--cwd",
                "/tmp",
                "zmx",
                "attach",
                "win-1",
            ],
        )

    def test_launch_argv_skips_missing_cwd(self) -> None:
        argv = kc.launch_argv(
            kind="tab", cmd=["zmx"], cwd="/nope-not-a-dir-xyz", match="id:4"
        )
        self.assertNotIn("--cwd", argv)
        self.assertEqual(argv[:4], ["launch", "--type=tab", "--match", "id:4"])

    def test_launch_argv_split(self) -> None:
        argv = kc.launch_argv(
            kind="window", cmd=["zmx"], match="id:4", location="vsplit"
        )
        self.assertEqual(argv[argv.index("--location") + 1], "vsplit")

    def test_placement_from_args_ignores_kitten_path(self) -> None:
        # kitty passes the kitten's own path as args[0]
        self.assertEqual(kc.placement_from_args(["new_window.py"]), "tab")
        self.assertEqual(kc.placement_from_args(["new_window.py", "vsplit"]), "vsplit")
        self.assertEqual(kc.placement_from_args(["new_window.py", "hsplit"]), "hsplit")
        self.assertEqual(
            kc.placement_from_args(["/abs/path/new_window.py", "tab"]), "tab"
        )
        self.assertEqual(kc.placement_from_args([]), "tab")

    def test_set_vars_and_focus_argv(self) -> None:
        self.assertEqual(
            kc.set_vars_argv(9, "ws-aaaaaaaa", "win-11111111"),
            [
                "set-user-vars",
                "--match",
                "id:9",
                "kitty_workspace=ws-aaaaaaaa",
                "kitty_window=win-11111111",
            ],
        )
        self.assertEqual(
            kc.focus_argv("ws-aaaaaaaa"),
            ["focus-window", "--match", "var:kitty_workspace=ws-aaaaaaaa"],
        )

    def test_windows_of_workspace_and_current(self) -> None:
        found = kc.windows_of_workspace(LS, "ws-aaaaaaaa")
        self.assertEqual([w["id"] for w in found], [5, 7])
        self.assertEqual(kc.current_workspace_id(LS, 5), "ws-aaaaaaaa")
        self.assertIsNone(kc.current_workspace_id(LS, 8))
        self.assertIsNone(kc.current_workspace_id(LS, None))
        self.assertIsNone(kc.window_cwd(LS, 99999))
        self.assertEqual(kc.window_cwd(LS, 5), "/src/app")


class FakeKitty:
    """Records kitten @ calls; hands out increasing window IDs for launches."""

    def __init__(self, ls_state: list) -> None:
        self.ls_state = ls_state
        self.calls: list[list[str]] = []
        self._next = 100

    def __call__(self, args: list[str]) -> str:
        self.calls.append(args)
        if args[0] == "ls":
            return json.dumps(self.ls_state)
        if args[0] == "launch":
            self._next += 1
            return str(self._next)
        return ""


class OpenWorkspaceTests(_StoreTest):
    def _ws(self) -> Workspace:
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", None)
        ops.add_window(ws, "logs", None, tab_id=ws.tabs[0].id)
        ops.add_window(ws, "shell", None)
        for tab in ws.tabs:
            for w in tab.windows:
                w.state = STATE_DETACHED
        storage.save(ws)
        return ws

    def test_opens_tabs_into_anchor_os_window_and_marks_open(self) -> None:
        ws = self._ws()
        fake = FakeKitty([])
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(kr.open_workspace(ws, anchor=1), "opened")
        launches = [c for c in fake.calls if c[0] == "launch"]
        # tab1: editor (new tab) + logs (split); tab2: shell (new tab). No os-window launches.
        self.assertEqual(
            [c[1] for c in launches], ["--type=tab", "--type=window", "--type=tab"]
        )
        self.assertIn("--match", launches[0])
        self.assertEqual(launches[0][launches[0].index("--match") + 1], "id:1")
        self.assertFalse(any("os-window" in c for c in launches))
        sets = [c for c in fake.calls if c[0] == "set-user-vars"]
        self.assertEqual(len(sets), 3)
        for c in sets:
            self.assertIn("kitty_workspace=" + ws.id, c)
        saved = storage.load(ws.id)
        self.assertTrue(
            all(w.state == STATE_OPEN for t in saved.tabs for w in t.windows)
        )

    def test_focuses_instead_when_already_open(self) -> None:
        ws = self._ws()
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [{"id": 3, "user_vars": {"kitty_workspace": ws.id}}],
                    }
                ],
            }
        ]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(kr.open_workspace(ws, anchor=3), "focused")
        self.assertFalse(any(c[0] == "launch" for c in fake.calls))
        self.assertIn(
            ["focus-window", "--match", f"var:kitty_workspace={ws.id}"], fake.calls
        )

    def _anchor_with(self, state: list, parents: list | None, self_id: str) -> int | None:
        import os as _os

        def fake(args: list[str]) -> str:
            if args[-1] == "state:overlay_parent":
                if parents is None:
                    raise RuntimeError("kitten @ ls failed: No matching windows for expression: state:overlay_parent")
                return json.dumps([{"id": 1, "tabs": [{"id": 2, "windows": [{"id": i} for i in parents]}]}])
            return json.dumps(state)

        with mock.patch.dict(_os.environ, {"KITTY_WINDOW_ID": self_id}), mock.patch.object(
            kr, "_run", side_effect=fake
        ):
            return kr.anchor_id()

    def test_anchor_is_the_window_itself_when_not_an_overlay(self) -> None:
        # The self-test case: the window it runs in has no overlay; another tab has one.
        state = [{"id": 1, "tabs": [
            {"id": 2, "windows": [{"id": 25, "user_vars": {}}]},
            {"id": 3, "windows": [{"id": 39, "user_vars": {}}]},
        ]}]
        self.assertEqual(self._anchor_with(state, parents=[39], self_id="25"), 25)

    def test_anchor_is_the_overlay_parent_in_the_same_tab(self) -> None:
        # The picker overlay (id 9) sits over window 4 in the same tab.
        state = [{"id": 1, "tabs": [
            {"id": 2, "windows": [{"id": 4, "user_vars": {}}, {"id": 9, "user_vars": {}}]},
        ]}]
        self.assertEqual(self._anchor_with(state, parents=[4], self_id="9"), 4)

    def test_anchor_falls_back_to_self_when_nothing_has_an_overlay(self) -> None:
        state = [{"id": 1, "tabs": [{"id": 2, "windows": [{"id": 7, "user_vars": {}}]}]}]
        self.assertEqual(self._anchor_with(state, parents=None, self_id="7"), 7)

    def test_kill_tolerates_window_already_closed_by_zmx_kill(self) -> None:
        # zmx kill ends the shell, kitty closes the window, then close-window finds nothing.
        ws = ops.new_workspace("w")
        win = ops.add_window(ws, "a", None)
        storage.save(ws)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {
                                "id": 54,
                                "user_vars": {
                                    "kitty_workspace": ws.id,
                                    "kitty_window": win.id,
                                },
                            }
                        ],
                    }
                ],
            }
        ]

        def fake(args: list[str]) -> str:
            if args[0] == "ls":
                return json.dumps(state)
            if args[0] == "close-window":
                raise RuntimeError(
                    "kitten @ close-window --match failed: Error: No matching windows for expression: id:54"
                )
            return ""

        with mock.patch.object(kr, "_run", side_effect=fake), mock.patch.object(
            actions.subprocess, "run"
        ) as zmx_kill:
            self.assertTrue(actions.kill_window(54))
        zmx_kill.assert_called_once()
        self.assertEqual(zmx_kill.call_args[0][0][1:], ["kill", win.id])
        self.assertEqual(
            storage.load(ws.id).tabs, []
        )  # the killed window is gone from the store

    def test_empty_workspace_gets_a_shell_and_placeholder_closes_only_after_launch(
        self,
    ) -> None:
        ws = ops.new_workspace("empty")
        storage.save(ws)  # no windows: what a killed-out workspace looks like on disk
        fake = FakeKitty(
            [{"id": 1, "tabs": [{"id": 2, "windows": [{"id": 5, "user_vars": {}}]}]}]
        )
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(
                kr.open_workspace(ws, anchor=5, close_anchor=True), "opened"
            )
        launches = [c for c in fake.calls if c[0] == "launch"]
        self.assertEqual(len(launches), 1)
        self.assertEqual(launches[0][launches[0].index("--match") + 1], "id:5")
        self.assertEqual(len(storage.load(ws.id).tabs), 1)
        self.assertIn(["close-window", "--match", "id:5"], fake.calls)

    def test_placeholder_anchor_closed_only_when_asked(self) -> None:
        # cmd+n: the picker's own window (id 5) is an empty placeholder with no workspace.
        ws = self._ws()
        state = [
            {"id": 1, "tabs": [{"id": 2, "windows": [{"id": 5, "user_vars": {}}]}]}
        ]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            kr.open_workspace(ws, anchor=5, close_anchor=True)
        closes = [c for c in fake.calls if c[0] == "close-window"]
        self.assertEqual(closes, [["close-window", "--match", "id:5"]])

        fake2 = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake2):
            kr.open_workspace(self._ws(), anchor=5, close_anchor=False)
        self.assertFalse(any(c[0] == "close-window" for c in fake2.calls))

    def test_focus_from_placeholder_closes_it(self) -> None:
        ws = self._ws()
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {"id": 3, "user_vars": {"kitty_workspace": ws.id}},
                            {"id": 5, "user_vars": {}},
                        ],
                    }
                ],
            }
        ]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(
                kr.open_workspace(ws, anchor=5, close_anchor=True), "focused"
            )
        self.assertIn(["close-window", "--match", "id:5"], fake.calls)

    def test_create_workspace_is_detached_until_opened(self) -> None:
        ws = actions.create_workspace()
        saved = storage.load(ws.id)
        self.assertEqual(len(saved.tabs), 1)
        self.assertEqual(
            [w.state for t in saved.tabs for w in t.windows], [STATE_DETACHED]
        )

    def test_switch_detaches_and_closes_previous_workspace_anchor_last(self) -> None:
        # The user's window (anchor, id 3) belongs to workspace B; a split (id 4) is also B's.
        old = ops.new_workspace("old")
        a = ops.add_window(old, "a", None)
        b = ops.add_window(old, "b", None, tab_id=old.tabs[0].id)
        storage.save(old)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {
                                "id": 3,
                                "user_vars": {
                                    "kitty_workspace": old.id,
                                    "kitty_window": a.id,
                                },
                            },
                            {
                                "id": 4,
                                "user_vars": {
                                    "kitty_workspace": old.id,
                                    "kitty_window": b.id,
                                },
                            },
                        ],
                    }
                ],
            }
        ]
        ws = self._ws()
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(kr.open_workspace(ws, anchor=3), "opened")
        closes = [c for c in fake.calls if c[0] == "close-window"]
        self.assertEqual(
            closes,
            [["close-window", "--match", "id:4"], ["close-window", "--match", "id:3"]],
        )
        saved_old = storage.load(old.id)
        self.assertTrue(
            all(w.state == STATE_DETACHED for t in saved_old.tabs for w in t.windows)
        )
        self.assertTrue(
            all(
                w.state == STATE_OPEN
                for t in storage.load(ws.id).tabs
                for w in t.windows
            )
        )


class LifecycleTests(_StoreTest):
    def test_mark_closed_detaches_and_ignores_unknown(self) -> None:
        ws = ops.new_workspace("x")
        win = ops.add_window(ws, "a", None)
        storage.save(ws)
        self.assertTrue(actions.mark_closed(ws.id, win.id))
        self.assertEqual(storage.load(ws.id).tabs[0].windows[0].state, STATE_DETACHED)
        self.assertFalse(
            actions.mark_closed(ws.id, "win-00000000")
        )  # killed earlier: no-op
        self.assertFalse(actions.mark_closed("ws-00000000", win.id))

    def test_rename_workspace(self) -> None:
        ws = ops.new_workspace("old")
        storage.save(ws)
        actions.rename_workspace(ws.id, "new")
        self.assertEqual(storage.load(ws.id).label, "new")
        self.assertRaises(KeyError, actions.rename_workspace, "ws-00000000", "x")


class NewBehaviourTests(_StoreTest):
    def test_open_ids_roundtrip_and_order(self) -> None:
        self.assertEqual(storage.load_open_ids(), [])
        storage.add_open_id("ws-00000001")
        storage.add_open_id("ws-00000002")
        storage.add_open_id("ws-00000001")  # no duplicates
        self.assertEqual(storage.load_open_ids(), ["ws-00000001", "ws-00000002"])
        storage.remove_open_id("ws-00000001")
        self.assertEqual(storage.load_open_ids(), ["ws-00000002"])
        # the open list is not a workspace
        self.assertEqual(storage.list_all(), [])

    def _reattach_fixture(self):
        ws = ops.new_workspace("api")
        a = ops.add_window(ws, "editor", None)
        b = ops.add_window(ws, "logs", None, tab_id=ws.tabs[0].id)  # split in tab 1
        c = ops.add_window(ws, "shell", None)  # tab 2
        ops.set_state(ws, b.id, STATE_DETACHED)
        ops.set_state(ws, c.id, STATE_DETACHED)
        storage.save(ws)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {"id": 5, "user_vars": {"kitty_workspace": ws.id, "kitty_window": a.id}}
                        ],
                    }
                ],
            }
        ]
        return ws, a, b, c, state

    def test_open_of_an_open_workspace_only_focuses(self) -> None:
        # No automatic restore: detached windows stay detached until reattached on purpose.
        ws, a, b, c, state = self._reattach_fixture()
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(kr.open_workspace(ws, anchor=5), "focused")
        self.assertFalse(any(c_[0] == "launch" for c_ in fake.calls))
        self.assertEqual(
            {w.id: w.state for t in storage.load(ws.id).tabs for w in t.windows},
            {a.id: STATE_OPEN, b.id: STATE_DETACHED, c.id: STATE_DETACHED},
        )

    def test_reattach_window_beside_its_open_sibling(self) -> None:
        ws, a, b, c, state = self._reattach_fixture()
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(kr.reattach_window(ws.id, b.id), "reattached")
        launches = [c_ for c_ in fake.calls if c_[0] == "launch"]
        self.assertEqual(len(launches), 1)
        self.assertEqual(launches[0][1], "--type=window")
        self.assertEqual(launches[0][launches[0].index("--match") + 1], "id:5")
        states = {w.id: w.state for t in storage.load(ws.id).tabs for w in t.windows}
        self.assertEqual(states[b.id], STATE_OPEN)
        self.assertEqual(states[c.id], STATE_DETACHED)  # only the one chosen came back

    def test_reattach_window_as_new_tab_when_its_tab_has_nothing_open(self) -> None:
        ws, a, b, c, state = self._reattach_fixture()
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            kr.reattach_window(ws.id, c.id)
        launches = [c_ for c_ in fake.calls if c_[0] == "launch"]
        self.assertEqual(launches[0][1], "--type=tab")
        self.assertEqual(launches[0][launches[0].index("--match") + 1], "id:5")

    def test_reattach_refuses_a_closed_workspace_and_an_open_window(self) -> None:
        ws, a, b, c, state = self._reattach_fixture()
        with mock.patch.object(kr, "_run", side_effect=FakeKitty([])):
            with self.assertRaises(RuntimeError):
                kr.reattach_window(ws.id, b.id)
        with mock.patch.object(kr, "_run", side_effect=FakeKitty(state)):
            with self.assertRaises(RuntimeError):
                kr.reattach_window(ws.id, a.id)

    def test_detached_windows_lists_only_windows_not_open(self) -> None:
        ws, a, b, c, state = self._reattach_fixture()
        other = ops.new_workspace("closed one")
        d = ops.add_window(other, "d", None)
        ops.set_state(other, d.id, STATE_DETACHED)
        storage.save(other)
        items = actions.detached_windows(state)
        self.assertEqual(
            sorted((i["win_id"], i["ws_open"]) for i in items),
            sorted([(b.id, True), (c.id, True), (d.id, False)]),
        )

    def test_prune_removes_from_store_ends_zmx_and_refuses_open(self) -> None:
        ws, a, b, c, state = self._reattach_fixture()
        with mock.patch.object(actions.subprocess, "run") as zmx, mock.patch.object(
            kr, "_run", side_effect=FakeKitty(state)
        ):
            actions.prune_window(ws.id, c.id)
            with self.assertRaises(RuntimeError):
                actions.prune_window(ws.id, a.id)  # open: refused
        zmx.assert_called_once()
        self.assertEqual(zmx.call_args[0][0][1:], ["kill", c.id])
        remaining = [w.id for t in storage.load(ws.id).tabs for w in t.windows]
        self.assertNotIn(c.id, remaining)
        self.assertIn(a.id, remaining)

    def test_new_os_window_for_startup_restore(self) -> None:
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", None)
        ops.add_window(ws, "logs", None, tab_id=ws.tabs[0].id)
        storage.save(ws)
        fake = FakeKitty([])
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(
                kr.open_workspace(ws, anchor=None, new_os_window=True), "opened"
            )
        launches = [c for c in fake.calls if c[0] == "launch"]
        self.assertEqual(
            [c[1] for c in launches], ["--type=os-window", "--type=window"]
        )
        self.assertEqual(launches[1][launches[1].index("--match") + 1], "id:101")
        self.assertIn(storage.load_open_ids(), [[ws.id]])

    def test_kill_workspace_closes_windows_anchor_last_and_deletes(self) -> None:
        ws = ops.new_workspace("gone")
        a = ops.add_window(ws, "a", None)
        b = ops.add_window(ws, "b", None)
        storage.save(ws)
        storage.add_open_id(ws.id)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {
                                "id": 3,
                                "user_vars": {
                                    "kitty_workspace": ws.id,
                                    "kitty_window": a.id,
                                },
                            },
                            {
                                "id": 4,
                                "user_vars": {
                                    "kitty_workspace": ws.id,
                                    "kitty_window": b.id,
                                },
                            },
                        ],
                    }
                ],
            }
        ]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake), mock.patch.object(
            actions.subprocess, "run"
        ) as zmx_kill:
            self.assertEqual(actions.kill_workspace(ws.id, anchor=3), 2)
        self.assertIsNone(storage.load(ws.id))
        self.assertEqual(storage.load_open_ids(), [])
        killed = [c[0][0][1:] for c in zmx_kill.call_args_list]
        self.assertEqual(killed, [["kill", a.id], ["kill", b.id]])
        closes = [c for c in fake.calls if c[0] == "close-window"]
        self.assertEqual(
            closes,
            [["close-window", "--match", "id:4"], ["close-window", "--match", "id:3"]],
        )

    def test_close_workspace_window_detaches_and_leaves_plain_windows(self) -> None:
        ws = ops.new_workspace("api")
        a = ops.add_window(ws, "a", None)
        b = ops.add_window(ws, "b", None, tab_id=ws.tabs[0].id)
        storage.save(ws)
        storage.add_open_id(ws.id)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {
                                "id": 3,
                                "user_vars": {
                                    "kitty_workspace": ws.id,
                                    "kitty_window": a.id,
                                },
                            },
                            {
                                "id": 4,
                                "user_vars": {
                                    "kitty_workspace": ws.id,
                                    "kitty_window": b.id,
                                },
                            },
                            {
                                "id": 9,
                                "user_vars": {},
                            },  # plain shell in the same OS window
                        ],
                    }
                ],
            }
        ]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(actions.close_workspace_window(anchor=3), 2)
        closes = [c for c in fake.calls if c[0] == "close-window"]
        self.assertEqual(
            closes,
            [["close-window", "--match", "id:4"], ["close-window", "--match", "id:3"]],
        )
        self.assertTrue(
            all(
                w.state == STATE_DETACHED
                for t in storage.load(ws.id).tabs
                for w in t.windows
            )
        )
        self.assertEqual(storage.load_open_ids(), [])
        self.assertEqual(
            storage.load(ws.id).tabs[0].windows[0].id, a.id
        )  # still in the store


    def test_switch_only_touches_the_anchors_os_window(self) -> None:
        # The old workspace has a window in this OS window (the anchor) and one in another OS window.
        old = ops.new_workspace("old")
        a = ops.add_window(old, "a", None)
        c = ops.add_window(old, "c", None)
        storage.save(old)
        storage.add_open_id(old.id)
        state = [
            {
                "id": 1,
                "tabs": [
                    {
                        "id": 2,
                        "windows": [
                            {"id": 3, "user_vars": {"kitty_workspace": old.id, "kitty_window": a.id}}
                        ],
                    }
                ],
            },
            {
                "id": 10,
                "tabs": [
                    {
                        "id": 11,
                        "windows": [
                            {"id": 12, "user_vars": {"kitty_workspace": old.id, "kitty_window": c.id}}
                        ],
                    }
                ],
            },
        ]
        ws = ops.new_workspace("new")
        ops.add_window(ws, "shell", None)
        storage.save(ws)
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            kr.open_workspace(ws, anchor=3)
        closes = [c_ for c_ in fake.calls if c_[0] == "close-window"]
        self.assertEqual(closes, [["close-window", "--match", "id:3"]])  # never id:12
        saved_old = storage.load(old.id)
        states = {w.id: w.state for t in saved_old.tabs for w in t.windows}
        self.assertEqual(states, {a.id: STATE_DETACHED, c.id: STATE_OPEN})
        self.assertIn(old.id, storage.load_open_ids())  # still open in the other OS window


    def test_picker_window_is_closed_when_done_on_both_paths(self) -> None:
        # cmd+k runs the picker in its own tab (window 8), anchored to the user's window (5).
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", None)
        storage.save(ws)
        fake = FakeKitty([{"id": 1, "tabs": [{"id": 2, "windows": [{"id": 5, "user_vars": {}}]}, {"id": 3, "windows": [{"id": 8, "user_vars": {}}]}]}])
        with mock.patch.object(kr, "_run", side_effect=fake):
            kr.open_workspace(ws, anchor=5, close_window=8)
        self.assertEqual(fake.calls[-1], ["close-window", "--match", "id:8"])
        self.assertTrue(any(c_[0] == "launch" and "id:5" in c_ for c_ in fake.calls))  # opened into the anchor

        other = ops.new_workspace("open one")
        w = ops.add_window(other, "w", None)
        storage.save(other)
        state = [{"id": 1, "tabs": [{"id": 2, "windows": [
            {"id": 3, "user_vars": {"kitty_workspace": other.id, "kitty_window": w.id}},
            {"id": 8, "user_vars": {}}]}]}]
        fake2 = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake2):
            self.assertEqual(kr.open_workspace(other, anchor=5, close_window=8), "focused")
        self.assertIn(["close-window", "--match", "id:8"], fake2.calls)


class ChooseTests(unittest.TestCase):
    def test_fzf_args_include_expect_keys_only_when_asked(self) -> None:
        from workspaces import choose as ch

        self.assertNotIn("--expect", ch.fzf_args("open> "))
        args = ch.fzf_args("detached> ", expect=("ctrl-x", "f3"))
        self.assertEqual(args[args.index("--expect") + 1], "ctrl-x,f3")
        self.assertEqual(args[args.index("--with-nth") + 1], "2..")

    def test_parse_fzf_output(self) -> None:
        from workspaces import choose as ch

        self.assertEqual(ch.parse_fzf_output("3\tlabel\n"), (None, 3))
        self.assertEqual(ch.parse_fzf_output("ctrl-x\n4\tlabel\n", ("ctrl-x",)), ("ctrl-x", 4))
        self.assertEqual(ch.parse_fzf_output("\n2\tlabel\n", ("ctrl-x",)), (None, 2))  # Enter
        self.assertEqual(ch.parse_fzf_output("\n", ("ctrl-x",)), (None, None))

    def test_numbered_fallback_when_fzf_missing(self) -> None:
        from workspaces import choose as ch

        with mock.patch.object(ch, "fzf_bin", return_value=None), mock.patch("builtins.input", return_value="2"), mock.patch("builtins.print"):
            self.assertEqual(ch.choose(["a", "b", "c"], "x> "), (None, 1))
        with mock.patch.object(ch, "fzf_bin", return_value=None), mock.patch("builtins.input", return_value=""), mock.patch("builtins.print"):
            self.assertIsNone(ch.choose(["a"], "x> "))

    def test_fzf_cancel_returns_none(self) -> None:
        from workspaces import choose as ch

        res = mock.Mock(returncode=130, stdout="")
        with mock.patch.object(ch, "fzf_bin", return_value="/bin/fzf"), mock.patch.object(ch.subprocess, "run", return_value=res):
            self.assertIsNone(ch.choose(["a"], "x> "))


class RestoreFidelityTests(_StoreTest):
    def test_restored_split_keeps_its_direction(self) -> None:
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", None)
        ops.add_window(ws, "logs", None, tab_id=ws.tabs[0].id, placement="hsplit")
        storage.save(ws)
        fake = FakeKitty([])
        with mock.patch.object(kr, "_run", side_effect=fake):
            kr.open_workspace(ws, anchor=1)
        splits = [c_ for c_ in fake.calls if c_[0] == "launch" and c_[1] == "--type=window"]
        self.assertEqual(splits[0][splits[0].index("--location") + 1], "hsplit")

    def test_placement_survives_a_round_trip_and_old_files_default(self) -> None:
        ws = ops.new_workspace("api")
        ops.add_window(ws, "editor", None)
        ops.add_window(ws, "logs", None, tab_id=ws.tabs[0].id, placement="vsplit")
        storage.save(ws)
        loaded = storage.load(ws.id)
        self.assertEqual([w.placement for w in loaded.tabs[0].windows], [None, "vsplit"])
        # a file written before placement existed still loads
        path = os.path.join(self._tmp.name, f"{ws.id}.json")
        with open(path) as f:
            data = json.load(f)
        for w in data["tabs"][0]["windows"]:
            w.pop("placement", None)
        with open(path, "w") as f:
            json.dump(data, f)
        self.assertEqual([w.placement for w in storage.load(ws.id).tabs[0].windows], [None, None])


class RenameTabTests(_StoreTest):
    def test_rename_tab_saves_label_and_sets_kitty_title(self) -> None:
        ws = ops.new_workspace("api")
        a = ops.add_window(ws, "editor", None)
        storage.save(ws)
        state = [{"id": 1, "tabs": [{"id": 2, "title": "shell", "windows": [
            {"id": 5, "user_vars": {"kitty_workspace": ws.id, "kitty_window": a.id}}]}]}]
        fake = FakeKitty(state)
        with mock.patch.object(kr, "_run", side_effect=fake):
            self.assertEqual(actions.rename_tab(5, "backend"), "backend")
        self.assertEqual(storage.load(ws.id).tabs[0].label, "backend")
        self.assertIn(["set-tab-title", "--match", "id:5", "backend"], fake.calls)

    def test_rename_tab_refuses_a_window_outside_a_workspace(self) -> None:
        with mock.patch.object(kr, "_run", side_effect=FakeKitty([{"id": 1, "tabs": [{"id": 2, "windows": [{"id": 9, "user_vars": {}}]}]}])):
            with self.assertRaises(ValueError):
                actions.rename_tab(9, "x")


class ScriptedUI:
    """A menu UI that answers from scripted lists, so the menu can be tested without a terminal."""

    def __init__(self, picks=(), asks=(), confirms=()):
        self.picks = list(picks)  # each: (key, index) or None
        self.asks = list(asks)
        self.confirms = list(confirms)
        self.said: list[str] = []
        self.prompts: list[str] = []

    def choose(self, items, prompt, expect=()):
        self.prompts.append(prompt)
        return self.picks.pop(0)

    def ask(self, prompt):
        return self.asks.pop(0)

    def confirm(self, prompt):
        return self.confirms.pop(0)

    def say(self, message):
        self.said.append(message)

    def as_ui(self):
        from workspaces.menu import UI

        return UI(choose=self.choose, ask=self.ask, confirm=self.confirm, say=self.say)


class MenuTests(_StoreTest):
    def _ctx(self, anchor=5, self_id=8):
        from workspaces.menu import Ctx

        return Ctx(anchor=anchor, self_id=self_id)

    def test_select_opens_the_chosen_workspace_and_closes_the_picker(self) -> None:
        from workspaces import menu

        a = ops.new_workspace("alpha")
        storage.save(a)
        ui = ScriptedUI(picks=[(None, 1)])  # index 1 = the first workspace (index 0 is New workspace)
        with mock.patch.object(menu.kr, "open_workspace", return_value="opened") as opn:
            self.assertTrue(menu.run("select", self._ctx(), ui.as_ui()))
        ws_arg, anchor = opn.call_args[0][0], opn.call_args[0][1]
        self.assertEqual(ws_arg.id, a.id)
        self.assertEqual(anchor, 5)
        self.assertEqual(opn.call_args[1], {"close_window": 8})

    def test_select_new_workspace_asks_for_a_name(self) -> None:
        from workspaces import menu

        ui = ScriptedUI(picks=[(None, 0)], asks=["api"])
        with mock.patch.object(menu.kr, "open_workspace", return_value="opened"):
            self.assertTrue(menu.run("select", self._ctx(), ui.as_ui()))
        self.assertEqual([w.label for w in storage.list_all()], ["api"])

    def test_new_workspace_blank_name_gets_a_default(self) -> None:
        from workspaces import menu

        ui = ScriptedUI(asks=[""])
        with mock.patch.object(menu.kr, "open_workspace", return_value="opened"):
            menu.run("new_workspace", self._ctx(), ui.as_ui())
        self.assertTrue(storage.list_all()[0].label.startswith("workspace "))

    def test_kill_workspace_only_when_confirmed(self) -> None:
        from workspaces import menu

        ws = ops.new_workspace("gone")
        storage.save(ws)
        with mock.patch.object(menu.actions, "kill_workspace") as kill:
            menu.run("kill_workspace", self._ctx(), ScriptedUI(picks=[(None, 0)], confirms=[False]).as_ui())
            kill.assert_not_called()
            menu.run("kill_workspace", self._ctx(), ScriptedUI(picks=[(None, 0)], confirms=[True]).as_ui())
            kill.assert_called_once_with(ws.id, 5)

    def test_detached_enter_reattaches_an_open_workspaces_window(self) -> None:
        from workspaces import menu

        item = {"ws_id": "ws-00000001", "ws_label": "api", "ws_open": True, "tab_label": "t", "win_id": "win-00000001", "win_label": "w", "cwd": None}
        ui = ScriptedUI(picks=[(None, 0)])
        with mock.patch.object(menu.actions, "detached_windows", return_value=[item]), \
                mock.patch.object(menu.kr, "ls", return_value=[]), \
                mock.patch.object(menu.kr, "reattach_window") as re_:
            menu.run("detached", self._ctx(), ui.as_ui())
        re_.assert_called_once_with("ws-00000001", "win-00000001")

    def test_detached_enter_on_a_closed_workspace_explains_instead(self) -> None:
        from workspaces import menu

        item = {"ws_id": "ws-00000001", "ws_label": "api", "ws_open": False, "tab_label": "t", "win_id": "win-00000001", "win_label": "w", "cwd": None}
        ui = ScriptedUI(picks=[(None, 0)])
        with mock.patch.object(menu.actions, "detached_windows", return_value=[item]), \
                mock.patch.object(menu.kr, "ls", return_value=[]), \
                mock.patch.object(menu.kr, "reattach_window") as re_:
            menu.run("detached", self._ctx(), ui.as_ui())
        re_.assert_not_called()
        self.assertTrue(any("isn't open" in m for m in ui.said))

    def test_detached_f3_prunes_all_after_confirming(self) -> None:
        from workspaces import menu

        items = [
            {"ws_id": "ws-00000001", "ws_label": "a", "ws_open": True, "tab_label": "t", "win_id": "win-00000001", "win_label": "w", "cwd": None},
            {"ws_id": "ws-00000001", "ws_label": "a", "ws_open": True, "tab_label": "t", "win_id": "win-00000002", "win_label": "w", "cwd": None},
        ]
        ui = ScriptedUI(picks=[("f3", 0)], confirms=[True])
        with mock.patch.object(menu.actions, "detached_windows", return_value=items), \
                mock.patch.object(menu.kr, "ls", return_value=[]), \
                mock.patch.object(menu.actions, "prune_window") as prune:
            menu.run("detached", self._ctx(), ui.as_ui())
        self.assertEqual([c[0] for c in prune.call_args_list], [("ws-00000001", "win-00000001"), ("ws-00000001", "win-00000002")])

    def test_base_menu_runs_the_chosen_command(self) -> None:
        from workspaces import menu

        ui = ScriptedUI(picks=[(None, menu.BASE_MENU.index("new_tab"))])
        with mock.patch.object(menu.actions, "new_window") as nw:
            self.assertTrue(menu.run(None, self._ctx(), ui.as_ui()))
        nw.assert_called_once_with(5, where="tab")

    def test_anchor_commands_fail_cleanly_without_an_anchor(self) -> None:
        from workspaces import menu

        ui = ScriptedUI()
        self.assertFalse(menu.run("kill_window", self._ctx(anchor=None), ui.as_ui()))
        self.assertTrue(any(m.startswith("Failed") for m in ui.said))

    def test_unknown_command_is_reported(self) -> None:
        from workspaces import menu

        ui = ScriptedUI()
        self.assertFalse(menu.run("nope", self._ctx(), ui.as_ui()))
        self.assertTrue(any("Unknown command" in m for m in ui.said))


if __name__ == "__main__":
    unittest.main()

