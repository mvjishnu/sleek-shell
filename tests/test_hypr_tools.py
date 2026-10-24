"""Shortcut editor save path (hypr/scripts/hypr-tools.py cmd_save).

Regression: a config error that existed before the save (for example from another module) must not make
the editor roll back a valid change; only errors introduced by the change may trigger a rollback.
Runs entirely in a temp XDG_CONFIG_HOME with hyprctl mocked.
"""
import importlib.util, json, os, shutil, sys, tempfile, unittest, warnings

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD_ERR = "/tmp/u/.config/hypr/modules/workspaces.lua:64: attempt to call a table value"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def load_tools(cfg):
    os.environ["XDG_CONFIG_HOME"] = cfg
    os.environ["XDG_STATE_HOME"] = os.path.join(cfg, "state")
    spec = importlib.util.spec_from_file_location("hypr_tools", os.path.join(REPO, "hypr/scripts/hypr-tools.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FakeHyprland:
    def __init__(self, before, after):
        self.before, self.after, self.reloaded = before, after, 0

    def run(self, cmd, timeout=10):
        if cmd[:1] != ["hyprctl"]:
            return 0, "", ""
        if "reload" in cmd:
            self.reloaded += 1
            return 0, "ok", ""
        if "configerrors" in cmd:
            errs = self.after if self.reloaded % 2 == 1 else self.before
            return 0, json.dumps(errs or [""]), ""
        if "binds" in cmd:
            return 0, "[]", ""
        return 0, "", ""


class SaveTest(unittest.TestCase):
    def setUp(self):
        warnings.simplefilter("ignore", ResourceWarning)
        self.tmp = tempfile.mkdtemp(prefix="sleek-hypr-tools.")
        shutil.copytree(os.path.join(REPO, "hypr"), os.path.join(self.tmp, "hypr"))
        self.t = load_tools(self.tmp)
        self.t.time.sleep = lambda s: None
        self.results = []
        self.t.out = self.results.append

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def save(self, fake):
        self.t.run = fake.run
        model = {"overrides": {}, "custom": [{"id": "c1", "keys": "SUPER + CTRL + F9", "kind": "dispatch",
                                              "value": "window.center", "desc": "test", "enabled": True}]}
        self.t.cmd_save(json.dumps(model))
        return self.results[-1]

    def test_preexisting_error_does_not_roll_back(self):
        r = self.save(FakeHyprland([OLD_ERR], [OLD_ERR]))
        self.assertTrue(r["ok"], r)
        self.assertTrue(os.path.exists(self.t.CUSTOM_LUA))
        self.assertIn("F9", read(self.t.CUSTOM_LUA))

    def test_new_error_rolls_back(self):
        r = self.save(FakeHyprland([OLD_ERR], [OLD_ERR, "custom_binds.lua:3: bad bind"]))
        self.assertFalse(r["ok"], r)
        self.assertTrue(r.get("rolledBack"))
        self.assertIn("bad bind", r["error"])
        self.assertNotIn("attempt to call a table", r["error"])
        self.assertFalse(os.path.exists(self.t.CUSTOM_LUA) and "F9" in read(self.t.CUSTOM_LUA))

    def test_clean_config(self):
        self.assertTrue(self.save(FakeHyprland([], []))["ok"])

    def test_parse_config_errors(self):
        p = self.t.parse_config_errors
        self.assertEqual(p('[""]'), set())
        self.assertEqual(p(""), set())
        self.assertEqual(p("no errors"), set())
        self.assertEqual(p('["a", "", "b"]'), {"a", "b"})
        self.assertEqual(p("line one\nline two\n"), {"line one", "line two"})


if __name__ == "__main__":
    unittest.main()
