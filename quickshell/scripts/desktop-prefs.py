#!/usr/bin/env python3
"""Sleek Shell: system-wide fonts and icon theme.

  desktop-prefs.py list
      JSON: installed font families (ui / mono), icon themes with preview icon paths, and what
      each toolkit currently uses.
  desktop-prefs.py apply UI_FONT UI_SIZE MONO_FONT MONO_SIZE ICON_THEME
      Writes the choice to every place that honours it and prints JSON {ok, changed, skipped, errors}:
        GNOME/GTK  gsettings org.gnome.desktop.interface (font-name, document-font-name,
                   monospace-font-name, icon-theme) + ~/.config/gtk-{3,4}.0/settings.ini
        KDE/Qt     ~/.config/kdeglobals [General] fonts + [Icons] Theme (with change notification)
        fontconfig ~/.config/fontconfig/conf.d/50-sleek-shell.conf (sans-serif / monospace aliases)
        kitty      ~/.config/kitty/font.conf (included last by kitty.conf; running kittys reload)
        Rofi       font in ~/.config/rofi/themes/rice.rasi, icon-theme in ~/.config/rofi/config.rasi
        Cursor     (optional CURSOR SIZE) gsettings cursor-theme/size, gtk settings.ini, kcminputrc,
                   ~/.local/share/icons/default, ~/.config/sleek-shell/hypr-cursor.lua, hyprctl setcursor
      Files are only rewritten when their content changes. Nothing is ever run through a shell.
  desktop-prefs.py cursor THEME SIZE
      Only the cursor part of apply.
"""
import json, os, re, shutil, struct, subprocess, sys, zlib

HOME = os.path.expanduser("~")
CFG = os.environ.get("XDG_CONFIG_HOME", HOME + "/.config")
DATA = os.environ.get("XDG_DATA_HOME", HOME + "/.local/share")
ASSET_CACHE = os.environ.get("XDG_CACHE_HOME", HOME + "/.cache") + "/sleek-shell/assets"
CURSOR_CACHE = ASSET_CACHE + "/cursors"
ICON_BASES = [HOME + "/.icons", DATA + "/icons"] + [d.rstrip("/") + "/icons" for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if d]
USER_BASES = [HOME + "/.icons", DATA + "/icons", DATA + "/fonts", HOME + "/.fonts"]
SKIP_THEMES = {"hicolor", "locolor", "default"}
CURSOR_NAME = re.compile(r"^[\w.+\- ]{1,99}$")
CURSOR_SHAPES = [
    ("pointer", ["left_ptr", "default", "arrow", "top_left_arrow"]),
    ("hand", ["hand2", "pointer", "pointing_hand", "hand1", "hand"]),
    ("text", ["xterm", "text", "ibeam"]),
    ("wait", ["watch", "wait", "progress", "left_ptr_watch"]),
]
HAND_HINT = re.compile(r"script|hand|brush|marker|caveat|pacifico|vibes|satisfy|sacramento|amatic|kalam|flower|shadows into|signature|calligra|cursive", re.I)
SERIF_HINT = re.compile(r"serif(?! *sans)|garamond|times|georgia|merriweather|lora|playfair|baskerville|bodoni|caslon|slab|book", re.I)
DISPLAY_HINT = re.compile(r"display|bebas|lobster|orbitron|press start|bungee|anton|black ops|decor|poster", re.I)
SAMPLES = [
    ("folder", ["folder", "inode-directory"]),
    ("home", ["user-home", "folder-home"]),
    ("terminal", ["kitty", "utilities-terminal", "org.gnome.Terminal", "terminal"]),
    ("files", ["org.kde.dolphin", "system-file-manager", "org.gnome.Nautilus"]),
    ("browser", ["firefox", "web-browser", "internet-web-browser"]),
    ("settings", ["preferences-system", "systemsettings", "org.gnome.Settings"]),
    ("text", ["text-x-generic"]),
    ("image", ["image-x-generic"]),
]
MONO_HINT = re.compile(r"mono|code|consol|courier|hack|meslo|terminus|fixed", re.I)
NOISE = re.compile(r"^(.* CJK .*|.*Math.*|Noto (Sans|Serif|Kufi|Naskh|Nastaliq|Rashi|Music|Znamenny|Traditional|Fangsong)\b(?! (Mono|Display)$)(?!$)|Material (Symbols|Icons)|Noto Color Emoji|.*Nerd Font (Mono|Propo)$|.*NL Nerd Font|Symbols Nerd Font)", re.I)


