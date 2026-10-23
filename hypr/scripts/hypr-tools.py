#!/usr/bin/env python3
"""Sleek Shell helper for keyboard shortcuts and monitor settings (used by the Quickshell settings).

All subcommands print exactly one JSON document on stdout.

Keyboard shortcuts
  binds                 every bind: built-in (parsed from the config files + live labels) and custom,
                        with category, label, action text, source, flags and enabled state
  model                 the user model (~/.config/sleek-shell/keybinds.json)
  validate JSON         validate one custom item -> {ok, error, warnings}
  save JSON             save a full model {overrides:{disabled:[norm], remap:{norm: keys}}, custom:[...]}:
                        validate, detect conflicts, generate files, reload Hyprland, verify, roll back on error
  conflicts KEYS [NORM] binds that would clash with KEYS (ignoring the bind whose original norm is NORM)
  export [PATH]         write the model to PATH (default ~/Downloads/sleek-shell-keybinds-<date>.json)
  import PATH           merge a previously exported model and save it
  reset [all]           drop all overrides of built-in binds (and custom binds too with "all")
  actions               the action catalogue the editor offers (Hyprland + shell actions)
  check-script PATH     is PATH an executable, syntactically valid script?
  custom                (legacy) the custom binds list
Monitors
  save-monitors JSON    persist monitor overrides to monitors_custom.lua

Never edits modules/keybinds.lua, monitors.lua or workspaces.lua: built-in binds are changed through the
override layer (hypr/sleekshell/bindlayer.lua).
"""
import json, os, re, shlex, shutil, subprocess, sys, time

HOME = os.path.expanduser("~")
HYPR = os.path.join(os.environ.get("XDG_CONFIG_HOME", HOME + "/.config"), "hypr")
SLEEK = os.path.join(os.environ.get("XDG_CONFIG_HOME", HOME + "/.config"), "sleek-shell")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME", HOME + "/.local/state"), "quickshell")
MODEL_JSON = os.path.join(SLEEK, "keybinds.json")
OVERRIDES_LUA = os.path.join(SLEEK, "hypr-binds.lua")
CUSTOM_LUA = os.path.join(HYPR, "custom_binds.lua")
LEGACY_CUSTOM_JSON = os.path.join(HYPR, "custom_binds.json")
LABELS_LUA = os.path.join(HYPR, "sleekshell", "bind_labels.lua")
MON_LUA = os.path.join(HYPR, "monitors_custom.lua")
MON_JSON = os.path.join(STATE, "monitor-overrides.json")
BACKUPS = os.path.join(SLEEK, "backups")

MODS = {"SUPER": "SUPER", "MOD4": "SUPER", "WIN": "SUPER", "META": "SUPER", "LOGO": "SUPER",
        "SHIFT": "SHIFT", "CTRL": "CTRL", "CONTROL": "CTRL", "ALT": "ALT", "MOD1": "ALT"}
MASK = [(1, "SHIFT"), (4, "CTRL"), (8, "ALT"), (64, "SUPER")]
MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"]
KEY_RE = re.compile(r"^[A-Za-z0-9_:\-.]+$")

