#!/usr/bin/env python3
"""Read / change boolean options in the configuration block of ~/.config/rofi/config.rasi.

  rofi-prefs.py get                 -> {"ok": true, "show-icons": true, "hover-select": true, ...}
  rofi-prefs.py set KEY true|false  -> writes atomically, keeps every other line untouched

Only the keys in KEYS can be changed. rofi reads the file on every launch, so changes apply
the next time it opens.
"""
import json
import os
import re
import sys
import tempfile

CFG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
PATH = os.path.join(CFG, "rofi", "config.rasi")
KEYS = {"show-icons": True, "hover-select": False, "case-sensitive": False, "sort": False}


def out(o, rc=0):
    sys.stdout.write(json.dumps(o) + "\n")
    return rc


def block_span(text):
    m = re.search(r"configuration\s*\{", text)
    if not m:
        return None
    depth, i = 1, m.end()
    while i < len(text) and depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return (m.end(), i - 1) if depth == 0 else None


def read():
    try:
        with open(PATH, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def get():
    text = read()
    if text is None:
        return out({"ok": False, "error": "~/.config/rofi/config.rasi not found"}, 1)
    span = block_span(text)
    body = text[span[0]:span[1]] if span else ""
    res = {"ok": True}
    for k, d in KEYS.items():
        m = re.search(r"^\s*" + re.escape(k) + r"\s*:\s*(true|false)\s*;", body, re.M)
        res[k] = (m.group(1) == "true") if m else d
    return out(res)


def put(key, value):
    if key not in KEYS or value not in ("true", "false"):
        return out({"ok": False, "error": "unsupported option"}, 2)
    text = read()
    if text is None:
        text = "configuration {\n}\n"
    span = block_span(text)
    if span is None:
        text = "configuration {\n}\n" + text
        span = block_span(text)
    body = text[span[0]:span[1]]
    pat = re.compile(r"^(\s*)" + re.escape(key) + r"\s*:\s*[^;]*;", re.M)
    if pat.search(body):
        body = pat.sub(lambda m: "%s%s: %s;" % (m.group(1), key, value), body, count=1)
    else:
        body = body.rstrip() + "\n    %s: %s;\n" % (key, value)
    new = text[:span[0]] + body + text[span[1]:]
    if new != text:
        d = os.path.dirname(PATH)
        os.makedirs(d, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=d, prefix=".config.rasi.")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, PATH)
    return get()


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["get"]:
        sys.exit(get())
    if len(a) == 3 and a[0] == "set":
        sys.exit(put(a[1], a[2]))
    sys.stderr.write(__doc__)
    sys.exit(2)
