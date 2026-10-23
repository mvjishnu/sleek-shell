#!/usr/bin/env python3
"""Sleek Shell asset store: download fonts, icon themes and cursor themes (no root needed).

Everything goes to user-local directories:
  fonts         ~/.local/share/fonts/sleek-shell/<Family>/   (fc-cache refreshes afterwards)
  icon themes   ~/.local/share/icons/<Theme>/
  cursor themes ~/.local/share/icons/<Theme>/
A manifest (~/.local/share/sleek-shell/assets.json) remembers what each catalog entry installed.

Commands (all print one JSON object):
  catalog [--refresh]              Google Fonts families + curated icon / cursor themes, with installed flags
  install-font FAMILY              Google Fonts family (regular/bold + common weights, italics when available)
  install-icon ID                  curated icon theme
  install-cursor ID                curated cursor theme
  install-path PATH_OR_URL         local file / folder / archive or a download link; detects fonts
                                   (.ttf .otf .ttc), cursor themes (index.theme + cursors/) and icon themes
  remove font FAMILY | remove icon THEME | remove cursor THEME
                                   only removes things inside the user's own directories
  preview-fonts COLOR FAMILY...    PNG previews (family name drawn in its own face) for fonts that are
                                   not installed, rendered with ImageMagick from a tiny subset download
  starter                          installs the default variety pack (fonts, icon and cursor themes)

Icon themes marked "script" run the theme's own install.sh (from its GitHub repository) with
`-d ~/.local/share/icons`; everything else is copied from the archive without running anything.
"""
import concurrent.futures as cf
import hashlib, json, os, re, shutil, subprocess, sys, tarfile, tempfile, time, urllib.parse, urllib.request, zipfile

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME", HOME + "/.local/share")
CACHE = os.environ.get("XDG_CACHE_HOME", HOME + "/.cache") + "/sleek-shell/assets"
FONT_DIR = DATA + "/fonts/sleek-shell"
ICON_DIR = DATA + "/icons"
USER_ICON_DIRS = [ICON_DIR, HOME + "/.icons"]
USER_FONT_DIRS = [DATA + "/fonts", HOME + "/.fonts"]
MANIFEST = DATA + "/sleek-shell/assets.json"
META_CACHE = CACHE + "/google-fonts.json"
META_URL = "https://fonts.google.com/metadata/fonts"
UA = "curl/8.10.1"
CAT = {"Sans Serif": "sans", "Serif": "serif", "Handwriting": "hand", "Display": "display", "Monospace": "mono"}
FONT_EXT = (".ttf", ".otf", ".ttc")
ARCHIVE_EXT = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.zst")


def gh_src(repo, ref="HEAD"):
    return "https://codeload.github.com/%s/tar.gz/%s" % (repo, ref)


def gh_rel(repo, asset):
    return "https://github.com/%s/releases/latest/download/%s" % (repo, asset)