# Hyprland actions the editor can bind (no free-form Lua: nothing typed in the UI becomes code).
DISPATCH = {
    "window.close":        ("Close window", 'hl.dsp.window.close()'),
    "window.kill":         ("Force-kill window", 'hl.dsp.window.kill()'),
    "window.float":        ("Toggle floating", 'hl.dsp.window.float({ action = "toggle" })'),
    "window.fullscreen":   ("Toggle fullscreen", 'hl.dsp.window.fullscreen()'),
    "window.pseudo":       ("Pseudo-tile", 'hl.dsp.window.pseudo()'),
    "window.pin":          ("Pin window", 'hl.dsp.window.pin()'),
    "window.center":       ("Center window", 'hl.dsp.window.center()'),
    "layout.togglesplit":  ("Toggle split", 'hl.dsp.layout("togglesplit")'),
    "focus.left":          ("Focus left", 'hl.dsp.focus({ direction = "left" })'),
    "focus.right":         ("Focus right", 'hl.dsp.focus({ direction = "right" })'),
    "focus.up":            ("Focus up", 'hl.dsp.focus({ direction = "up" })'),
    "focus.down":          ("Focus down", 'hl.dsp.focus({ direction = "down" })'),
    "move.left":           ("Move window left", 'hl.dsp.window.move({ direction = "left" })'),
    "move.right":          ("Move window right", 'hl.dsp.window.move({ direction = "right" })'),
    "move.up":             ("Move window up", 'hl.dsp.window.move({ direction = "up" })'),
    "move.down":           ("Move window down", 'hl.dsp.window.move({ direction = "down" })'),
    "special.toggle":      ("Toggle scratchpad", 'hl.dsp.workspace.toggle_special("magic")'),
    "special.move":        ("Move window to scratchpad", 'hl.dsp.window.move({ workspace = "special:magic" })'),
    "session.exit":        ("Exit Hyprland", 'hl.dsp.exit()'),
}
SHELL = {
    "overview":       ("Workspace overview", "quickshell ipc call overview toggle"),
    "switcher.next":  ("App switcher", "quickshell ipc call switcher next"),
    "settings":       ("Sleek Shell settings", "quickshell ipc call settings toggle"),
    "appearance":     ("Appearance panel", "quickshell ipc call appearance toggle"),
    "keybinds":       ("Keyboard shortcuts", "quickshell ipc call keybinds toggle"),
    "monitors":       ("Display settings", "quickshell ipc call monitors toggle"),
    "lock":           ("Lock screen", "quickshell ipc call lock lock"),
    "media.playpause":("Play / pause media", "quickshell ipc call media playPause"),
    "media.next":     ("Next track", "quickshell ipc call media next"),
    "media.previous": ("Previous track", "quickshell ipc call media previous"),
    "ws.next":        ("Next workspace (this monitor)", "quickshell ipc call ws next"),
    "ws.prev":        ("Previous workspace (this monitor)", "quickshell ipc call ws prev"),
    "wallpaper.next": ("Next wallpaper", HOME + "/.config/hypr/scripts/wallpaper-next.sh"),
    "wallpaper.random": ("Random wallpaper", HOME + "/.config/hypr/scripts/wallpaper-next.sh random"),
}
DANGEROUS = [
    (r"\brm\s+(-\w*[rf]\w*\s+)+", "deletes files (rm -r/-f)"),
    (r"\bmkfs(\.\w+)?\b", "formats a filesystem"),
    (r"\bdd\b.*\bof=", "writes raw data to a device or file (dd of=)"),
    (r":\(\)\s*\{", "fork bomb"),
    (r"\b(shutdown|poweroff|reboot|halt)\b", "powers off / restarts the machine"),
    (r">\s*/dev/(sd|nvme|mmcblk)", "overwrites a disk device"),
    (r"\bchmod\s+-R\b|\bchown\s+-R\b", "recursively changes permissions/ownership"),
    (r"\bsudo\b|\bpkexec\b|\bdoas\b", "runs with root privileges"),
    (r"\bkill(all)?\s+-9\b|\bpkill\b", "kills processes"),
]


def out(obj):
    print(json.dumps(obj))


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except Exception as e:  # noqa
        return 1, "", str(e)


# ---------------------------------------------------------------- key combinations
def split_keys(keys):
    toks = [t.strip() for t in str(keys).split("+") if t.strip()]
    mods, key = set(), ""
    for i, t in enumerate(toks):
        u = t.upper()
        if i < len(toks) - 1 and u in MODS:
            mods.add(MODS[u])
        else:
            key = t
    return mods, key


def norm(keys, submap=""):
    """'SUPER + SHIFT + W' -> 'SHIFT+SUPER|w' (matches M.norm in hypr/sleekshell/bindlayer.lua)."""
    mods, key = split_keys(keys)
    return "+".join(sorted(mods)) + "|" + key.lower() + ("@" + submap if submap else "")


def pretty_keys(keys):
    mods, key = split_keys(keys)
    disp = key.upper() if len(key) == 1 else key
    return " + ".join([m for m in MOD_ORDER if m in mods] + [disp])


def valid_keys(keys):
    toks = [t.strip() for t in str(keys).split("+")]
    if not toks or any(t == "" for t in toks):
        return "Shortcut is empty or has a stray '+'"
    *mods, key = toks
    for m in mods:
        if m.upper() not in MODS:
            return "Unknown modifier '%s' (use SUPER, CTRL, ALT, SHIFT)" % m
    if key.upper() in MODS:
        return "A shortcut needs a key after the modifiers"
    if not KEY_RE.match(key):
        return "Invalid key name '%s'" % key
    return ""


# ---------------------------------------------------------------- source scan
def lua_files():
    seen, todo, order = set(), [os.path.join(HYPR, "hyprland.lua")], []
    while todo:
        f = todo.pop(0)
        if f in seen or not os.path.isfile(f):
            continue
        seen.add(f)
        order.append(f)
        try:
            txt = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for m in re.finditer(r"require\s*\(?\s*[\"']([\w.]+)[\"']", txt):
            todo.append(os.path.join(HYPR, m.group(1).replace(".", "/") + ".lua"))
        for m in re.finditer(r"pcall\s*\(\s*require\s*,\s*[\"']([\w.]+)[\"']", txt):
            todo.append(os.path.join(HYPR, m.group(1).replace(".", "/") + ".lua"))
    return order


