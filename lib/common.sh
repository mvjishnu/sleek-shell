# shellcheck shell=bash
# Shared helpers for install.sh: output, dry-run, manifest, backups.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_B=$'\e[1m' C_G=$'\e[32m' C_Y=$'\e[33m' C_R=$'\e[31m' C_0=$'\e[0m'
else
    C_B="" C_G="" C_Y="" C_R="" C_0=""
fi
say()  { printf '%s\n' "$*"; }
head1() { printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_0"; }
ok()   { printf '  %sok%s    %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '  %swarn%s  %s\n' "$C_Y" "$C_0" "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
die()  { printf '%serror:%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }
WARNINGS=0

DRY=0
# act DESCRIPTION CMD...: run CMD, or only describe it in dry-run mode
act() {
    local d="$1"; shift
    if [ "$DRY" = 1 ]; then printf '  %swould%s %s\n' "$C_Y" "$C_0" "$d"; return 0; fi
    "$@" || die "failed: $d"
    printf '  %sdone%s  %s\n' "$C_G" "$C_0" "$d"
}

# Answers come from the terminal, or from $SLEEK_PROMPT_IN (tests: a file with one answer per line).
# The source is opened once so that consecutive questions read consecutive lines.
PROMPT_FD=""
NONINTERACTIVE=0   # install.sh sets it for --yes and --dry-run: every question takes its default
prompt_open() {
    [ -n "$PROMPT_FD" ] && return 0
    local in="${SLEEK_PROMPT_IN:-}"
    if [ -z "$in" ]; then [ -t 0 ] || return 1; in=/dev/tty; fi
    { true <"$in"; } 2>/dev/null || return 1
    exec {PROMPT_FD}<"$in"
}
# prompt_read VAR: one line into VAR; fails when there is nothing to read from
prompt_read() {
    prompt_open || return 1
    IFS= read -r "$1" <&"$PROMPT_FD" || { printf -v "$1" '%s' ""; return 1; }
}

# ask QUESTION: yes/no on the terminal. No terminal means no.
ask() {
    local reply=""
    if ! prompt_open; then warn "no terminal to confirm on: answered no"; return 1; fi
    printf '%s [y/N] ' "$1" >&2
    prompt_read reply || true
    case "$reply" in y|Y|yes|Yes|YES) return 0 ;; esac
    return 1
}

# choose_yesno QUESTION DEFAULT(yes|no): the default without a terminal or with --yes / --dry-run
choose_yesno() {
    local reply="" d="$2"
    if [ "$NONINTERACTIVE" = 1 ] || ! prompt_open; then [ "$d" = yes ]; return; fi
    printf '\n%s [%s] ' "$1" "$( [ "$d" = yes ] && echo Y/n || echo y/N)" >&2
    prompt_read reply || true
    case "$reply" in y|Y|yes|Yes|YES) return 0 ;; n|N|no|No|NO) return 1 ;; esac
    [ "$d" = yes ]
}

# choose VAR QUESTION DEFAULT "id|label"...: numbered menu; the answer is a number or an id. An empty
# answer, no terminal, --yes or --dry-run take DEFAULT.
choose() {
    local __v="$1" q="$2" def="$3" o i reply="" defn=1
    shift 3
    printf -v "$__v" '%s' "$def"
    [ "$NONINTERACTIVE" = 1 ] && return 0
    prompt_open || return 0
    printf '\n%s%s%s\n' "$C_B" "$q" "$C_0" >&2
    i=1
    for o in "$@"; do
        if [ "${o%%|*}" = "$def" ]; then defn=$i; printf '  %d) %s (default)\n' "$i" "${o#*|}" >&2
        else printf '  %d) %s\n' "$i" "${o#*|}" >&2; fi
        i=$((i + 1))
    done
    while :; do
        printf 'Choice [%d]: ' "$defn" >&2
        prompt_read reply || return 0
        [ -n "$reply" ] || return 0
        if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le $# ]; then
            o="${!reply}"; printf -v "$__v" '%s' "${o%%|*}"; return 0
        fi
        for o in "$@"; do [ "${o%%|*}" = "$reply" ] && { printf -v "$__v" '%s' "$reply"; return 0; }; done
        printf '  enter a number from 1 to %d\n' "$#" >&2
    done
}

sha_of() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

# ---- manifest (tab separated; read by uninstall.sh) ------------------------------------------
#   file <sha256> <path>     installed file (removed on uninstall when unmodified)
#   gen <sha256> <path>      installed file that Sleek Shell rewrites at runtime (always removed)
#   dir <path>               directory created by the installer (removed when empty)
#   backup <path> <copy>     a pre-existing file/dir that was moved away (restored on uninstall)
declare -A OLD_SHA=()
OLD_BACKUPS=()
NEW_LINES=()
declare -A NEW_FILES=()
declare -A NEW_DIRS=()
declare -A GEN=()

load_old_manifest() {
    local m="$1" kind a b
    [ -f "$m" ] || return 0
    while IFS=$'\t' read -r kind a b; do
        case "$kind" in
            file) OLD_SHA["$b"]="$a" ;;
            gen) OLD_SHA["$b"]="$a"; GEN["$b"]=1 ;;
            dir) NEW_DIRS["$a"]=1 ;;
            backup) OLD_BACKUPS+=("$a"$'\t'"$b") ;;
        esac
    done < "$m"
}