# ------------------------------------------------------------------------------- curated lists
# kind: script = run the repo's install.sh with -d DEST [args]; copy = copy dirs from the source
# archive (dirs: {path-in-archive: installed-name}, "*" globs keep their own name); release = any
# theme folders found inside a release archive. provides = theme folder names that mark it installed.
ICONS = [
    {"id": "tela-circle", "name": "Tela circle", "desc": "Flat, colourful circular app icons", "tone": "blue", "mb": 25,
     "kind": "script", "repo": "vinceliuice/Tela-circle-icon-theme", "provides": ["Tela-circle", "Tela-circle-dark"]},
    {"id": "tela-circle-dracula", "name": "Tela circle Dracula", "desc": "Tela circle in Dracula purple", "tone": "purple", "mb": 25,
     "kind": "script", "repo": "vinceliuice/Tela-circle-icon-theme", "args": ["dracula"], "provides": ["Tela-circle-dracula", "Tela-circle-dracula-dark"]},
    {"id": "tela-circle-nord", "name": "Tela circle Nord", "desc": "Tela circle in frosty Nord blue", "tone": "cyan", "mb": 25,
     "kind": "script", "repo": "vinceliuice/Tela-circle-icon-theme", "args": ["nord"], "provides": ["Tela-circle-nord", "Tela-circle-nord-dark"]},
    {"id": "colloid", "name": "Colloid", "desc": "Soft, rounded Material-style icons", "tone": "blue", "mb": 20,
     "kind": "script", "repo": "vinceliuice/Colloid-icon-theme", "provides": ["Colloid", "Colloid-Dark", "Colloid-Light"]},
    {"id": "qogir", "name": "Qogir", "desc": "Clean flat icons with a light touch", "tone": "cyan", "mb": 15,
     "kind": "script", "repo": "vinceliuice/Qogir-icon-theme", "provides": ["Qogir", "Qogir-Dark", "Qogir-Light"]},
    {"id": "whitesur", "name": "WhiteSur", "desc": "macOS Big Sur look-alike", "tone": "blue", "mb": 45,
     "kind": "script", "repo": "vinceliuice/WhiteSur-icon-theme", "provides": ["WhiteSur", "WhiteSur-dark", "WhiteSur-light"]},
    {"id": "mcmojave-circle", "name": "McMojave circle", "desc": "macOS Mojave style with round app icons", "tone": "blue", "mb": 30,
     "kind": "script", "repo": "vinceliuice/McMojave-circle", "provides": ["McMojave-circle", "McMojave-circle-dark", "McMojave-circle-light"]},
    {"id": "win11", "name": "Win11", "desc": "Windows 11 style icons", "tone": "blue", "mb": 25,
     "kind": "script", "repo": "yeyushengfan258/Win11-icon-theme", "provides": ["Win11", "Win11-dark"]},
    {"id": "vimix", "name": "Vimix", "desc": "Material icons with gem-coloured folders", "tone": "pink", "mb": 20,
     "kind": "script", "repo": "vinceliuice/vimix-icon-theme", "provides": ["Vimix", "Vimix-dark"]},
    {"id": "kora", "name": "Kora", "desc": "Semi-flat icons with soft shadows", "tone": "green", "mb": 40,
     "kind": "copy", "repo": "bikass/kora", "dirs": {"kora": "kora", "kora-pgrey": "kora-pgrey"}, "provides": ["kora"]},
    {"id": "candy", "name": "Candy", "desc": "Sweet gradient icons", "tone": "pink", "mb": 15,
     "kind": "copy", "repo": "EliverLara/candy-icons", "dirs": {".": "candy-icons"}, "provides": ["candy-icons"]},
    {"id": "beautyline", "name": "BeautyLine", "desc": "Neon gradient outline icons", "tone": "purple", "mb": 30,
     "kind": "copy", "repo": "gvolpe/BeautyLine", "dirs": {"BeautyLine*": "*"}, "provides": ["BeautyLine"]},
    {"id": "morewaita", "name": "MoreWaita", "desc": "Extends Adwaita with many more app icons", "tone": "blue", "mb": 15,
     "kind": "copy", "repo": "somepaulo/MoreWaita", "dirs": {".": "MoreWaita"}, "provides": ["MoreWaita"]},
    {"id": "flat-remix", "name": "Flat Remix", "desc": "Material flat icons with depth (blue, teal, red)", "tone": "blue", "mb": 60,
     "kind": "copy", "repo": "daniruiz/flat-remix", "provides": ["Flat-Remix-Blue-Dark"],
     "dirs": {"Flat-Remix-Blue-Dark": "Flat-Remix-Blue-Dark", "Flat-Remix-Blue-Light": "Flat-Remix-Blue-Light",
              "Flat-Remix-Teal-Dark": "Flat-Remix-Teal-Dark", "Flat-Remix-Red-Dark": "Flat-Remix-Red-Dark"}},
    {"id": "zafiro", "name": "Zafiro", "desc": "Minimal flat icons with washed-out colours", "tone": "cyan", "mb": 10,
     "kind": "copy", "repo": "zayronxio/Zafiro-icons", "dirs": {"Dark": "Zafiro-Dark", "Light": "Zafiro-Light"}, "provides": ["Zafiro-Dark"]},
    {"id": "nordzy", "name": "Nordzy", "desc": "Icons in the Nord palette", "tone": "cyan", "mb": 8,
     "kind": "release", "url": gh_rel("MolassesLover/Nordzy-icon", "Nordzy-dark.tar.gz"), "provides": ["Nordzy-dark"]},
    {"id": "gruvbox-plus", "name": "Gruvbox Plus", "desc": "Warm retro Gruvbox palette", "tone": "yellow", "mb": 50,
     "kind": "release", "url": gh_rel("SylEleuth/gruvbox-plus-icon-pack", "gruvbox-plus-icon-pack-6.6.0.zip"), "provides": ["Gruvbox-Plus-Dark"]},
]

