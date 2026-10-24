#!/usr/bin/env bash
# Sleek Shell uninstaller (per-user; never uses sudo, never removes packages).
#
#   ~/.local/share/sleek-shell/uninstall.sh            remove what install.sh installed, restore backups
#   ~/.local/share/sleek-shell/uninstall.sh --dry-run  show what would happen
#   ... --purge          also remove your Sleek Shell settings (~/.config/sleek-shell) and downloaded fonts
#   ... --keep-greeter   uninstall even though the login greeter is still installed
#   ... --yes            do not ask
#
# Only files listed in the install manifest are removed, and only when they are unchanged: files you
# edited are kept and listed. Everything install.sh moved away is put back.
set -euo pipefail

main() {
    local DRY=0 PURGE=0 YES=0 KEEP_GREETER=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run|-n) DRY=1 ;;
            --purge) PURGE=1 ;;
            --yes|-y) YES=1 ;;
            --keep-greeter) KEEP_GREETER=1 ;;
            -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
            *) echo "error: unknown option $1 (see --help)" >&2; return 1 ;;
        esac
        shift
    done
    [ "$(id -u)" != 0 ] || { echo "error: run as your own user, not root" >&2; return 1; }

    local CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
    local DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    local DATA="$DATA_HOME/sleek-shell"
    local MANIFEST="$DATA/manifest.tsv"
    local SYS_ROOT="${SLEEK_SYS_ROOT:-}"
    local SYSLOG="$DATA/system-changes.log" syschanges=""

    say() { printf '%s\n' "$*"; }
    do_() {   # do_ DESCRIPTION CMD...
        local d="$1"; shift
        if [ "$DRY" = 1 ]; then say "  would $d"; else "$@" && say "  $d" || { say "  FAILED: $d"; FAILED=$((FAILED + 1)); }; fi
    }
    local FAILED=0

    [ -f "$MANIFEST" ] || { echo "error: no install manifest at $MANIFEST: nothing to uninstall" >&2; return 1; }
    head -n1 "$MANIFEST" | grep -q '^# Sleek Shell install manifest' || { echo "error: $MANIFEST is not a Sleek Shell manifest" >&2; return 1; }

    if [ -d "$SYS_ROOT/etc/greetd/sleek-shell" ] && [ "$KEEP_GREETER" = 0 ]; then
        cat >&2 <<EOF
The Sleek Shell login greeter is installed (/etc/greetd/sleek-shell). Remove it first, while its
scripts are still here:
    sudo $DATA/greeter/uninstall.sh --purge
