#!/usr/bin/env bash
# Propagates the Quickshell theme to the themed applications.
#
# Reads the theme export (argument 1, normally ~/.config/sleek-shell/theme-export.json,
# written by services/Theme.qml) and rewrites the colour blocks in:
#   kitty   ~/.config/kitty/theme.conf      (included by kitty.conf)
#   rofi    ~/.config/rofi/themes/rice.rasi and control-center.rasi
#   alacritty ~/.config/alacritty/theme.toml (imported without replacing user options)
#   GTK3/4  ~/.config/gtk-{3,4}.0/gtk.css
#   micro   ~/.config/micro/colorschemes/rice.micro
#   KDE/Qt  ~/.config/kdeglobals + ~/.local/share/color-schemes/Rice.colors
#
# Only the generated blocks are touched; everything else in those files is kept.
# If jq is missing, or the export file is absent, the script exits quietly so a
# missing theme never breaks startup or the shell.
#
# The exported mode controls every generated app palette: light mode uses
# paper surfaces with dark text, while dark mode follows the selected tint.
set -u

command -v jq >/dev/null || exit 0

# Sleek Shell passes the export file explicitly; the search is the pre-Sleek Shell fallback.
EXPORT="${1:-}"
if [ -z "$EXPORT" ]; then
    STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    EXPORT="$(find "$STATE_ROOT" -name theme-export.json -type f -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n1 | cut -d' ' -f2-)"
fi
[ -n "$EXPORT" ] && [ -f "$EXPORT" ] || exit 0

read -r GLASS MODE STYLE FONT_FAMILY < <(jq -r '"\(.glass) \(.mode // "dark") \(.styleMode // "glass") \(.fontFamily // "")"' "$EXPORT")
read -r BORDER_WIDTH BORDER_COLOR < <(jq -r '"\(.borderWidth // 0) \(.borderColor // .accent)"' "$EXPORT")
read -r WINDOW_RADIUS SHELL_BORDERS < <(jq -r '"\(.windowRounding // 14) \(if has("shellBorders") then .shellBorders else true end)"' "$EXPORT")
[ "$MODE" = "light" ] || MODE="dark"
BORDER_WIDTH=$((BORDER_WIDTH > 0 ? BORDER_WIDTH : 0))
WINDOW_RADIUS=$((WINDOW_RADIUS < 0 ? 0 : (WINDOW_RADIUS > 30 ? 30 : WINDOW_RADIUS)))
SURFACE_RADIUS=$((WINDOW_RADIUS * 3 / 4))
ITEM_RADIUS=$((WINDOW_RADIUS / 2))
FONT_FAMILY="$(printf '%s' "${FONT_FAMILY:-}" | tr -cd '[:alnum:] ._-')"

# Per-app policy (written by Theme.qml from ~/.config/sleek-shell/app-themes.json):
#   .apps.<id>.on == false   -> excluded, the app's files are not touched
#   .apps.<id>.tintR etc.    -> custom palette for that app; missing fields inherit the shell theme
# Exports without .apps (older shells) theme every app.
app_on() { [ "$(jq -r --arg a "$1" '.apps[$a].on == false' "$EXPORT")" != true ]; }
load_app() {
    read -r TINT_R TINT_G TINT_B ACCENT TEXT MUTED DIM APP_SURFACE APP_SURFACE_HI < <(
        jq -r --arg a "$1" '(.apps[$a] // {}) as $p |
            "\($p.tintR // .tintR) \($p.tintG // .tintG) \($p.tintB // .tintB) \($p.accent // .accent) \($p.text // .text) \($p.muted // .muted) \($p.dim // .dim) \($p.surface // .surface // "") \($p.surfaceHi // .surfaceHi // "")"' "$EXPORT")
    [ -n "${TINT_R:-}" ] && [ "$TINT_R" != null ] || return 1
    compute
}

hex2rgb() { # "#rrggbb" -> "r g b"
    local h="${1#\#}"
    printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}
compute() {
read -r AR AG AB < <(hex2rgb "$ACCENT")
[ -n "${AR:-}" ] || { AR=124; AG=156; AB=255; }

# Tonal helpers: blend the tint toward black/white by a percentage (0-100).
mix() { # base_r base_g base_b target_r target_g target_b pct
    awk -v r1="$1" -v g1="$2" -v b1="$3" -v r2="$4" -v g2="$5" -v b2="$6" -v t="$7" \
        'BEGIN{ p=t/100; printf "%d %d %d", r1+(r2-r1)*p, g1+(g2-g1)*p, b1+(b2-b1)*p }'
}
to_hex() { printf '#%02x%02x%02x' "$1" "$2" "$3"; }

if [ "$MODE" = "light" ]; then
BG0=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 0 0 0 5)
BG1=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 0 0 0 2)
BG2="$TINT_R $TINT_G $TINT_B"
BG3=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 255 255 255 6)
BG4=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 255 255 255 12)
else
BG0=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 0 0 0 35)
BG1=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 0 0 0 15)
BG2="$TINT_R $TINT_G $TINT_B"
BG3=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 255 255 255 12)
BG4=$(mix "$TINT_R" "$TINT_G" "$TINT_B" 255 255 255 22)
fi