CURSORS = [
    {"id": "bibata-modern-classic", "name": "Bibata Modern Classic", "desc": "Rounded black cursor", "tone": "#202020",
     "url": gh_rel("ful1e5/Bibata_Cursor", "Bibata-Modern-Classic.tar.xz"), "provides": ["Bibata-Modern-Classic"]},
    {"id": "bibata-modern-ice", "name": "Bibata Modern Ice", "desc": "Rounded white cursor", "tone": "#f4f4f4",
     "url": gh_rel("ful1e5/Bibata_Cursor", "Bibata-Modern-Ice.tar.xz"), "provides": ["Bibata-Modern-Ice"]},
    {"id": "bibata-modern-amber", "name": "Bibata Modern Amber", "desc": "Rounded amber cursor", "tone": "#ff9800",
     "url": gh_rel("ful1e5/Bibata_Cursor", "Bibata-Modern-Amber.tar.xz"), "provides": ["Bibata-Modern-Amber"]},
    {"id": "bibata-original-classic", "name": "Bibata Original Classic", "desc": "Sharp black cursor", "tone": "#202020",
     "url": gh_rel("ful1e5/Bibata_Cursor", "Bibata-Original-Classic.tar.xz"), "provides": ["Bibata-Original-Classic"]},
    {"id": "bibata-original-ice", "name": "Bibata Original Ice", "desc": "Sharp white cursor", "tone": "#f4f4f4",
     "url": gh_rel("ful1e5/Bibata_Cursor", "Bibata-Original-Ice.tar.xz"), "provides": ["Bibata-Original-Ice"]},
    {"id": "phinger", "name": "Phinger", "desc": "Friendly, playful cursors (dark and light)", "tone": "#3a3a3a",
     "url": gh_rel("phisch/phinger-cursors", "phinger-cursors-variants.tar.bz2"), "provides": ["phinger-cursors-dark", "phinger-cursors-light"]},
    {"id": "catppuccin-mocha-dark", "name": "Catppuccin Mocha", "desc": "Soft pastel dark cursor", "tone": "#1e1e2e",
     "url": gh_rel("catppuccin/cursors", "catppuccin-mocha-dark-cursors.zip"), "provides": ["catppuccin-mocha-dark-cursors"]},
    {"id": "catppuccin-mocha-lavender", "name": "Catppuccin Lavender", "desc": "Pastel lavender cursor", "tone": "#b4befe",
     "url": gh_rel("catppuccin/cursors", "catppuccin-mocha-lavender-cursors.zip"), "provides": ["catppuccin-mocha-lavender-cursors"]},
    {"id": "catppuccin-latte-light", "name": "Catppuccin Latte", "desc": "Soft pastel light cursor", "tone": "#eff1f5",
     "url": gh_rel("catppuccin/cursors", "catppuccin-latte-light-cursors.zip"), "provides": ["catppuccin-latte-light-cursors"]},
    {"id": "macos", "name": "macOS", "desc": "Apple style pointer", "tone": "#111111",
     "url": gh_rel("ful1e5/apple_cursor", "macOS.tar.xz"), "provides": ["macOS"]},
    {"id": "googledot-black", "name": "GoogleDot Black", "desc": "Material dot cursor, black", "tone": "#000000",
     "url": gh_rel("ful1e5/Google_Cursor", "GoogleDot-Black.tar.gz"), "provides": ["GoogleDot-Black"]},
    {"id": "googledot-blue", "name": "GoogleDot Blue", "desc": "Material dot cursor, blue", "tone": "#1a73e8",
     "url": gh_rel("ful1e5/Google_Cursor", "GoogleDot-Blue.tar.gz"), "provides": ["GoogleDot-Blue"]},
    {"id": "banana", "name": "Banana", "desc": "A banana. For your pointer.", "tone": "#ffe14d",
     "url": gh_rel("ful1e5/banana-cursor", "Banana.tar.xz"), "provides": ["Banana"]},
    {"id": "fuchsia", "name": "Fuchsia", "desc": "Fuchsia OS inspired cursor", "tone": "#202020",
     "url": gh_rel("ful1e5/fuchsia-cursor", "Fuchsia.tar.xz"), "provides": ["Fuchsia"]},
    {"id": "xcursor-pro-dark", "name": "XCursor Pro Dark", "desc": "Modern, crisp dark cursor", "tone": "#1b1b1b",
     "url": gh_rel("ful1e5/XCursor-pro", "XCursor-Pro-Dark.tar.xz"), "provides": ["XCursor-Pro-Dark"]},
    {"id": "xcursor-pro-light", "name": "XCursor Pro Light", "desc": "Modern, crisp light cursor", "tone": "#fafafa",
     "url": gh_rel("ful1e5/XCursor-pro", "XCursor-Pro-Light.tar.xz"), "provides": ["XCursor-Pro-Light"]},
    {"id": "rosepine", "name": "Rose Pine", "desc": "BreezeX in Rose Pine", "tone": "#191724",
     "url": gh_rel("rose-pine/cursors", "BreezeX-RosePine-Linux.tar.xz"), "provides": ["BreezeX-RosePine-Linux"]},
    {"id": "rosepine-dawn", "name": "Rose Pine Dawn", "desc": "BreezeX in Rose Pine Dawn", "tone": "#faf4ed",
     "url": gh_rel("rose-pine/cursors", "BreezeX-RosePineDawn-Linux.tar.xz"), "provides": ["BreezeX-RosePineDawn-Linux"]},
    {"id": "nordzy-cursors", "name": "Nordzy", "desc": "Nord palette cursor", "tone": "#2e3440",
     "url": gh_rel("guillaumeboehm/Nordzy-cursors", "Nordzy-cursors.tar.gz"), "provides": ["Nordzy-cursors"]},
    {"id": "nordzy-cursors-white", "name": "Nordzy White", "desc": "Nord palette cursor, white", "tone": "#eceff4",
     "url": gh_rel("guillaumeboehm/Nordzy-cursors", "Nordzy-cursors-white.tar.gz"), "provides": ["Nordzy-cursors-white"]},
    {"id": "capitaine", "name": "Capitaine", "desc": "macOS inspired, based on KDE Breeze", "tone": "#111111",
     "url": gh_rel("sainnhe/capitaine-cursors", "Linux.zip"), "provides": ["Capitaine Cursors"]},
]