def run(cmd, timeout=6):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, "", str(e)


# ------------------------------------------------------------------------------------- fonts
def fonts():
    rc, out, _ = run(["fc-list", ":lang=en", "--format", "%{family[0]}\t%{spacing}\n"])
    fams, mono = set(), set()
    if rc == 0:
        for line in out.splitlines():
            fam, _, sp = line.partition("\t")
            fam = fam.strip()
            if not fam or NOISE.match(fam):
                continue
            fams.add(fam)
            if sp.strip() in ("90", "100") or MONO_HINT.search(fam):
                mono.add(fam)
    ui = sorted(fams - {f for f in mono if MONO_HINT.search(f)}, key=str.lower)
    return ui, sorted(mono, key=str.lower), fams


# --------------------------------------------------------------------------------- icon themes
def parse_index(path):
    sec, data, cur = None, {}, None
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    cur = data.setdefault(line[1:-1], {})
                    continue
                if cur is not None and "=" in line:
                    k, _, v = line.partition("=")
                    cur[k.strip()] = v.strip()
    except OSError:
        return None
    return data


def theme_dirs(name):
    return [b + "/" + name for b in ICON_BASES if os.path.isfile(b + "/" + name + "/index.theme")]


def icon_themes():
    seen, out = set(), []
    for base in ICON_BASES:
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for n in names:
            if n in seen or n in SKIP_THEMES:
                continue
            idx = parse_index(base + "/" + n + "/index.theme")
            if not idx:
                continue
            it = idx.get("Icon Theme", {})
            if not it.get("Directories") or (it.get("Hidden", "").lower() == "true" and n != "Adwaita"):
                continue
            seen.add(n)
            out.append({"id": n, "name": it.get("Name", n), "comment": it.get("Comment", ""),
                        "dark": bool(re.search(r"dark", n, re.I)), "removable": user_owned(base + "/" + n), "preview": previews(n)})
    out.sort(key=lambda t: t["name"].lower())
    return out


def lookup(theme, names, size=48, visited=None):
    visited = visited if visited is not None else set()
    if theme in visited:
        return ""
    visited.add(theme)
    roots = theme_dirs(theme)
    if not roots:
        return ""
    idx = parse_index(roots[0] + "/index.theme") or {}
    it = idx.get("Icon Theme", {})
    dirs = [d for d in it.get("Directories", "").split(",") + it.get("ScaledDirectories", "").split(",") if d]

    def score(d):
        meta = idx.get(d, {})
        try:
            s = int(meta.get("Size", "0"))
        except ValueError:
            s = 0
        scale = meta.get("Scale", "1")
        sym = "symbolic" in d
        return (sym, scale != "1", 0 if meta.get("Type") == "Scalable" and s >= 32 else abs(s - size))

    dirs.sort(key=score)
    for name in names:
        for d in dirs:
            for r in roots:
                for ext in (".svg", ".png"):
                    p = "%s/%s/%s%s" % (r, d, name, ext)
                    if os.path.isfile(p):
                        return p
    for parent in [p for p in it.get("Inherits", "").split(",") if p]:
        if parent == "hicolor" and theme != "hicolor":
            continue
        r = lookup(parent.strip(), names, size, visited)
        if r:
            return r
    return ""


def previews(theme):
    return {k: lookup(theme, names) for k, names in SAMPLES}


def user_owned(path):
    real = os.path.realpath(path)
    return any(real.startswith(os.path.realpath(b) + os.sep) for b in USER_BASES)


# ------------------------------------------------------------------------------- cursor themes
def cursor_dirs(name):
    return [b + "/" + name for b in ICON_BASES if os.path.isdir(b + "/" + name + "/cursors")]


def cursor_themes():
    seen, out = set(), []
    for base in ICON_BASES:
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for n in names:
            if n in seen or n == "default" or not os.path.isdir(base + "/" + n + "/cursors"):
                continue
            if not CURSOR_NAME.match(n):
                continue
            seen.add(n)
            idx = parse_index(base + "/" + n + "/index.theme") or {}
            it = idx.get("Icon Theme", {})
            name = it.get("Name", n)
            if not name or name.lower() == "default":
                name = n
            out.append({"id": n, "name": name.replace("_", " "), "comment": it.get("Comment", ""),
                        "removable": user_owned(base + "/" + n), "preview": cursor_previews(n)})
    out.sort(key=lambda t: t["name"].lower())
    return out