color() { to_hex $1 $2 $3; }
C_BG0=$(color $BG0); C_BG1=$(color $BG1); C_BG2=$(color $BG2)
C_BG3=$(color $BG3); C_BG4=$(color $BG4)
if [ "$STYLE" = "solid" ] && [[ "${APP_SURFACE:-}" =~ ^#[0-9a-fA-F]{6}$ ]] && [[ "${APP_SURFACE_HI:-}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    # Solid-mode apps use the exact Quickshell surface tokens, not a separately
    # darkened approximation of the palette tint.
    C_BG0="$APP_SURFACE"; C_BG1="$APP_SURFACE_HI"; C_BG2="$APP_SURFACE"
fi
C_ACC="$ACCENT"
read -r AR2 AG2 AB2 < <(mix $AR $AG $AB 255 255 255 35); C_ACC_SOFT=$(color $AR2 $AG2 $AB2)
ACC_LUMA=$(awk -v r="$AR" -v g="$AG" -v b="$AB" 'BEGIN{printf "%.4f", (0.2126*r+0.7152*g+0.0722*b)/255}')
ON_ACCENT=$(awk -v l="$ACC_LUMA" 'BEGIN{print (l>0.55 ? "#141414" : "#ffffff")}')
}

CFG="$HOME/.config"

# ---------------------------------------------------------------------------
# kitty
# ---------------------------------------------------------------------------
kitty="$CFG/kitty/theme.conf"
if [ -d "$CFG/kitty" ] && ! app_on kitty; then
    printf '# Sleek Shell theming is off for kitty (Settings > Appearance > App theming).\n# kitty uses the colours from kitty.conf.\n' > "$kitty"
elif [ -d "$CFG/kitty" ] && load_app kitty; then
    cat > "$kitty" <<EOF
# Generated by apply-theme.sh — do not edit by hand.
# Colours follow the Quickshell palette. Edit the theme in the bar instead.
background_opacity     1.0
background            $C_BG0
foreground            $TEXT
cursor                $C_ACC
cursor_text_color     $ON_ACCENT
selection_background  $C_ACC
selection_foreground  $ON_ACCENT
url_color             $C_ACC_SOFT

active_tab_foreground   $ON_ACCENT
active_tab_background   $C_ACC
inactive_tab_foreground $MUTED
inactive_tab_background $C_BG2
tab_bar_background      none
window_border_width    ${BORDER_WIDTH}pt
active_border_color     $BORDER_COLOR
inactive_border_color   $MUTED
bell_border_color       $BORDER_COLOR

color0  $C_BG1
color8  $MUTED
color1  #ff6b86
color9  #ff8fa3
color2  #a5f58b
color10 #c2ffb0
color3  #ffe45e
color11 #fff08a
color4  #70b8ff
color12 #9ccfff
color5  #ff70c5
color13 #ff9bd9
color6  #8be0ff
color14 #b4eeff
color7  $TEXT
color15 $TEXT
EOF
fi

# ---------------------------------------------------------------------------
# Alacritty: import a small generated color file so user preferences stay intact.
# ---------------------------------------------------------------------------
alacritty="$CFG/alacritty"
if app_on alacritty && load_app alacritty; then
    mkdir -p "$alacritty"
    cat > "$alacritty/theme.toml" <<EOF
# Generated by Sleek Shell. Edit the theme in Quickshell Settings.
[window]
opacity = 1.0

[colors.primary]
background = "$C_BG0"
foreground = "$TEXT"
bright_foreground = "$TEXT"
dim_foreground = "$MUTED"

[colors.cursor]
cursor = "$ACCENT"
text = "$ON_ACCENT"

[colors.selection]
background = "$ACCENT"
text = "$ON_ACCENT"

[colors.normal]
black = "$C_BG1"
red = "#ff6b86"
green = "#a5f58b"
yellow = "#ffe45e"
blue = "#70b8ff"
magenta = "#ff70c5"
cyan = "#8be0ff"
white = "$TEXT"

[colors.bright]
black = "$MUTED"
red = "#ff718b"
green = "#77e9a8"
yellow = "#ffe05b"
blue = "#78aaff"
magenta = "#ff8bdb"
cyan = "#61d9e8"
white = "$TEXT"
EOF
    config="$alacritty/alacritty.toml"
    if [ ! -f "$config" ]; then
        printf '[general]\nimport = ["~/.config/alacritty/theme.toml"]\n' > "$config"
    elif ! grep -Fq 'theme.toml' "$config"; then
        python3 - "$config" <<'PY'
import os, re, sys
path = sys.argv[1]
lines = open(path).read().splitlines()
general = next((i for i, line in enumerate(lines) if line.strip().lower() == '[general]'), -1)
if general >= 0:
    lines.insert(general + 1, 'import = ["~/.config/alacritty/theme.toml"]')
else:
    lines = ['[general]', 'import = ["~/.config/alacritty/theme.toml"]', ''] + lines
tmp = path + '.tmp'
with open(tmp, 'w') as f: f.write('\n'.join(lines) + '\n')
os.replace(tmp, path)
PY
    fi
fi

# ---------------------------------------------------------------------------
# rofi
# ---------------------------------------------------------------------------
rofi="$CFG/rofi/themes/rice.rasi"
if [ -f "$rofi" ] && app_on rofi && load_app rofi; then
    # Upgrade legacy hardcoded window, inputbar and element properties to use RASI theme variables
    python3 - "$rofi" <<'PY'
import os, re, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        s = f.read()

    def repl_window(m):
        w = m.group(0)
        if "border:" in w and "@window-border" not in w:
            w = re.sub(r'border:\s*[^;]+;', 'border: @window-border;', w)
        elif "@window-border" not in w:
            w = re.sub(r'(background-color:\s*[^;]+;)', r'\1\n    border: @window-border;', w)
        if "border-color:" in w and "@window-border-color" not in w:
            w = re.sub(r'border-color:\s*[^;]+;', 'border-color: @window-border-color;', w)
        elif "@window-border-color" not in w:
            w = re.sub(r'(border:\s*@window-border;)', r'\1\n    border-color: @window-border-color;', w)
        if "border-radius:" in w and "@window-radius" not in w:
            w = re.sub(r'border-radius:\s*[^;]+;', 'border-radius: @window-radius;', w)
        return w

    s = re.sub(r'(?s)window\s*\{.*?\}', repl_window, s, count=1)

    def repl_inputbar(m):
        b = m.group(0)
        if "border-radius:" in b and "@surface-radius" not in b:
            b = re.sub(r'border-radius:\s*[^;]+;', 'border-radius: @surface-radius;', b)
        return b
    s = re.sub(r'(?s)inputbar\s*\{.*?\}', repl_inputbar, s, count=1)

    def repl_element(m):
        e = m.group(0)
        if "border-radius:" in e and "@item-radius" not in e:
            e = re.sub(r'border-radius:\s*[^;]+;', 'border-radius: @item-radius;', e)
        return e
    s = re.sub(r'(?s)(?<!\.)element\s*\{.*?\}', repl_element, s, count=1)

    tmp = path + ".sleek-upgrade.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(s)
    os.replace(tmp, path)
except Exception:
    pass
PY

    # Solid launcher surfaces are fully opaque; Glass keeps a translucent background.
    if [ "${STYLE:-glass}" = "solid" ]; then
        ra="ff"
    else
        ra=$(awk -v g="$GLASS" 'BEGIN{ a=g+0; if(a>1)a=1; if(a<0)a=0; printf "%02x", a*255 }')
    fi
    bg_alpha="${C_BG0}${ra}"
    surface_alpha="$ra"
    line_color="${C_BG4}66"
    [ "$SHELL_BORDERS" = "true" ] || line_color="#00000000"
    tmp="$(mktemp)"
    awk -v mark="__THEME_BLOCK__" '
        /\/\* __THEME_BLOCK__/ { inblk=1 }
        inblk==1 { if ($0 ~ /\/\* __THEME_END__ \*\//) { inblk=0 }; next }
        { buf[++n]=$0 }
        END { while (n > 0 && buf[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print buf[i] }
    ' "$rofi" > "$tmp"
    # strip any old generated vars if the block markers were missing
    grep -vE '^\s*\*(bg|accent|fg|muted|dim):' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
    {
        cat "$tmp"
        cat <<EOF

/* __THEME_BLOCK__ (generated by apply-theme.sh) */
* {
    bg:        $bg_alpha;
    surface:   ${C_BG2}${surface_alpha};
    surface-hi:${C_BG1}${surface_alpha};
    line:      $line_color;
    accent:    $ACCENT;
    fg:        $TEXT;
    muted:     $MUTED;
    dim:       $DIM;
    onaccent:  $ON_ACCENT;
    window-border: ${BORDER_WIDTH}px;
    window-border-color: $BORDER_COLOR;
    window-radius: ${WINDOW_RADIUS}px;
    surface-radius: ${SURFACE_RADIUS}px;
    item-radius: ${ITEM_RADIUS}px;
    cyan:      $ACCENT;
    purple:    $ACCENT;
    pink:      $ACCENT;
    font:      "${FONT_FAMILY:-Inter} 12";
}
/* __THEME_END__ */
EOF
    } > "$rofi.generated" && mv "$rofi.generated" "$rofi"
    rm -f "$tmp"
fi

# The config also imports control-center.rasi; keep its legacy rules tied to the
# same generated palette, otherwise that later import masks the live rice theme.
ccrofi="$CFG/rofi/themes/control-center.rasi"
if [ -f "$ccrofi" ] && app_on rofi && load_app rofi; then
python3 - "$ccrofi" "$C_BG1" "$C_BG2" "$TEXT" "$ACCENT" "$C_ACC_SOFT" "$FONT_FAMILY" "$ON_ACCENT" "$ra" "$surface_alpha" "$BORDER_WIDTH" "$BORDER_COLOR" "$WINDOW_RADIUS" "$SURFACE_RADIUS" "$ITEM_RADIUS" <<'PY'
import os, re, sys
path, bg, surface, fg, accent, muted, font, on_accent, bg_alpha, surface_alpha, border_width, border_color, window_radius, surface_radius, item_radius = sys.argv[1:]
s = open(path).read()
s = re.sub(r'/\* __SLEEK_THEME__.*?__SLEEK_THEME_END__ \*/\n?', '', s, flags=re.S)
s = s.replace('@onAccent', '@onaccent')
tokens = f'''/* __SLEEK_THEME__ (generated by apply-theme.sh) */
* {{ bg: {bg}{bg_alpha}; surface: {surface}{surface_alpha}; foreground: {fg}; accent: {accent}; selected: {accent}; onaccent: {on_accent}; muted: {muted}; font: "{font or 'Inter'} 12"; window-border: {border_width}px; window-border-color: {border_color}; window-radius: {window_radius}px; surface-radius: {surface_radius}px; item-radius: {item_radius}px; }}
/* __SLEEK_THEME_END__ */'''
for old, new in {
    '#17191ef5': '@bg', '#17191e': '@onaccent', '#252932e8': '@surface',
    '#f0f2f5': '@foreground', '#aab4c4': '@accent'
}.items():
    s = s.replace(old, new)
s = re.sub(r'(\bbackground:\s*)@onaccent', r'\1@bg', s, count=1)
s = re.sub(r'(\*\s*\{[^}]*?\bfont:\s*)"[^"]+"', lambda m: m.group(1) + '"' + (font or 'Inter') + ' 12"', s, count=1, flags=re.S)
open(path + '.tmp', 'w').write(tokens + '\n' + s.lstrip())
os.replace(path + '.tmp', path)
PY
fi

# ---------------------------------------------------------------------------
# GTK 3 + 4 (palette surfaces, text, accent and selection colors)
# ---------------------------------------------------------------------------
app_on gtk && load_app gtk && for v in 3.0 4.0; do
    css="$CFG/gtk-$v/gtk.css"
    mkdir -p "$(dirname "$css")" 2>/dev/null
    [ -f "$css" ] || : > "$css"
    python3 - "$css" "$C_ACC" "$TEXT" "$C_BG0" "$C_BG1" "$C_BG2" "$BORDER_COLOR" "$BORDER_WIDTH" <<'PY'
import re, sys
path, accent, text, bg0, bg1, bg2, border, border_width = sys.argv[1:9]
s = open(path).read()
lines = {
    "accent_bg_color": accent,
    "accent_fg_color": "#141414" if (0.2126*int(accent[1:3],16)+0.7152*int(accent[3:5],16)+0.0722*int(accent[5:7],16))/255 > 0.55 else "#ffffff",
    "accent_color": accent,
    "theme_selected_bg_color": accent,
    "theme_selected_fg_color": "#141414" if (0.2126*int(accent[1:3],16)+0.7152*int(accent[3:5],16)+0.0722*int(accent[5:7],16))/255 > 0.55 else "#ffffff",
    "cc_bg": bg0,
    "cc_surface": bg2,
    "cc_fg": text,
    "cc_accent": accent,
    "cc_border": border,
    "cc_hover": f"alpha({accent}, 0.18)",
}
s = re.sub(r"@define-color\s+(" + "|".join(lines) + r")\s+[^;]+;",
           lambda m: f"@define-color {m.group(1)} {lines[m.group(1)]};", s)
s = re.sub(r"/\* __SLEEK_ACCENT__.*?__SLEEK_ACCENT_END__ \*/\n?", "", s, flags=re.S).rstrip()
missing = [k for k in lines if not re.search(r"@define-color\s+" + k + r"\s", s)]
block = "/* __SLEEK_ACCENT__ (generated by apply-theme.sh) */\n" + "".join(f"@define-color {k} {lines[k]};\n" for k in missing)
block += "window, .background { background-color: @cc_bg; color: @cc_fg; }\n"
block += "* { color: @cc_fg; }\n"
block += "window, .background, view, textview, treeview, list, grid, .view, .sidebar, placessidebar { background-image: none; background-color: @cc_bg; color: @cc_fg; }\n"
block += f"headerbar, .titlebar {{ background-image: none; background-color: @cc_surface; color: @cc_fg; border-bottom: {border_width}px solid @cc_border; box-shadow: none; }}\n"
block += f"button, entry, searchentry, spinbutton, dropdown, combobox {{ background-image: none; background-color: @cc_surface; color: @cc_fg; border-color: @cc_border; }}\n"
block += "button:hover { background-color: @cc_hover; }\n"
block += "button:checked, row:selected, treeview:selected { background-color: @cc_accent; color: @cc_bg; }\n"
block += "entry, searchentry { background-color: @cc_surface; color: @cc_fg; }\n/* __SLEEK_ACCENT_END__ */\n"
s = (s + "\n\n" if s else "") + block
tmp = path + ".tmp"
open(tmp, "w").write(s)
import os; os.replace(tmp, path)
PY
done

if app_on gtk && [ -n "$FONT_FAMILY" ]; then
    for v in 3.0 4.0; do
        ini="$CFG/gtk-$v/settings.ini"
        mkdir -p "$(dirname "$ini")" 2>/dev/null
        python3 - "$ini" gtk-font-name "$FONT_FAMILY 10" <<'PY'
import os, re, sys
path, key, value = sys.argv[1:]
try: lines = open(path).read().splitlines()
except FileNotFoundError: lines = []
out, in_settings, found, section_seen = [], False, False, False
for line in lines:
    if re.match(r'^\s*\[.*\]\s*$', line):
        if in_settings and not found:
            out.append(f'{key}={value}'); found = True
        in_settings = line.strip().lower() == '[settings]'
        section_seen |= in_settings
        out.append(line)
    elif in_settings and re.match(r'^\s*' + re.escape(key) + r'\s*=', line):
        if not found: out.append(f'{key}={value}'); found = True
    else: out.append(line)
if in_settings and not found: out.append(f'{key}={value}'); found = True
if not section_seen: out.extend(([''] if out and out[-1] else []) + ['[Settings]', f'{key}={value}'])
tmp = path + '.tmp'
with open(tmp, 'w') as f: f.write('\n'.join(out) + '\n')
os.replace(tmp, path)
PY
    done
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface font-name "$FONT_FAMILY 10" 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------------------------
# micro
# ---------------------------------------------------------------------------
micro="$CFG/micro/colorschemes/rice.micro"
if app_on micro && load_app micro; then
mkdir -p "$CFG/micro/colorschemes" 2>/dev/null
cat > "$micro" <<EOF
# Generated by apply-theme.sh — follows the Quickshell palette.
color-link default "$TEXT,$C_BG0"
color-link comment "$MUTED"
color-link identifier "$C_ACC_SOFT"
color-link constant "$C_ACC"
color-link statement "$C_ACC"
color-link symbol "$C_ACC_SOFT"
color-link preproc "$C_ACC_SOFT"
color-link type "$C_ACC"
color-link special "$C_ACC"
color-link underlined "$C_ACC"
color-link error "bold #ff6b86"
color-link todo "bold #ffe45e"
color-link number "$C_ACC_SOFT"
color-link string "#a5f58b"
color-link character "#a5f58b"
color-link statusline "$TEXT,$C_BG2"
color-link tabbar "$MUTED,$C_BG1"
color-link indent-char "$C_BG3"
color-link line-number "$MUTED"
color-link current-line-number "$C_ACC"
color-link cursor-line "$C_BG2"
color-link color-column "$C_BG2"
color-link selection "$C_BG0,$C_ACC"
color-link match-braces "$C_ACC"
EOF
fi

# ---------------------------------------------------------------------------
# KDE / Qt (kdeglobals) — used by Dolphin and other Qt apps
#
# KDE/Qt receives the same mode-aware palette as GTK, Rofi and terminals.
# ---------------------------------------------------------------------------
if app_on qt && load_app qt; then
    rgb3() { local c="$1"; local t="${c#\#}"; printf '%d,%d,%d' "0x${t:0:2}" "0x${t:2:2}" "0x${t:4:2}"; }
    set_grp() {
        if command -v kwriteconfig6 >/dev/null 2>&1; then
            kwriteconfig6 --file kdeglobals --group "$1" --key "$2" "$3"
        elif command -v kwriteconfig5 >/dev/null 2>&1; then
            kwriteconfig5 --file kdeglobals --group "$1" --key "$2" "$3"
        else
            python3 - "$CFG/kdeglobals" "$1" "$2" "$3" <<'PY'
import os, re, sys
path, group, key, value = sys.argv[1:]
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    lines = []
section = f'[{group}]'
start = next((i for i, line in enumerate(lines) if line.strip() == section), -1)
if start < 0:
    if lines and lines[-1].strip(): lines.append('')
    lines.extend([section, f'{key}={value}'])
else:
    end = next((i for i in range(start + 1, len(lines)) if re.match(r'^\s*\[.*\]\s*$', lines[i])), len(lines))
    index = next((i for i in range(start + 1, end) if re.match(r'^\s*' + re.escape(key) + r'\s*=', lines[i])), -1)
    if index >= 0: lines[index] = f'{key}={value}'
    else: lines.insert(end, f'{key}={value}')
tmp = path + '.tmp'
with open(tmp, 'w') as f: f.write('\n'.join(lines) + '\n')
os.replace(tmp, path)
PY
        fi
    }

    L_BG1="$(rgb3 "$C_BG1")"
    L_BG2="$(rgb3 "$C_BG2")"
    L_TEXT="$TEXT"
    L_MUTED="$MUTED"
    L_ACC="$ACCENT"
    L_ACC_SOFT="$C_ACC_SOFT"
    SEL_FG="$TEXT"

    ACC_RGB="$(rgb3 "$ACCENT")"
    SOFT_RGB="$(rgb3 "$C_ACC_SOFT")"
    for grp in Colors:Window Colors:View Colors:Button Colors:Selection Colors:Tooltip Colors:Header; do
        set_grp "$grp" BackgroundNormal "$L_BG1"
        set_grp "$grp" BackgroundAlternate "$L_BG2"
        set_grp "$grp" ForegroundNormal "$L_TEXT"
        set_grp "$grp" ForegroundInactive "$L_MUTED"
        set_grp "$grp" ForegroundActive "$L_ACC"
        set_grp "$grp" DecorationFocus "$L_ACC"
        set_grp "$grp" DecorationHover "$L_ACC_SOFT"
        set_grp "$grp" ForegroundNegative "#ff6b86"
        set_grp "$grp" ForegroundNeutral "#ffe45e"
        set_grp "$grp" ForegroundPositive "#a5f58b"
        set_grp "$grp" ForegroundLink "$L_ACC_SOFT"
    done
    set_grp Colors:Selection BackgroundNormal "$ACC_RGB"
    set_grp Colors:Selection BackgroundAlternate "$SOFT_RGB"
    set_grp Colors:Selection ForegroundNormal "$ON_ACCENT"
    [ -n "$FONT_FAMILY" ] && set_grp General font "$FONT_FAMILY,10,-1,5,50,0,0,0,0,0"
fi

# ---------------------------------------------------------------------------
# kitty.conf include (idempotent)
# ---------------------------------------------------------------------------
kconf="$CFG/kitty/kitty.conf"
if app_on kitty && [ -f "$kconf" ] && ! grep -q '^include theme.conf' "$kconf" 2>/dev/null; then
    printf '\n# Palette follows the Quickshell theme (regenerated at runtime).\ninclude theme.conf\n' >> "$kconf"
fi

exit 0