STARTER = {
    "fonts": ["Caveat", "Dancing Script", "Pacifico", "Indie Flower", "Kalam", "Shadows Into Light", "Satisfy",
              "Great Vibes", "Permanent Marker", "Patrick Hand", "Amatic SC", "Sacramento",
              "Lora", "Merriweather", "Playfair Display", "EB Garamond",
              "Inter", "Poppins", "Nunito", "Montserrat", "Lexend", "Work Sans", "Quicksand",
              "Bebas Neue", "Lobster", "Press Start 2P", "Orbitron",
              "JetBrains Mono", "Fira Code", "Victor Mono", "Space Mono", "IBM Plex Mono"],
    "icons": ["tela-circle", "colloid", "qogir", "candy", "kora", "flat-remix"],
    "cursors": ["bibata-modern-classic", "bibata-modern-ice", "phinger", "catppuccin-mocha-dark", "macos",
                "googledot-black", "banana", "rosepine"],
}

# offline fallback when the Google Fonts catalogue cannot be fetched
FALLBACK_FONTS = {"hand": STARTER["fonts"][:12], "serif": STARTER["fonts"][12:16], "sans": STARTER["fonts"][16:23],
                  "display": STARTER["fonts"][23:27], "mono": STARTER["fonts"][27:]}


# ------------------------------------------------------------------------------------- helpers
class Fail(Exception):
    pass


def out(obj):
    print(json.dumps(obj))
    sys.stdout.flush()


def run(cmd, timeout=60, cwd=None):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, "", str(e)


def fetch(url, dest=None, timeout=60):
    """GET url; returns bytes, or writes to dest and returns dest."""
    if not re.match(r"^https?://", url):
        raise Fail("Only http(s) links can be downloaded")
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            if dest is None:
                return r.read()
            with open(dest, "wb") as fh:
                shutil.copyfileobj(r, fh, 1 << 16)
            return dest
    except Exception as e:  # urllib raises many types (HTTPError, URLError, socket errors, ...)
        raise Fail("Download failed (%s): %s" % (urllib.parse.urlsplit(url).netloc, getattr(e, "reason", e)))


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent=1)
    os.replace(tmp, path)


def manifest():
    m = load_json(MANIFEST, {})
    for k in ("fonts", "icons", "cursors"):
        if not isinstance(m.get(k), dict):
            m[k] = {}
    return m


def record(kind, key, value):
    m = manifest()
    m[kind][key] = value
    save_json(MANIFEST, m)


def safe_name(n):
    return bool(n) and n not in (".", "..") and "/" not in n and len(n) < 120 and not n.startswith(".")


def theme_exists(name):
    return any(os.path.isfile("%s/%s/index.theme" % (b, name)) for b in
               USER_ICON_DIRS + [d.rstrip("/") + "/icons" for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if d])


def installed_families():
    rc, o, _ = run(["fc-list", "--format", "%{family}\n"], timeout=20)
    fams = set()
    for line in o.splitlines():
        for f in line.split(","):
            if f.strip():
                fams.add(f.strip())
    return fams


def extract(archive, dest):
    """Extract a zip / tar archive safely (no absolute paths, no escaping the destination)."""
    low = archive.lower()
    root = os.path.realpath(dest)
    if low.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            for n in z.namelist():
                p = os.path.realpath(os.path.join(dest, n))
                if p != root and not p.startswith(root + os.sep):
                    raise Fail("Archive contains unsafe paths")
            links = []
            for info in z.infolist():
                if (info.external_attr >> 16) & 0o170000 == 0o120000:
                    links.append(info)
                else:
                    z.extract(info, dest)
            for info in links:
                target = z.read(info).decode("utf-8", "replace").strip()
                p = os.path.join(dest, info.filename.rstrip("/"))
                resolved = os.path.realpath(os.path.join(os.path.dirname(p), target))
                if os.path.isabs(target) or not (resolved == root or resolved.startswith(root + os.sep)):
                    continue
                os.makedirs(os.path.dirname(p), exist_ok=True)
                if os.path.lexists(p):
                    os.remove(p)
                os.symlink(target, p)
        return
    if low.endswith(".tar.zst") or low.endswith(".tzst"):
        rc, _, err = run(["bsdtar", "-xf", archive, "-C", dest], timeout=600)
        if rc != 0:
            raise Fail("Could not unpack: " + err[:200])
        return
    try:
        with tarfile.open(archive) as t:
            t.extractall(dest, filter="data")
    except (tarfile.TarError, OSError) as e:
        rc, _, err = run(["bsdtar", "-xf", archive, "-C", dest], timeout=600)
        if rc != 0:
            raise Fail("Could not unpack the archive: %s" % e)