def cursor_file(theme, names, visited=None):
    visited = visited if visited is not None else set()
    if theme in visited or len(visited) > 8:
        return ""
    visited.add(theme)
    for d in cursor_dirs(theme):
        for n in names:
            p = d + "/cursors/" + n
            if os.path.exists(p):
                return os.path.realpath(p)
    for d in [b + "/" + theme for b in ICON_BASES if os.path.isfile(b + "/" + theme + "/index.theme")][:1]:
        inh = (parse_index(d + "/index.theme") or {}).get("Icon Theme", {}).get("Inherits", "")
        for parent in [p.strip() for p in inh.split(",") if p.strip()]:
            r = cursor_file(parent, names, visited)
            if r:
                return r
    return ""


def xcursor_image(path, want=48):
    """Best image (closest nominal size to `want`) of an Xcursor file as (w, h, rgba bytes)."""
    try:
        with open(path, "rb") as fh:
            data = fh.read(4 << 20)
    except OSError:
        return None
    if data[:4] != b"Xcur" or len(data) < 16:
        return None
    _, _, ntoc = struct.unpack_from("<III", data, 4)
    best = None
    for i in range(min(ntoc, 512)):
        off = 16 + i * 12
        if off + 12 > len(data):
            break
        typ, sub, pos = struct.unpack_from("<III", data, off)
        if typ != 0xFFFD0002:
            continue
        key = (abs(sub - want), -sub)
        if best is None or key < best[0]:
            best = (key, pos)
    if not best:
        return None
    pos = best[1]
    if pos + 36 > len(data):
        return None
    _, _, _, _, w, h, _, _, _ = struct.unpack_from("<IIIIIIIII", data, pos)
    if not (0 < w <= 512 and 0 < h <= 512) or pos + 36 + w * h * 4 > len(data):
        return None
    px = data[pos + 36: pos + 36 + w * h * 4]
    rgba = bytearray(w * h * 4)
    for j in range(w * h):
        b, g, r, a = px[j * 4], px[j * 4 + 1], px[j * 4 + 2], px[j * 4 + 3]
        if a and a < 255:
            r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
        rgba[j * 4:j * 4 + 4] = bytes((r, g, b, a))
    return w, h, bytes(rgba)


def write_png(path, w, h, rgba):
    raw = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    tmp = path + ".tmp"
    with open(tmp, "wb") as fh:
        fh.write(png)
    os.replace(tmp, path)


def cursor_previews(theme):
    res = {}
    os.makedirs(CURSOR_CACHE, exist_ok=True)
    for key, names in CURSOR_SHAPES:
        src = cursor_file(theme, names)
        if not src:
            res[key] = ""
            continue
        try:
            stamp = int(os.path.getmtime(src))
        except OSError:
            res[key] = ""
            continue
        png = "%s/%s-%s-%d.png" % (CURSOR_CACHE, re.sub(r"[^A-Za-z0-9._-]", "_", theme), key, stamp)
        if not os.path.isfile(png):
            img = xcursor_image(src)
            if not img:
                res[key] = ""
                continue
            try:
                write_png(png, *img)
            except OSError:
                res[key] = ""
                continue
        res[key] = png
    return res


# ---------------------------------------------------------------------------- font library
def font_category(fam, mono, gf):
    c = gf.get(fam.lower())
    if c:
        return c
    if fam in mono or MONO_HINT.search(fam):
        return "mono"
    if HAND_HINT.search(fam):
        return "hand"
    if SERIF_HINT.search(fam):
        return "serif"
    if DISPLAY_HINT.search(fam):
        return "display"
    return "sans"