or keep it (it runs from its own copy in /etc and keeps working) with: $0 --keep-greeter
Nothing changed.
EOF
        return 1
    fi

    local kind a b
    local -a files=() dirs=() backups=()
    while IFS=$'\t' read -r kind a b; do
        case "$kind" in
            file) files+=("$a"$'\t'"$b") ;;
            gen) files+=("*"$'\t'"$b") ;;
            dir) dirs+=("$a") ;;
            backup) backups+=("$a"$'\t'"$b") ;;
        esac
    done < "$MANIFEST"
    [ -f "$SYSLOG" ] && syschanges="$(cat "$SYSLOG")"

    say "Sleek Shell $(awk -F'\t' '$1=="version"{print $2}' "$MANIFEST"): ${#files[@]} files, ${#backups[@]} backups to restore$( [ "$PURGE" = 1 ] && echo ', purge settings')$( [ "$DRY" = 1 ] && echo ' (dry run)')"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && grep -q -F "$(printf '\t%s/hyprland.lua' "$CFG/hypr")" "$MANIFEST"; then
        say "  note: Hyprland is running and reloads ~/.config/hypr when it changes; expect a config error"
        say "        banner until your previous config is restored below or you log out."
    fi
    if [ "$DRY" = 0 ] && [ "$YES" = 0 ]; then
        if [ -t 0 ]; then
            printf 'Continue? [y/N] '; local r; read -r r
            case "$r" in y|Y|yes|YES) ;; *) say "Nothing changed."; return 0 ;; esac
        else
            echo "error: not a terminal: re-run with --yes" >&2; return 1
        fi
    fi

    local e sha p removed=0 kept=()
    for e in "${files[@]}"; do
        sha="${e%%$'\t'*}"; p="${e#*$'\t'}"
        case "$p" in "$HOME"/*) ;; *) say "  skip $p (outside your home)"; continue ;; esac
        [ -e "$p" ] || [ -L "$p" ] || continue
        if [ -f "$p" ] && [ ! -L "$p" ] && { [ "$sha" = "*" ] || [ "$(sha256sum -- "$p" | cut -d' ' -f1)" = "$sha" ]; }; then
            if [ "$DRY" = 1 ]; then removed=$((removed + 1)); else rm -f -- "$p" && removed=$((removed + 1)); fi
        else
            kept+=("$p")
        fi
    done
    say "  $( [ "$DRY" = 1 ] && echo 'would remove' || echo removed) $removed files"

    if [ "$PURGE" = 1 ]; then
        local x
        for x in "$CFG/sleek-shell" "$DATA_HOME/fonts/sleek-shell" "$DATA/assets.json" \
                 "${XDG_STATE_HOME:-$HOME/.local/state}/hyprland/workspaces.txt" \
                 "${XDG_STATE_HOME:-$HOME/.local/state}/awww-rice"; do
            [ -e "$x" ] && do_ "remove $x" rm -rf -- "$x"
        done
    fi

    if [ "$DRY" = 0 ]; then
        printf '%s\n' "${dirs[@]}" | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2- | while IFS= read -r p; do
            case "$p" in "$HOME"/?*) [ -d "$p" ] && rmdir -- "$p" 2>/dev/null || true ;; esac
        done
    fi

    for e in "${backups[@]}"; do
        a="${e%%$'\t'*}"; b="${e#*$'\t'}"
        if [ ! -e "$b" ] && [ ! -L "$b" ]; then say "  backup missing: $b (was $a)"; continue; fi
        if [ -e "$a" ] || [ -L "$a" ]; then
            if [ "$DRY" = 1 ] && is_ours "$a"; then say "  would restore $a <- $b"; continue; fi
            say "  NOT restored: $a exists (your backup stays at $b)"; FAILED=$((FAILED + 1)); continue
        fi
        do_ "restore $a <- $b" mv -- "$b" "$a"
    done

    if [ "$DRY" = 0 ]; then
        rm -f -- "$MANIFEST" "$SYSLOG" "$DATA/install-report.txt"
        find "$DATA_HOME/sleek-shell-backups" -depth -type d -empty -delete 2>/dev/null || true
        rmdir -- "$DATA" 2>/dev/null || true
    fi

    if [ "${#kept[@]}" -gt 0 ]; then
        say "  kept ${#kept[@]} file(s) you changed after installing:"
        printf '    %s\n' "${kept[@]}"
    fi
    [ -d "$DATA_HOME/sleek-shell-backups" ] && say "  leftover backups: $DATA_HOME/sleek-shell-backups"
    [ "$PURGE" = 1 ] || [ ! -d "$CFG/sleek-shell" ] || say "  your settings are kept in $CFG/sleek-shell (--purge removes them)"
    if [ -n "$syschanges" ]; then
        say "  install.sh also changed the system. This script does not undo that (it never uses sudo):"
        printf '%s\n' "$syschanges" | sed 's/^/    /'
    fi
    say "Packages were not removed. Log out, or restart Hyprland, to finish."
    [ "$FAILED" = 0 ]
}

# A path counts as Sleek Shell's (in a dry run) when the manifest lists files under it.
is_ours() { grep -q -F -- "$(printf '\t%s/' "$1")" "${XDG_DATA_HOME:-$HOME/.local/share}/sleek-shell/manifest.tsv" 2>/dev/null; }

main "$@"
exit $?