def is_archive(name):
    low = name.lower()
    return any(low.endswith(e) for e in ARCHIVE_EXT)


def copy_theme(src, name):
    if not safe_name(name):
        raise Fail("Bad theme name: %r" % name)
    os.makedirs(ICON_DIR, exist_ok=True)
    dst = ICON_DIR + "/" + name
    if os.path.lexists(dst):
        shutil.rmtree(dst) if os.path.isdir(dst) and not os.path.islink(dst) else os.remove(dst)
    shutil.copytree(src, dst, symlinks=True, ignore=shutil.ignore_patterns(".git", ".github", "*.md", "LICENSE*", "install.sh"))
    if shutil.which("gtk-update-icon-cache") and not os.path.isdir(dst + "/cursors"):
        run(["gtk-update-icon-cache", "-q", "-f", "-t", dst], timeout=120)
    return name


def read_index(path):
    data, cur = {}, None
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("[") and line.endswith("]"):
                    cur = data.setdefault(line[1:-1], {})
                elif cur is not None and "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    cur[k.strip()] = v.strip()
    except OSError:
        pass
    return data


def scan_themes(root):
    """(cursor_dirs, icon_dirs) found under root: folders with index.theme."""
    cursors, icons = [], []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "src", "node_modules")]
        if "index.theme" not in filenames:
            continue
        if os.path.isdir(dirpath + "/cursors"):
            cursors.append(dirpath)
            dirnames[:] = []
        elif read_index(dirpath + "/index.theme").get("Icon Theme", {}).get("Directories"):
            icons.append(dirpath)
            dirnames[:] = []
    return cursors, icons


def theme_name_for(path):
    base = os.path.basename(path.rstrip("/"))
    return base if safe_name(base) else None


def fc_refresh(path):
    if shutil.which("fc-cache"):
        run(["fc-cache", "-f", path], timeout=180)


# ------------------------------------------------------------------------------- Google Fonts
def gf_meta(refresh=False):
    cached = load_json(META_CACHE, None)
    fresh = cached and time.time() - cached.get("at", 0) < 7 * 86400
    if cached and fresh and not refresh:
        return cached["families"]
    try:
        raw = fetch(META_URL, timeout=30).decode("utf-8", "replace")
        o = json.loads(raw[raw.index("{"):])
        fams = []
        for e in o.get("familyMetadataList", []):
            if "latin" not in e.get("subsets", []) or e.get("category") not in CAT:
                continue
            fonts = e.get("fonts") or {}
            fams.append({"f": e["family"], "c": CAT[e["category"]], "p": int(e.get("popularity") or 9999),
                         "s": len(fonts), "w": sorted(fonts.keys()), "v": bool(e.get("axes")),
                         "color": bool(e.get("colorCapabilities"))})
        fams.sort(key=lambda x: x["p"])
        save_json(META_CACHE, {"at": time.time(), "families": fams})
        return fams
    except (Fail, ValueError, KeyError):
        if cached:
            return cached["families"]
        return [{"f": f, "c": c, "p": i, "s": 0, "w": ["400"], "v": False, "color": False}
                for c, lst in FALLBACK_FONTS.items() for i, f in enumerate(lst)]


def gf_entry(family):
    for e in gf_meta():
        if e["f"].lower() == family.lower():
            return e
    return None


def css2_urls(query):
    css = fetch("https://fonts.googleapis.com/css2?" + query, timeout=30).decode("utf-8", "replace")
    faces = []
    for block in re.findall(r"@font-face\s*\{(.*?)\}", css, re.S):
        url = re.search(r"url\((https://[^)]+)\)", block)
        if not url:
            continue
        w = re.search(r"font-weight:\s*(\d+)", block)
        it = re.search(r"font-style:\s*italic", block)
        faces.append((int(w.group(1)) if w else 400, bool(it), url.group(1)))
    return faces


def pick_weights(keys):
    normal = sorted(int(k) for k in keys if k.isdigit())
    italic = sorted(int(k[:-1]) for k in keys if k.endswith("i") and k[:-1].isdigit())
    want = [w for w in normal if w in (300, 400, 500, 600, 700)] or ([min(normal, key=lambda w: abs(w - 400))] if normal else [])
    wit = [w for w in italic if w in (400, 700)] or ([min(italic, key=lambda w: abs(w - 400))] if italic and not normal else [])
    return want, wit