def strip_comment(line):
    out_, q = [], None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            out_.append(c)
            if c == "\\" and i + 1 < len(line):
                out_.append(line[i + 1]); i += 2; continue
            if c == q:
                q = None
        else:
            if c in "\"'":
                q = c
            elif line.startswith("--", i):
                break
            out_.append(c)
        i += 1
    return "".join(out_)


def split_args(s):
    """split the argument list of a call at top-level commas"""
    args, depth, q, cur = [], 0, None, ""
    for i, c in enumerate(s):
        if q:
            cur += c
            if c == q and s[i - 1] != "\\":
                q = None
            continue
        if c in "\"'":
            q = c
        elif c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        elif c == "," and depth == 0:
            args.append(cur.strip()); cur = ""; continue
        cur += c
    if cur.strip():
        args.append(cur.strip())
    return args


def eval_concat(expr, env):
    """evaluate  "a" .. var .. "b"  /  var % 10  with a tiny environment; None if not static"""
    parts = [p.strip() for p in re.split(r"\.\.", expr)]
    res = ""
    for p in parts:
        m = re.fullmatch(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', p)
        if m:
            res += bytes(m.group(1) if m.group(1) is not None else m.group(2), "utf-8").decode("unicode_escape")
        elif re.fullmatch(r"[A-Za-z_]\w*", p) and p in env:
            res += str(env[p])
        elif re.fullmatch(r"\d+", p):
            res += p
        else:
            return None
    return res


def humanize(action, env):
    a = action.strip()
    m = re.fullmatch(r"hl\.dsp\.exec_cmd\((.*)\)", a, re.S)
    if m:
        v = eval_concat(m.group(1), env)
        return ("Run: " + v) if v is not None else "Run command", "exec", v or ""
    m = re.fullmatch(r"hl\.dsp\.global\((.*)\)", a, re.S)
    if m:
        v = eval_concat(m.group(1), env)
        return "Shell: " + (v.split(":", 1)[-1] if v else "global shortcut"), "global", v or ""
    return a.replace("hl.dsp.", ""), "dispatch", a


def scan_builtin():
    """Every hl.bind in the config files except the generated custom_binds.lua."""
    res = []
    for f in lua_files():
        rel = os.path.relpath(f, HYPR)
        if rel in ("custom_binds.lua",) or rel.startswith(("sleekshell/", "sleakshell/", "sleakos/")):
            continue
        try:
            lines = open(f, encoding="utf-8", errors="replace").read().split("\n")
        except OSError:
            continue
        env, loops = {}, []   # loops: [(var, start, stop, local_key_expr)]
        buf, buf_line = "", 0
        for n, raw in enumerate(lines, 1):
            line = strip_comment(raw)
            s = line.strip()
            m = re.match(r'local\s+(\w+)\s*=\s*"([^"]*)"\s*$', s)
            if m and not loops:
                env[m.group(1)] = m.group(2)
            m = re.match(r"for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do", s)
            if m:
                loops.append([m.group(1), int(m.group(2)), int(m.group(3)), {}])
                continue
            if loops:
                m = re.match(r"local\s+(\w+)\s*=\s*(\w+)\s*%\s*(\d+)", s)
                if m:
                    loops[-1][3][m.group(1)] = (m.group(2), int(m.group(3)))
                    continue
                if re.fullmatch(r"end", s):
                    loops.pop()
                    continue
            if not buf and "hl.bind(" not in s:
                continue
            if not buf:
                buf, buf_line = s[s.index("hl.bind(") + len("hl.bind("):], n
            else:
                buf += " " + s
            depth, q, end = 1, None, -1
            for i, c in enumerate(buf):
                if q:
                    if c == q and buf[i - 1] != "\\":
                        q = None
                    continue
                if c in "\"'":
                    q = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        end = i; break
            if end < 0:
                continue
            argstr, buf = buf[:end], ""
            args = split_args(argstr)
            if len(args) < 2:
                continue
            opts = args[2] if len(args) > 2 else ""
            flags = [k for k in ("locked", "repeating", "mouse", "release", "non_consuming") if re.search(r"\b%s\s*=\s*true" % k, opts)]
            envs = [dict(env)]
            if loops:
                var, a, b, locs = loops[-1]
                envs = []
                for v in range(a, b + 1):
                    e = dict(env); e[var] = v
                    for lk, (src, mod) in locs.items():
                        if src == var:
                            e[lk] = v % mod
                    envs.append(e)
            for e in envs:
                keys = eval_concat(args[0], e)
                if keys is None:
                    continue
                text, kind, value = humanize(args[1], e)
                res.append({"keys": keys, "norm": norm(keys), "action": text, "actionKind": kind, "actionValue": value,
                            "source": rel, "line": buf_line, "flags": flags, "loop": bool(loops)})
    return res


def read_labels():
    labels = {}
    try:
        for m in re.finditer(r'\["([^"]+)"\]\s*=\s*"([^"]*)"', open(LABELS_LUA, encoding="utf-8").read()):
            labels[m.group(1)] = m.group(2)
    except OSError:
        pass
    return labels


def split_label(desc):
    if desc and ": " in desc:
        c, l = desc.split(": ", 1)
        return c, l
    return "", desc or ""


def guess_category(kind, value, keys):
    k, v = keys.lower(), (value or "").lower()
    if "xf86" in k:
        return "Media & hardware"
    if kind == "global" or "quickshell ipc" in v:
        return "Shell"
    if "workspace" in v:
        return "Workspaces"
    if kind == "dispatch":
        return "Windows"
    if kind == "exec":
        return "Applications"
    return "Other"


def live_binds():
    rc, so, _ = run(["hyprctl", "binds", "-j"])
    if rc != 0:
        return None
    try:
        data = json.loads(so)
    except ValueError:
        return None
    res = []
    for b in data:
        mods = [name for bit, name in MASK if b.get("modmask", 0) & bit]
        key = b.get("key") or ("code:%s" % b.get("keycode", ""))
        keys = " + ".join(mods + [key]) if mods else key
        res.append({"keys": keys, "norm": norm(keys), "submap": b.get("submap", "") or "",
                    "desc": b.get("description", "") or "", "locked": b.get("locked", False)})
    return res


# ---------------------------------------------------------------- model
def empty_model():
    return {"version": 1, "overrides": {"disabled": [], "remap": {}}, "custom": []}


def load_model():
    try:
        m = json.load(open(MODEL_JSON))
        if not isinstance(m, dict):
            raise ValueError
    except (OSError, ValueError):
        m = empty_model()
        # migrate binds created by the pre-Sleek Shell keybind manager
        try:
            for it in json.load(open(LEGACY_CUSTOM_JSON)):
                kind = "command" if it.get("kind") == "exec" else None
                if kind:
                    m["custom"].append({"id": it.get("id") or "c%d" % len(m["custom"]), "keys": it.get("keys", ""),
                                        "kind": kind, "value": it.get("value", ""), "desc": it.get("desc", ""),
                                        "enabled": it.get("enabled", True), "flags": it.get("flags", {})})
        except (OSError, ValueError, TypeError):
            pass
    ov = m.get("overrides") or {}
    m["overrides"] = {"disabled": [n for n in ov.get("disabled", []) if isinstance(n, str)],
                      "remap": {k: v for k, v in (ov.get("remap") or {}).items() if isinstance(k, str) and isinstance(v, str)}}
    m["custom"] = [c for c in m.get("custom", []) if isinstance(c, dict)]
    m["version"] = 1
    return m


def first_word(cmd):
    try:
        parts = shlex.split(cmd)
    except ValueError:
        return None, "Unbalanced quotes in the command"
    while parts and re.match(r"^\w+=", parts[0]):   # leading VAR=value
        parts = parts[1:]
    if not parts:
        return None, "Empty command"
    return parts[0], ""


def resolves(word):
    w = os.path.expanduser(word)
    if "/" in w:
        return os.path.isfile(w) and os.access(w, os.X_OK)
    return shutil.which(w) is not None or w in ("command", "exec", "env", "test", "[", "true", "false")


def exec_string(it):
    k, v = it["kind"], it["value"].strip()
    if k == "app":
        return re.sub(r"\s%[a-zA-Z]", "", v).strip()
    if k == "command":
        return v
    if k == "script":
        args = it.get("args", "").strip()
        return shlex.quote(os.path.expanduser(v)) + ((" " + args) if args else "")
    if k == "shell":
        return SHELL[v][1]
    return None


def validate_item(it, check_conflict_with=None):
    """returns (error, warnings)"""
    warnings = []
    if not isinstance(it, dict):
        return "Malformed item", warnings
    if not re.match(r"^[A-Za-z0-9_\-]{1,40}$", str(it.get("id", ""))):
        return "Internal id is invalid", warnings
    e = valid_keys(it.get("keys", ""))
    if e:
        return e, warnings
    kind, v = it.get("kind"), str(it.get("value", "")).strip()
    if kind not in ("app", "command", "script", "shell", "dispatch"):
        return "Choose what the shortcut should do", warnings
    if not v:
        return "The action is empty", warnings
    if "\n" in v or "\r" in v:
        return "The action must be a single line", warnings
    if kind in ("app", "command"):
        w, err = first_word(re.sub(r"\s%[a-zA-Z]", "", v))
        if err:
            return err, warnings
        if not resolves(w):
            return "'%s' was not found. Install it or use its full path." % w, warnings
        if kind == "command":
            for pat, why in DANGEROUS:
                if re.search(pat, v):
                    warnings.append("This command " + why + ".")
            if warnings and not it.get("confirmed"):
                return "Potentially destructive command: " + " ".join(warnings) + " Tick 'I understand' to save it.", warnings
    elif kind == "script":
        p = os.path.expanduser(v)
        if not os.path.isfile(p):
            return "Script not found: " + v, warnings
        if not os.access(p, os.X_OK):
            return "Script is not executable (run: chmod +x %s)" % v, warnings
        try:
            first = open(p, "rb").readline().decode("utf-8", "replace").strip()
        except OSError as ex:
            return "Cannot read script: %s" % ex, warnings
        if not first.startswith("#!"):
            warnings.append("Script has no #! line; it will be run by sh.")
        elif re.search(r"\b(ba|z|da)?sh\b", first):
            rc, _, se = run(["bash", "-n", p])
            if rc:
                return "Script has a syntax error: " + se.strip(), warnings
        if "\n" in it.get("args", ""):
            return "Arguments must be a single line", warnings
    elif kind == "shell":
        if v not in SHELL:
            return "Unknown shell action", warnings
    elif kind == "dispatch":
        if v not in DISPATCH:
            return "Unknown Hyprland action", warnings
        if v in ("session.exit", "window.kill"):
            warnings.append("This action " + ("ends the session" if v == "session.exit" else "force-kills the window") + ".")
    if len(str(it.get("desc", ""))) > 80:
        return "Description is too long (80 characters max)", warnings
    return "", warnings


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


def gen_custom_lua(items):
    lines = ["-- MANAGED by Sleek Shell Settings > Keyboard. Do not edit by hand: your binds live in",
             "-- ~/.config/sleek-shell/keybinds.json. Delete this file to drop all custom binds.",
             "-- Custom binds bypass the built-in override layer (they call the original hl.bind).",
             "local ok, layer = pcall(require, \"sleekshell.bindlayer\")",
             "local bind = (ok and type(layer) == \"table\" and layer.orig) or hl.bind",
             ""]
    for it in items:
        if not it.get("enabled", True):
            continue
        if it["kind"] == "dispatch":
            act = DISPATCH[it["value"]][1]
        else:
            act = "hl.dsp.exec_cmd(%s)" % lua_str(exec_string(it))
        label = re.sub(r"[\r\n]+", " ", it.get("desc") or "") or describe(it)
        opts = ["description = %s" % lua_str("Custom: " + label)]
        fl = it.get("flags") or {}
        for k in ("locked", "repeating"):
            if fl.get(k):
                opts.append("%s = true" % k)
        lines.append("bind(%s, %s, { %s })" % (lua_str(pretty_keys(it["keys"])), act, ", ".join(opts)))
    return "\n".join(lines) + "\n"


def gen_overrides_lua(ov):
    lines = ["-- Generated by Sleek Shell Settings > Keyboard from ~/.config/sleek-shell/keybinds.json. Do not edit by hand.",
             "-- Read by hypr/sleekshell/bindlayer.lua: disables or moves built-in binds without editing their files.",
             "return {", "    disabled = {"]
    for n in sorted(set(ov.get("disabled", []))):
        lines.append("        %s," % lua_str(n))
    lines += ["    },", "    remap = {"]
    for n, k in sorted(ov.get("remap", {}).items()):
        lines.append("        [%s] = %s," % (lua_str(n), lua_str(pretty_keys(k))))
    lines += ["    },", "}"]
    return "\n".join(lines) + "\n"


def describe(it):
    k, v = it.get("kind"), it.get("value", "")
    if k == "dispatch":
        return DISPATCH.get(v, (v,))[0]
    if k == "shell":
        return SHELL.get(v, (v,))[0]
    if k == "script":
        return "Script: " + os.path.basename(v)
    if k == "app":
        return "Open " + (it.get("app") or v.split()[0] if v else "app")
    return "Run: " + v


# ---------------------------------------------------------------- effective bind table
def effective(model, builtin=None, live=None):
    """[(norm, display keys, label, ref)] for everything that will be bound after saving the model."""
    builtin = builtin if builtin is not None else scan_builtin()
    labels = read_labels()
    ov = model["overrides"]
    dis, remap = set(ov["disabled"]), ov["remap"]
    rows, known = [], set()
    for b in builtin:
        known.add(b["norm"])
        if b["norm"] in dis:
            continue
        keys = remap.get(b["norm"], b["keys"])
        rows.append((norm(keys), pretty_keys(keys), split_label(labels.get(b["norm"], ""))[1] or b["action"], "builtin:" + b["norm"]))
    for it in model["custom"]:
        if it.get("enabled", True) and not valid_keys(it.get("keys", "")):
            rows.append((norm(it["keys"]), pretty_keys(it["keys"]), it.get("desc") or describe(it), "custom:" + str(it.get("id"))))
    # binds that exist live but come from somewhere we do not manage (plugins, other files)
    custom_norms = {norm(i.get("keys", "")) for i in model["custom"]}
    remapped_to = {norm(k) for k in remap.values()}
    for lb in (live or []):
        if lb["norm"] not in known and lb["norm"] not in custom_norms and lb["norm"] not in remapped_to and lb["submap"] == "":
            rows.append((lb["norm"], pretty_keys(lb["keys"]), lb["desc"] or "external bind", "external:" + lb["norm"]))
    return rows


def find_conflicts(rows):
    by, clashes = {}, []
    for r in rows:
        by.setdefault(r[0], []).append(r)
    for n, rs in by.items():
        if len(rs) > 1:
            clashes.append({"keys": rs[0][1], "binds": [{"label": r[2], "ref": r[3]} for r in rs]})
    return clashes


# ---------------------------------------------------------------- commands
def cmd_binds():
    model = load_model()
    builtin = scan_builtin()
    live = live_binds()
    labels = read_labels()
    live_by = {}
    for lb in live or []:
        live_by.setdefault(lb["norm"], lb)
    ov = model["overrides"]
    dis, remap = set(ov["disabled"]), ov["remap"]
    res, seen = [], set()
    for b in builtin:
        if b["norm"] in seen:
            continue
        seen.add(b["norm"])
        cur = remap.get(b["norm"], b["keys"])
        lb = live_by.get(norm(cur))
        cat, label = split_label(labels.get(b["norm"], "") or (lb["desc"] if lb else ""))
        res.append({
            "id": "b:" + b["norm"], "kind": "builtin", "keys": pretty_keys(cur), "norm": norm(cur),
            "origNorm": b["norm"], "origKeys": pretty_keys(b["keys"]), "remapped": b["norm"] in remap,
            "enabled": b["norm"] not in dis, "live": lb is not None,
            "label": label or b["action"], "category": cat or guess_category(b["actionKind"], b["actionValue"], b["keys"]),
            "action": b["action"], "source": b["source"], "line": b["line"], "flags": b["flags"],
        })
    for it in model["custom"]:
        err, warns = validate_item(it)
        res.append({
            "id": "c:" + str(it.get("id")), "kind": "custom", "keys": pretty_keys(it.get("keys", "")), "norm": norm(it.get("keys", "")),
            "origNorm": "", "origKeys": "", "remapped": False, "enabled": bool(it.get("enabled", True)),
            "live": norm(it.get("keys", "")) in live_by, "label": it.get("desc") or describe(it), "category": "Custom",
            "action": describe(it), "source": "~/.config/sleek-shell/keybinds.json", "line": 0,
            "flags": [k for k, v in (it.get("flags") or {}).items() if v], "item": it, "problem": err, "warnings": warns,
        })
    clashes = find_conflicts(effective(model, builtin, live))
    out({"ok": True, "binds": res, "model": model, "conflicts": clashes, "liveOk": live is not None,
         "sources": sorted({b["source"] for b in builtin})})


def cmd_validate(js):
    it = json.loads(js)
    err, warns = validate_item(it)
    out({"ok": not err, "error": err, "warnings": warns, "preview": exec_string(it) if not err and it.get("kind") != "dispatch" else (DISPATCH.get(it.get("value"), ("", ""))[1] if not err else "")})


def cmd_conflicts(keys, ignore=""):
    model = load_model()
    e = valid_keys(keys)
    if e:
        return out({"ok": False, "error": e, "conflicts": []})
    n = norm(keys)
    hits = [{"keys": r[1], "label": r[2], "ref": r[3]} for r in effective(model, live=live_binds())
            if r[0] == n and r[3] not in ("builtin:" + ignore, "custom:" + ignore)]
    out({"ok": True, "conflicts": hits})


def snapshot_files():
    snap = {}
    for p in (MODEL_JSON, OVERRIDES_LUA, CUSTOM_LUA):
        snap[p] = open(p).read() if os.path.exists(p) else None
    return snap


def restore_files(snap):
    for p, txt in snap.items():
        if txt is None:
            if os.path.exists(p):
                os.remove(p)
        else:
            write_atomic(p, txt)


def write_atomic(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".new"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def keep_backup(snap):
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for p, txt in snap.items():
        if txt is not None:
            open(os.path.join(BACKUPS, os.path.basename(p) + "." + stamp), "w").write(txt)
    # keep the 20 newest backups per file
    files = sorted(os.listdir(BACKUPS))
    for base in {f.rsplit(".", 1)[0] for f in files}:
        mine = sorted(f for f in files if f.rsplit(".", 1)[0] == base)
        for old in mine[:-20]:
            try:
                os.remove(os.path.join(BACKUPS, old))
            except OSError:
                pass


def lua_check(path):
    for lua in ("luac", "luac5.4", "luac5.5"):
        if shutil.which(lua):
            rc, _, se = run([lua, "-p", path])
            return se.strip() if rc else ""
    return ""


def cmd_save(js, reload=True):
    try:
        model = json.loads(js)
    except ValueError as e:
        return out({"ok": False, "error": "Malformed data: %s" % e})
    base = empty_model()
    ov = model.get("overrides") or {}
    base["overrides"]["disabled"] = sorted({n for n in ov.get("disabled", []) if isinstance(n, str) and "|" in n})
    for n, k in (ov.get("remap") or {}).items():
        e = valid_keys(k)
        if e:
            return out({"ok": False, "error": "Remap of %s: %s" % (n, e)})
        if norm(k) != n:
            base["overrides"]["remap"][n] = pretty_keys(k)
    ids = set()
    for it in model.get("custom", []):
        err, _ = validate_item(it)
        if err:
            return out({"ok": False, "error": "%s: %s" % (it.get("keys") or "New shortcut", err), "item": it.get("id")})
        if it["id"] in ids:
            return out({"ok": False, "error": "Duplicate internal id"})
        ids.add(it["id"])
        clean = {"id": it["id"], "keys": pretty_keys(it["keys"]), "kind": it["kind"], "value": it["value"].strip(),
                 "desc": re.sub(r"[\r\n]+", " ", it.get("desc", ""))[:80], "enabled": bool(it.get("enabled", True)),
                 "flags": {k: bool(v) for k, v in (it.get("flags") or {}).items() if k in ("locked", "repeating") and v}}
        if it.get("args"):
            clean["args"] = it["args"]
        if it.get("app"):
            clean["app"] = str(it["app"])[:60]
        if it.get("confirmed"):
            clean["confirmed"] = True
        base["custom"].append(clean)
    builtin = scan_builtin()
    known = {b["norm"] for b in builtin}
    base["overrides"]["disabled"] = [n for n in base["overrides"]["disabled"] if n in known]
    base["overrides"]["remap"] = {n: k for n, k in base["overrides"]["remap"].items() if n in known}
    clashes = find_conflicts(effective(base, builtin, live_binds()))
    if clashes:
        c = clashes[0]
        return out({"ok": False, "error": "%s is used by: %s" % (c["keys"], ", ".join(b["label"] for b in c["binds"])), "conflicts": clashes})

    snap = snapshot_files()
    os.makedirs(SLEEK, exist_ok=True)
    tmp_c, tmp_o = CUSTOM_LUA + ".check", OVERRIDES_LUA + ".check"
    open(tmp_c, "w").write(gen_custom_lua(base["custom"]))
    open(tmp_o, "w").write(gen_overrides_lua(base["overrides"]))
    errs = lua_check(tmp_c) or lua_check(tmp_o)
    if errs:
        os.remove(tmp_c); os.remove(tmp_o)
        return out({"ok": False, "error": "Generated Lua is invalid: " + errs})
    os.replace(tmp_c, CUSTOM_LUA)
    os.replace(tmp_o, OVERRIDES_LUA)
    write_atomic(MODEL_JSON, json.dumps(base, indent=1) + "\n")
    keep_backup(snap)
    if not reload:
        return out({"ok": True, "applied": False})
    run(["hyprctl", "reload"])
    time.sleep(0.6)
    rc, so, _ = run(["hyprctl", "configerrors"])
    errs = so.strip()
    if rc == 0 and errs and "no errors" not in errs.lower() and errs != "[]":
        restore_files(snap)
        run(["hyprctl", "reload"])
        return out({"ok": False, "rolledBack": True, "error": "Hyprland rejected the change, previous shortcuts restored: " + errs[:400]})
    # verify: every enabled custom bind and every remap is live now
    live = {b["norm"] for b in (live_binds() or [])}
    missing = [it["keys"] for it in base["custom"] if it["enabled"] and norm(it["keys"]) not in live]
    missing += [k for k in base["overrides"]["remap"].values() if norm(k) not in live]
    out({"ok": True, "applied": True, "missing": missing,
         "message": "Saved and applied" if not missing else "Saved, but not live yet: " + ", ".join(missing)})


def cmd_export(path=""):
    model = load_model()
    if not path:
        path = os.path.join(HOME, "Downloads", "sleek-shell-keybinds-%s.json" % time.strftime("%Y%m%d-%H%M"))
    path = os.path.expanduser(path)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        payload = dict(model); payload["sleekShellKeybinds"] = 1
        open(path, "w").write(json.dumps(payload, indent=1) + "\n")
    except OSError as e:
        return out({"ok": False, "error": str(e)})
    out({"ok": True, "path": path})


def cmd_import(path):
    p = os.path.expanduser(path.strip())
    try:
        data = json.load(open(p))
    except (OSError, ValueError) as e:
        return out({"ok": False, "error": "Cannot read %s: %s" % (path, e)})
    if not isinstance(data, dict) or (data.get("sleekShellKeybinds") != 1 and data.get("sleakShellKeybinds") != 1 and data.get("sleakosKeybinds") != 1):
        return out({"ok": False, "error": "Not a Sleek Shell keybinds export"})
    model = load_model()
    ov = data.get("overrides") or {}
    model["overrides"]["disabled"] = sorted(set(model["overrides"]["disabled"]) | {n for n in ov.get("disabled", []) if isinstance(n, str)})
    model["overrides"]["remap"].update({k: v for k, v in (ov.get("remap") or {}).items() if isinstance(k, str) and isinstance(v, str)})
    have = {c["id"] for c in model["custom"]}
    for it in data.get("custom", []):
        if not isinstance(it, dict):
            continue
        it = dict(it)
        while it.get("id") in have or not it.get("id"):
            it["id"] = "c%d" % int(time.time() * 1000 + len(have)); have.add(it["id"])
        have.add(it["id"])
        model["custom"].append(it)
    cmd_save(json.dumps(model))


def cmd_reset(scope=""):
    model = load_model()
    model["overrides"] = {"disabled": [], "remap": {}}
    if scope == "all":
        model["custom"] = []
    cmd_save(json.dumps(model))


def cmd_actions():
    apps = []
    out({"ok": True,
         "dispatch": [{"id": k, "label": v[0]} for k, v in DISPATCH.items()],
         "shell": [{"id": k, "label": v[0]} for k, v in SHELL.items()]})


def cmd_check_script(path):
    it = {"id": "x", "keys": "SUPER + F12", "kind": "script", "value": path}
    err, warns = validate_item(it)
    out({"ok": not err, "error": err, "warnings": warns})

# ---------------------------------------------------------------- monitors
def cmd_save_monitors(js):
    new = json.loads(js)
    try:
        old = json.load(open(MON_JSON))
    except (OSError, ValueError):
        old = {}
    for name, v in new.items():
        if not re.match(r"^[\w.:\-]+$", name):
            return out({"ok": False, "error": "bad monitor name"})
        if not re.match(r"^\d+x\d+@[\d.]+$", v["mode"]) or not re.match(r"^-?\d+x-?\d+$", v["position"]):
            return out({"ok": False, "error": "bad mode/position for " + name})
        float(v["scale"]); int(v["transform"])
    old.update(new)
    os.makedirs(STATE, exist_ok=True)
    lines = ["-- MANAGED by the Quickshell monitor settings. Loaded after the nwg-displays",
             "-- monitors.lua, so it overrides only the outputs listed here. Delete this file",
             "-- (or run: rm ~/.config/hypr/monitors_custom.lua) to go back to nwg-displays.", ""]
    for name, v in sorted(old.items()):
        lines.append('hl.monitor({ output = %s, mode = %s, position = %s, scale = %s, transform = %d })'
                     % (lua_str(name), lua_str(v["mode"]), lua_str(v["position"]), v["scale"], int(v["transform"])))
    backup(MON_LUA)
    open(MON_LUA + ".new", "w").write("\n".join(lines) + "\n")
    os.replace(MON_LUA + ".new", MON_LUA)
    json.dump(old, open(MON_JSON, "w"), indent=1)
    out({"ok": True})




def main(a):
    try:
        if not a:
            return print(__doc__)
        c, rest = a[0], a[1:]
        if c == "binds": cmd_binds()
        elif c == "model": out({"ok": True, "model": load_model()})
        elif c == "custom": out({"ok": True, "binds": load_model()["custom"]})
        elif c == "validate": cmd_validate(rest[0])
        elif c == "conflicts": cmd_conflicts(rest[0], rest[1] if len(rest) > 1 else "")
        elif c == "save": cmd_save(rest[0], reload="--no-reload" not in rest)
        elif c == "export": cmd_export(rest[0] if rest else "")
        elif c == "import": cmd_import(rest[0])
        elif c == "reset": cmd_reset(rest[0] if rest else "")
        elif c == "actions": cmd_actions()
        elif c == "check-script": cmd_check_script(rest[0])
        elif c == "save-monitors": cmd_save_monitors(rest[0])
        else: out({"ok": False, "error": "unknown command"})
    except Exception as e:  # noqa
        out({"ok": False, "error": "%s: %s" % (type(e).__name__, e)})


if __name__ == "__main__":
    main(sys.argv[1:])