def library(ui, mono):
    """Every usable family with a category, flagged when it lives in the user's own font folder."""
    try:
        with open(ASSET_CACHE + "/google-fonts.json", encoding="utf-8") as fh:
            gf = {e["f"].lower(): e["c"] for e in json.load(fh).get("families", [])}
    except (OSError, ValueError, KeyError, TypeError):
        gf = {}
    try:
        with open(DATA + "/sleek-shell/assets.json", encoding="utf-8") as fh:
            for fam, v in (json.load(fh).get("fonts") or {}).items():
                if isinstance(v, dict) and v.get("category") in ("sans", "serif", "hand", "display", "mono"):
                    gf[fam.lower()] = v["category"]
    except (OSError, ValueError, AttributeError):
        pass
    user = set()
    rc, out, _ = run(["fc-list", "--format", "%{family[0]}\t%{file}\n"], timeout=15)
    for line in out.splitlines():
        fam, _, f = line.partition("\t")
        if fam.strip() and user_owned(f):
            user.add(fam.strip())
    monos = set(mono)
    return [{"f": f, "c": font_category(f, monos, gf), "user": f in user} for f in sorted(set(ui) | monos, key=str.lower)]


# ------------------------------------------------------------------------------------ current
def gget(key):
    rc, out, _ = run(["gsettings", "get", "org.gnome.desktop.interface", key])
    return out.strip("'") if rc == 0 else ""


def kget(group, key):
    if not shutil.which("kreadconfig6"):
        return ""
    return run(["kreadconfig6", "--file", "kdeglobals", "--group", group, "--key", key])[1]


def current():
    return {"gtkFont": gget("font-name"), "gtkMono": gget("monospace-font-name"), "gtkIcons": gget("icon-theme"),
            "qtFont": kget("General", "font"), "qtMono": kget("General", "fixed"), "qtIcons": kget("Icons", "Theme"),
            "cursor": gget("cursor-theme"), "cursorSize": gget("cursor-size").replace("uint32 ", "")}


# -------------------------------------------------------------------------------------- apply
class Result:
    def __init__(self):
        self.changed, self.skipped, self.errors = [], [], []


def write_if_changed(path, text, res, label):
    try:
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
    except OSError:
        old = None
    if old == text:
        return False
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".sleek-tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
        res.changed.append(label)
        return True
    except OSError as e:
        res.errors.append("%s: %s" % (label, e))
        return False


def set_ini(path, kv, res, label):
    try:
        lines = open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []
    except OSError as e:
        res.errors.append("%s: %s" % (label, e))
        return
    if not any(l.strip() == "[Settings]" for l in lines):
        lines = ["[Settings]"] + lines
    start = next(i for i, l in enumerate(lines) if l.strip() == "[Settings]")
    end = next((i for i in range(start + 1, len(lines)) if lines[i].strip().startswith("[")), len(lines))
    done = set()
    for i in range(start + 1, end):
        k = lines[i].split("=", 1)[0].strip()
        if k in kv:
            lines[i] = "%s=%s" % (k, kv[k])
            done.add(k)
    extra = ["%s=%s" % (k, v) for k, v in kv.items() if k not in done]
    lines[end:end] = extra
    write_if_changed(path, "\n".join(lines) + "\n", res, label)


def qt_font(family, size, weight=400):
    return "%s,%s,-1,5,%d,0,0,0,0,0,0,0,0,0,0,1" % (family, size, weight)


def fontconfig_xml(ui, mono):
    esc = lambda s: s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return ("<?xml version=\"1.0\"?>\n<!DOCTYPE fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\">\n"
            "<!-- Generated by Sleek Shell Settings > Fonts & icons. Delete this file to undo. -->\n<fontconfig>\n"
            "  <alias><family>sans-serif</family><prefer><family>%s</family></prefer></alias>\n"
            "  <alias><family>system-ui</family><prefer><family>%s</family></prefer></alias>\n"
            "  <alias><family>monospace</family><prefer><family>%s</family></prefer></alias>\n"
            "</fontconfig>\n") % (esc(ui), esc(ui), esc(mono))