def install_font(family):
    e = gf_entry(family)
    if not e:
        raise Fail("'%s' is not in the Google Fonts catalogue" % family)
    family = e["f"]
    normal, italic = pick_weights(e.get("w") or ["400"])
    fam = urllib.parse.quote_plus(family)
    if italic:
        spec = ";".join(["0,%d" % w for w in normal] + ["1,%d" % w for w in italic])
        query = "family=%s:ital,wght@%s" % (fam, spec)
    elif normal and normal != [400]:
        query = "family=%s:wght@%s" % (fam, ";".join(str(w) for w in normal))
    else:
        query = "family=" + fam
    faces = css2_urls(query + "&display=swap")
    if not faces:
        raise Fail("Google Fonts returned no files for '%s'" % family)
    slug = re.sub(r"[^A-Za-z0-9]+", "", family) or hashlib.sha1(family.encode()).hexdigest()[:10]
    final = FONT_DIR + "/" + slug
    tmp = final + ".part"
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    seen = {}
    for w, it, url in faces:
        seen[(w, it)] = url
    jobs = [("%s/%s-%d%s.ttf" % (tmp, slug, w, "Italic" if it else ""), url) for (w, it), url in sorted(seen.items())]
    with cf.ThreadPoolExecutor(6) as ex:
        list(ex.map(lambda j: fetch(j[1], j[0], timeout=120), jobs))
    shutil.rmtree(final, ignore_errors=True)
    os.replace(tmp, final)
    fc_refresh(final)
    files = sorted(final + "/" + f for f in os.listdir(final))
    record("fonts", family, {"dir": final, "category": e["c"]})
    return {"ok": True, "kind": "font", "family": family, "files": files, "category": e["c"]}


def preview_fonts(color, families):
    if not re.match(r"^#[0-9a-fA-F]{6}$", color):
        color = "#e6e6f0"
    pdir = CACHE + "/previews"
    os.makedirs(pdir, exist_ok=True)
    magick = shutil.which("magick") or shutil.which("convert")
    res = {}

    def one(fam):
        key = hashlib.sha1((fam + "|" + color + "|v2").encode()).hexdigest()[:16]
        png = "%s/%s.png" % (pdir, key)
        if os.path.isfile(png) and os.path.getsize(png) > 0:
            return fam, png
        if not magick:
            return fam, ""
        text = fam
        try:
            faces = css2_urls("family=%s&text=%s" % (urllib.parse.quote_plus(fam), urllib.parse.quote(text)))
            if not faces:
                return fam, ""
            ttf = "%s/%s.ttf" % (pdir, key)
            fetch(faces[0][2], ttf, timeout=30)
            rc, _, _ = run([magick, "-background", "none", "-fill", color, "-font", ttf, "-pointsize", "44",
                            "label:" + text.replace("%", "%%").lstrip("@"), "-trim", "+repage", png], timeout=30)
            try:
                os.remove(ttf)
            except OSError:
                pass
            return fam, png if rc == 0 and os.path.isfile(png) else ""
        except Fail:
            return fam, ""

    with cf.ThreadPoolExecutor(8) as ex:
        for fam, png in ex.map(one, families[:80]):
            if png:
                res[fam] = png
    return {"ok": True, "previews": res}


# ------------------------------------------------------------------------- icon / cursor themes
def find_entry(lst, ident):
    for e in lst:
        if e["id"] == ident:
            return e
    raise Fail("Unknown catalog entry '%s'" % ident)


def download_to(tmpdir, url, name="download"):
    tail = urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1] or name
    if "codeload.github.com" in url and not is_archive(tail):
        tail = name + ".tar.gz"
    path = os.path.join(tmpdir, re.sub(r"[^A-Za-z0-9._+-]", "_", tail))
    return fetch(url, path, timeout=900)


def top_dir(root):
    entries = [e for e in os.listdir(root) if not e.startswith(".")]
    if len(entries) == 1 and os.path.isdir(os.path.join(root, entries[0])):
        return os.path.join(root, entries[0])
    return root


def icon_names():
    try:
        return set(os.listdir(ICON_DIR))
    except OSError:
        return set()