owned() { [ -n "${OLD_SHA[$1]+x}" ]; }
owned_under() {
    local p
    for p in "${!OLD_SHA[@]}"; do case "$p" in "$1"/*) return 0 ;; esac; done
    return 1
}
record_file() { NEW_FILES["$2"]="$1"; }
record_backup() { OLD_BACKUPS+=("$1"$'\t'"$2"); }

# mkdirs DIR: create DIR and record every directory level that did not exist yet
mkdirs() {
    local d="$1" missing=()
    while [ ! -d "$d" ] && [ "$d" != "/" ] && [ "$d" != "$HOME" ]; do missing=("$d" "${missing[@]}"); d="$(dirname "$d")"; done
    local m
    for m in "${missing[@]}"; do
        NEW_DIRS["$m"]=1
        [ "$DRY" = 1 ] || mkdir -p -- "$m" || die "cannot create $m"
    done
}

write_manifest() {
    local m="$1" tmp p k
    [ "$DRY" = 1 ] && return 0
    tmp="$(mktemp "${m}.XXXXXX")" || die "cannot write manifest"
    {
        printf '# Sleek Shell install manifest (read by uninstall.sh). Do not edit.\n'
        printf 'version\t%s\n' "$VERSION"
        printf 'profile\t%s\n' "$PROFILE"
        printf 'date\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        for p in "${!NEW_DIRS[@]}"; do printf 'dir\t%s\n' "$p"; done | sort
        for p in "${!NEW_FILES[@]}"; do
            if [ -n "${GEN[$p]+x}" ]; then k=gen; else k=file; fi
            printf '%s\t%s\t%s\n' "$k" "${NEW_FILES[$p]}" "$p"
        done | sort -k3
        for k in "${OLD_BACKUPS[@]}"; do printf 'backup\t%s\n' "$k"; done
    } > "$tmp"
    mv -f -- "$tmp" "$m"
}

# backup_away PATH: move an existing file/dir that the installer does not own into BACKUP_DIR
backup_away() {
    local p="$1" rel dest
    rel="${p#"$HOME"/}"
    dest="$BACKUP_DIR/$rel"
    if [ "$DRY" = 1 ]; then printf '  %swould%s back up %s -> %s\n' "$C_Y" "$C_0" "$p" "$dest"; return 0; fi
    mkdir -p -- "$(dirname "$dest")" || die "cannot create $(dirname "$dest")"
    mv -- "$p" "$dest" || die "cannot back up $p"
    record_backup "$p" "$dest"
    printf '  %sbackup%s %s -> %s\n' "$C_Y" "$C_0" "$p" "$dest"
}

# place SRC DEST MODE POLICY
#   managed : always ours. Not-owned existing file -> backed up (unless identical). Owned but edited
#             by the user -> the edited copy is saved next to the backups first.
#   ifabsent: a default. Installed only when DEST does not exist (or is ours and unmodified).
place() {
    local src="$1" dest="$2" mode="$3" policy="$4" new cur
    new="$(sha_of "$src")"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        cur="$(sha_of "$dest")"
        if owned "$dest"; then
            if [ "$cur" != "${OLD_SHA[$dest]}" ]; then
                if [ "$policy" = ifabsent ]; then
                    record_file "${OLD_SHA[$dest]}" "$dest"
                    say "  keep  $dest (changed since install)"; return 0
                fi
                local keep="$BACKUP_DIR/edited/${dest#"$HOME"/}"
                if [ "$DRY" = 1 ]; then say "  would save your edited $dest -> $keep"
                else mkdir -p -- "$(dirname "$keep")" && cp -p -- "$dest" "$keep"; warn "you had edited $dest; your copy is saved as $keep"; fi
            fi
        elif [ "$policy" = ifabsent ]; then
            # adopt a file that is ours but missing from the manifest (an earlier run stopped before writing
            # it): identical to the default, or a generated file that carries the Sleek Shell header
            if [ "$cur" = "$new" ]; then
                record_file "$new" "$dest"; COUNT_FILES=$((COUNT_FILES + 1))
                say "  adopt $dest (identical to the Sleek Shell default)"; return 0
            fi
            if [ -n "${GEN[$dest]+x}" ] && [ -f "$dest" ] && head -n1 -- "$dest" | grep -q 'Sleek Shell'; then
                record_file "$cur" "$dest"
                say "  adopt $dest (written by Sleek Shell)"; return 0
            fi
            say "  keep  $dest (already exists)"; return 0
        else
            backup_away "$dest"
        fi
    fi
    mkdirs "$(dirname "$dest")"
    if [ "$DRY" = 0 ]; then
        if [ "$(sha_of "$dest")" != "$new" ] || [ -L "$dest" ]; then
            rm -f -- "$dest"
            install -m "$mode" -- "$src" "$dest" || die "cannot install $dest"
        else
            chmod "$mode" -- "$dest"
        fi
    fi
    record_file "$new" "$dest"
    COUNT_FILES=$((COUNT_FILES + 1))
}
COUNT_FILES=0

# place_tree SRCDIR DESTDIR: every file, mode kept (executables stay executable)
place_tree() {
    local src="$1" dest="$2" f rel mode
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        if [ -x "$f" ]; then mode=755; else mode=644; fi
        place "$f" "$dest/$rel" "$mode" managed
    done < <(find "$src" -type f ! -name '*.pyc' ! -path '*/__pycache__/*' -print0 | sort -z)
}

# remove_stale ROOT: files under ROOT from the previous install that this release no longer ships
remove_stale() {
    local root="$1" p
    for p in "${!OLD_SHA[@]}"; do
        case "$p" in "$root"/*) ;; *) continue ;; esac
        [ -n "${NEW_FILES[$p]+x}" ] && continue
        [ -e "$p" ] || continue
        if [ "$(sha_of "$p")" = "${OLD_SHA[$p]}" ]; then
            act "remove $p (no longer shipped)" rm -f -- "$p"
        else
            warn "$p is no longer shipped but you edited it; left in place"
        fi
    done
}