def apply(ui, ui_size, mono, mono_size, icons, cursor=None, cursor_size=None):
    res = Result()
    _, _, families = fonts()
    themes = {t["id"] for t in icon_themes()}
    if ui not in families:
        return {"ok": False, "error": "Font '%s' is not installed" % ui}
    if mono not in families:
        return {"ok": False, "error": "Font '%s' is not installed" % mono}
    if icons not in themes:
        return {"ok": False, "error": "Icon theme '%s' is not installed" % icons}
    ui_size = max(7, min(24, int(round(float(ui_size)))))
    mono_size = max(7, min(28, int(round(float(mono_size)))))

    # GNOME / GTK (GTK3+4 on Wayland read gsettings; settings.ini is the fallback without dconf)
    if shutil.which("gsettings") and "org.gnome.desktop.interface" in run(["gsettings", "list-schemas"])[1].split():
        for key, val in (("font-name", "%s %d" % (ui, ui_size)), ("document-font-name", "%s %d" % (ui, ui_size)),
                         ("monospace-font-name", "%s %d" % (mono, mono_size)), ("icon-theme", icons)):
            if gget(key) != val:
                rc, _, err = run(["gsettings", "set", "org.gnome.desktop.interface", key, val])
                (res.changed.append("gsettings " + key) if rc == 0 else res.errors.append("gsettings %s: %s" % (key, err)))
    else:
        res.skipped.append("gsettings (schema not installed)")
    for v in ("3.0", "4.0"):
        set_ini("%s/gtk-%s/settings.ini" % (CFG, v), {"gtk-font-name": "%s %d" % (ui, ui_size), "gtk-icon-theme-name": icons}, res, "gtk-%s/settings.ini" % v)

    # KDE / Qt (QT_QPA_PLATFORMTHEME=kde reads kdeglobals; --notify updates running Qt apps)
    if shutil.which("kwriteconfig6"):
        want = {("General", "font"): qt_font(ui, ui_size), ("General", "menuFont"): qt_font(ui, ui_size),
                ("General", "toolBarFont"): qt_font(ui, max(7, ui_size - 1)),
                ("General", "smallestReadableFont"): qt_font(ui, max(7, ui_size - 2)),
                ("WM", "activeFont"): qt_font(ui, ui_size, 500), ("General", "fixed"): qt_font(mono, mono_size)}
        for (g, k), val in want.items():
            if kget(g, k) != val:
                rc, _, err = run(["kwriteconfig6", "--notify", "--file", "kdeglobals", "--group", g, "--key", k, val])
                (res.changed.append("kdeglobals %s/%s" % (g, k)) if rc == 0 else res.errors.append("kdeglobals %s: %s" % (k, err)))
        if kget("Icons", "Theme") != icons:
            if os.access("/usr/lib/plasma-changeicons", os.X_OK):
                rc, _, err = run(["/usr/lib/plasma-changeicons", icons])
            else:
                rc, _, err = run(["kwriteconfig6", "--notify", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme", icons])
            (res.changed.append("kdeglobals Icons/Theme") if rc == 0 else res.errors.append("Qt icons: " + err))
    else:
        res.skipped.append("kdeglobals (kwriteconfig6 not installed)")

    # fontconfig generic families
    write_if_changed(CFG + "/fontconfig/conf.d/50-sleek-shell.conf", fontconfig_xml(ui, mono), res, "fontconfig")

    # kitty
    kdir = CFG + "/kitty"
    if os.path.isdir(kdir):
        if write_if_changed(kdir + "/font.conf", "# Generated by Sleek Shell Settings > Fonts & icons.\nfont_family %s\nfont_size %d.0\n" % (mono, mono_size), res, "kitty font.conf"):
            if shutil.which("pkill"):
                run(["pkill", "-USR1", "-x", "kitty"])
        kconf = kdir + "/kitty.conf"
        try:
            text = open(kconf, encoding="utf-8").read() if os.path.exists(kconf) else ""
            if not re.search(r"^include font\.conf\s*$", text, re.M):
                write_if_changed(kconf, text.rstrip("\n") + "\n\n# Sleek Shell: font chosen in Settings > Fonts & icons\ninclude font.conf\n", res, "kitty.conf include")
        except OSError as e:
            res.errors.append("kitty.conf: %s" % e)
    else:
        res.skipped.append("kitty (no config dir)")

    # Rofi: only the global font in the "* { }" block and the icon theme
    rasi = CFG + "/rofi/themes/rice.rasi"
    if os.path.exists(rasi):
        t = open(rasi, encoding="utf-8").read()
        m = re.search(r"^\*\s*\{.*?^\}", t, re.S | re.M)
        if m:
            block = re.sub(r'(^\s*font:\s*)"[^"]*";', lambda x: '%s"%s %d";' % (x.group(1), ui, ui_size + 2), m.group(0), count=1, flags=re.M)
            write_if_changed(rasi, t[:m.start()] + block + t[m.end():], res, "rofi font")
    rcfg = CFG + "/rofi/config.rasi"
    if os.path.exists(rcfg):
        t = open(rcfg, encoding="utf-8").read()
        nt = re.sub(r'(^\s*icon-theme:\s*)"[^"]*";', lambda x: '%s"%s";' % (x.group(1), icons), t, count=1, flags=re.M)
        write_if_changed(rcfg, nt, res, "rofi icon-theme")

    if cursor:
        apply_cursor(cursor, cursor_size, res)

    return {"ok": not res.errors, "changed": res.changed, "skipped": res.skipped, "errors": res.errors}


def apply_cursor(theme, size, res):
    """Cursor theme + size for GTK, Qt/KDE, XWayland fallbacks and Hyprland itself."""
    if not CURSOR_NAME.match(theme) or not cursor_dirs(theme):
        res.errors.append("Cursor theme '%s' is not installed" % theme)
        return
    size = max(16, min(96, int(round(float(size or 24)))))
    touched = False
    if shutil.which("gsettings") and "org.gnome.desktop.interface" in run(["gsettings", "list-schemas"])[1].split():
        for key, val in (("cursor-theme", theme), ("cursor-size", str(size))):
            cur = gget(key).replace("uint32 ", "")
            if cur != val:
                rc, _, err = run(["gsettings", "set", "org.gnome.desktop.interface", key, val])
                (res.changed.append("gsettings " + key) if rc == 0 else res.errors.append("gsettings %s: %s" % (key, err)))
                touched = True
    for v in ("3.0", "4.0"):
        set_ini("%s/gtk-%s/settings.ini" % (CFG, v), {"gtk-cursor-theme-name": theme, "gtk-cursor-theme-size": str(size)}, res, "gtk-%s/settings.ini cursor" % v)
    if shutil.which("kwriteconfig6"):
        for k, val in (("cursorTheme", theme), ("cursorSize", str(size))):
            if run(["kreadconfig6", "--file", "kcminputrc", "--group", "Mouse", "--key", k])[1] != val:
                rc, _, err = run(["kwriteconfig6", "--notify", "--file", "kcminputrc", "--group", "Mouse", "--key", k, val])
                (res.changed.append("kcminputrc Mouse/" + k) if rc == 0 else res.errors.append("kcminputrc: " + err))
    write_if_changed(DATA + "/icons/default/index.theme",
                     "[Icon Theme]\nName=Default\nComment=Default cursor theme (set by Sleek Shell Settings)\nInherits=%s\n" % theme,
                     res, "icons/default cursor")
    state = ("-- Generated by Sleek Shell Settings. Do not edit by hand; use Settings (SUPER+I).\n"
             "return { theme = \"%s\", size = %d }\n") % (theme, size)
    touched = write_if_changed(CFG + "/sleek-shell/hypr-cursor.lua", state, res, "hyprland cursor") or touched
    if touched and shutil.which("hyprctl"):
        rc, out, err = run(["hyprctl", "setcursor", theme, str(size)])
        if rc != 0 or "ok" not in out.lower():
            res.errors.append("hyprctl setcursor: " + (err or out)[:160])
        run(["hyprctl", "eval", "require('sleekshell.cursor').apply()"])
    if touched and shutil.which("dbus-update-activation-environment"):
        run(["dbus-update-activation-environment", "--systemd", "XCURSOR_THEME=" + theme, "XCURSOR_SIZE=%d" % size])


def main(argv):
    if len(argv) >= 2 and argv[1] == "list":
        ui, mono, _ = fonts()
        print(json.dumps({"ok": True, "ui": ui, "mono": mono, "library": library(ui, mono), "icons": icon_themes(),
                          "cursors": cursor_themes(), "current": current()}))
        return 0
    if len(argv) in (7, 9) and argv[1] == "apply":
        try:
            r = apply(*argv[2:])
        except (ValueError, OSError) as e:
            r = {"ok": False, "error": str(e)}
        print(json.dumps(r))
        return 0 if r.get("ok") else 1
    if len(argv) == 4 and argv[1] == "cursor":
        res = Result()
        try:
            apply_cursor(argv[2], argv[3], res)
        except (ValueError, OSError) as e:
            res.errors.append(str(e))
        print(json.dumps({"ok": not res.errors, "changed": res.changed, "skipped": res.skipped, "errors": res.errors}))
        return 0 if not res.errors else 1
    print(json.dumps({"ok": False, "error": "usage: list | apply UI SIZE MONO SIZE ICONS [CURSOR SIZE] | cursor THEME SIZE"}))
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