def install_icon(ident):
    e = find_entry(ICONS, ident)
    with tempfile.TemporaryDirectory(prefix="sleek-assets-") as tmp:
        if e["kind"] == "script":
            arc = download_to(tmp, gh_src(e["repo"]), e["id"])
            src = tmp + "/src"
            os.makedirs(src)
            extract(arc, src)
            src = top_dir(src)
            if not os.path.isfile(src + "/install.sh"):
                raise Fail("The theme's install.sh is missing")
            os.makedirs(ICON_DIR, exist_ok=True)
            before = {n: os.path.getmtime(ICON_DIR + "/" + n) for n in icon_names()}
            rc, o, err = run(["bash", "install.sh", "-d", ICON_DIR] + e.get("args", []), timeout=1800, cwd=src)
            after = icon_names()
            new = sorted(n for n in after if n not in before or os.path.getmtime(ICON_DIR + "/" + n) != before[n])
            new = [n for n in new if os.path.isfile("%s/%s/index.theme" % (ICON_DIR, n))]
            if rc != 0 and not new:
                raise Fail("install.sh failed: " + (err or o)[-300:])
        elif e["kind"] == "copy":
            arc = download_to(tmp, gh_src(e["repo"]), e["id"])
            src = tmp + "/src"
            os.makedirs(src)
            extract(arc, src)
            src = top_dir(src)
            new = []
            import fnmatch
            for pat, name in e["dirs"].items():
                if "*" in pat:
                    for d in sorted(os.listdir(src)):
                        if fnmatch.fnmatch(d, pat) and os.path.isfile("%s/%s/index.theme" % (src, d)):
                            new.append(copy_theme(src + "/" + d, d))
                elif os.path.isfile("%s/%s/index.theme" % (src, pat)):
                    new.append(copy_theme(os.path.normpath(src + "/" + pat), name))
        else:
            arc = download_to(tmp, e["url"], e["id"])
            src = tmp + "/src"
            os.makedirs(src)
            extract(arc, src)
            _, icons = scan_themes(src)
            new = [copy_theme(d, theme_name_for(d)) for d in icons if theme_name_for(d)]
        if not new:
            raise Fail("No icon themes were found in the download")
    record("icons", ident, new)
    return {"ok": True, "kind": "icon", "id": ident, "themes": new}


def install_cursor(ident):
    e = find_entry(CURSORS, ident)
    with tempfile.TemporaryDirectory(prefix="sleek-assets-") as tmp:
        arc = download_to(tmp, e["url"], e["id"])
        src = tmp + "/src"
        os.makedirs(src)
        extract(arc, src)
        cursors, _ = scan_themes(src)
        new = [copy_theme(d, theme_name_for(d)) for d in cursors if theme_name_for(d)]
        if not new:
            raise Fail("No cursor themes were found in the download")
    record("cursors", ident, new)
    return {"ok": True, "kind": "cursor", "id": ident, "themes": new}


def install_path(target):
    target = target.strip()
    if target.startswith("file://"):
        target = urllib.parse.unquote(target[7:])
    target = os.path.expanduser(target)
    with tempfile.TemporaryDirectory(prefix="sleek-assets-") as tmp:
        if re.match(r"^https?://", target):
            target = download_to(tmp, target, "download")
        if not os.path.exists(target):
            raise Fail("Not found: %s" % target)
        root = target
        if os.path.isfile(target):
            low = target.lower()
            if low.endswith(FONT_EXT):
                root = tmp + "/single"
                os.makedirs(root)
                shutil.copy2(target, root)
            elif is_archive(low):
                root = tmp + "/src"
                os.makedirs(root)
                extract(target, root)
            else:
                raise Fail("Unsupported file: use a .ttf/.otf font, a .zip/.tar.* archive or a theme folder")
        cursors, icons = scan_themes(root)
        got_c = [copy_theme(d, theme_name_for(d)) for d in cursors if theme_name_for(d)]
        got_i = [copy_theme(d, theme_name_for(d)) for d in icons if theme_name_for(d)]
        theme_roots = cursors + icons
        font_files = []
        for dirpath, dirnames, filenames in os.walk(root):
            if any(dirpath == t or dirpath.startswith(t + os.sep) for t in theme_roots):
                continue
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d != "__MACOSX"]
            for f in filenames:
                if f.lower().endswith(FONT_EXT) and not f.startswith("._"):
                    font_files.append(os.path.join(dirpath, f))
        families, dest_files = [], []
        if font_files:
            dest = FONT_DIR + "/imported"
            os.makedirs(dest, exist_ok=True)
            for f in font_files:
                d = dest + "/" + os.path.basename(f)
                shutil.copy2(f, d)
                dest_files.append(d)
                rc, o, _ = run(["fc-scan", "--format", "%{family[0]}\n", d], timeout=20)
                for fam in o.splitlines():
                    if fam.strip() and fam.strip() not in families:
                        families.append(fam.strip())
                        record("fonts", fam.strip(), {"dir": dest, "files": [d], "category": "imported"})
            fc_refresh(dest)
    if not (got_c or got_i or families):
        raise Fail("Nothing to install: no fonts or icon / cursor themes were found there")
    return {"ok": True, "kind": "path", "fonts": families, "files": dest_files, "icons": got_i, "cursors": got_c}


def user_owned(path):
    real = os.path.realpath(path)
    return any(real.startswith(os.path.realpath(b) + os.sep) for b in USER_ICON_DIRS + USER_FONT_DIRS)


def remove(kind, name):
    if kind in ("icon", "cursor"):
        if not safe_name(name):
            raise Fail("Bad theme name")
        hits = [b + "/" + name for b in USER_ICON_DIRS if os.path.isdir(b + "/" + name)]
        if not hits:
            raise Fail("'%s' is not in your own icons folder (system themes are removed with the package manager)" % name)
        for h in hits:
            if user_owned(h) or os.path.islink(h):
                shutil.rmtree(h) if not os.path.islink(h) else os.remove(h)
        m = manifest()
        bucket = m["icons" if kind == "icon" else "cursors"]
        for k in list(bucket):
            bucket[k] = [t for t in bucket[k] if t != name]
            if not bucket[k]:
                del bucket[k]
        save_json(MANIFEST, m)
        return {"ok": True, "removed": name}
    if kind == "font":
        rc, o, _ = run(["fc-list", "--format", "%{file}\t%{family}\n"], timeout=20)
        files = []
        for line in o.splitlines():
            f, _, fams = line.partition("\t")
            if name in [x.strip() for x in fams.split(",")] and user_owned(f):
                files.append(f)
        if not files:
            raise Fail("'%s' is not installed in your own fonts folder" % name)
        dirs = set()
        for f in files:
            try:
                os.remove(f)
                dirs.add(os.path.dirname(f))
            except OSError:
                pass
        for d in dirs:
            if d.startswith(FONT_DIR + "/") and d != FONT_DIR + "/imported":
                try:
                    if not [x for x in os.listdir(d) if x.lower().endswith(FONT_EXT)]:
                        shutil.rmtree(d)
                except OSError:
                    pass
            fc_refresh(d if os.path.isdir(d) else os.path.dirname(d))
        m = manifest()
        m["fonts"].pop(name, None)
        save_json(MANIFEST, m)
        return {"ok": True, "removed": name}
    raise Fail("remove: kind must be font, icon or cursor")


# ------------------------------------------------------------------------------------- catalog
def catalog(refresh=False):
    fams = installed_families()
    m = manifest()
    fonts = []
    for e in gf_meta(refresh):
        fonts.append({"f": e["f"], "c": e["c"], "p": e["p"], "s": e["s"], "i": e["f"] in fams})

    def flag(lst, bucket):
        res = []
        for e in lst:
            got = [t for t in m[bucket].get(e["id"], []) if theme_exists(t)] or [t for t in e.get("provides", []) if theme_exists(t)]
            item = {k: e[k] for k in ("id", "name", "desc", "tone") if k in e}
            item["mb"] = e.get("mb", 0)
            item["script"] = e.get("kind") == "script"
            item["installed"] = bool(got)
            item["themes"] = got
            res.append(item)
        return res

    counts = {}
    for f in fonts:
        counts[f["c"]] = counts.get(f["c"], 0) + 1
    return {"ok": True, "fonts": fonts, "fontCounts": counts, "icons": flag(ICONS, "icons"), "cursors": flag(CURSORS, "cursors"),
            "starter": STARTER, "dirs": {"fonts": FONT_DIR, "icons": ICON_DIR}}


def starter():
    done, failed = [], []
    fams = installed_families()
    m = manifest()
    for f in STARTER["fonts"]:
        if f in fams:
            continue
        try:
            install_font(f)
            done.append(f)
        except Fail as e:
            failed.append("%s: %s" % (f, e))
    for ident in STARTER["icons"]:
        e = find_entry(ICONS, ident)
        if any(theme_exists(t) for t in e.get("provides", [])) or m["icons"].get(ident):
            continue
        try:
            install_icon(ident)
            done.append(e["name"])
        except Fail as x:
            failed.append("%s: %s" % (e["name"], x))
    for ident in STARTER["cursors"]:
        e = find_entry(CURSORS, ident)
        if any(theme_exists(t) for t in e.get("provides", [])) or m["cursors"].get(ident):
            continue
        try:
            install_cursor(ident)
            done.append(e["name"])
        except Fail as x:
            failed.append("%s: %s" % (e["name"], x))
    return {"ok": not failed, "kind": "starter", "installed": done, "errors": failed}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    try:
        if cmd == "catalog":
            r = catalog("--refresh" in argv)
        elif cmd == "install-font" and len(argv) == 3:
            r = install_font(argv[2])
        elif cmd == "install-icon" and len(argv) == 3:
            r = install_icon(argv[2])
        elif cmd == "install-cursor" and len(argv) == 3:
            r = install_cursor(argv[2])
        elif cmd == "install-path" and len(argv) == 3:
            r = install_path(argv[2])
        elif cmd == "remove" and len(argv) == 4:
            r = remove(argv[2], argv[3])
        elif cmd == "preview-fonts" and len(argv) >= 3:
            r = preview_fonts(argv[2], argv[3:])
        elif cmd == "starter":
            r = starter()
        else:
            r = {"ok": False, "error": "usage: catalog | install-font F | install-icon ID | install-cursor ID | "
                                       "install-path P | remove KIND NAME | preview-fonts COLOR F... | starter"}
    except Fail as e:
        r = {"ok": False, "error": str(e)}
    except (OSError, shutil.Error, zipfile.BadZipFile) as e:
        r = {"ok": False, "error": "%s: %s" % (type(e).__name__, e)}
    out(r)
    return 0 if r.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
