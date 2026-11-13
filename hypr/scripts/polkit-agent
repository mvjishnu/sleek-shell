#!/usr/bin/env bash
# Start a polkit authentication agent (the password prompt apps use for admin actions) unless one runs.
#   polkit-agent.sh          start the first installed agent (Hyprland autostart)
#   polkit-agent.sh --find   print the agent that would be started; exit 1 if none is installed
set -u
R="${SLEEK_SYS_ROOT:-}"
AGENTS=(
    /usr/lib/hyprpolkitagent/hyprpolkitagent
    /usr/libexec/hyprpolkitagent
    "/usr/lib/*/hyprpolkitagent"
    /usr/lib/polkit-kde-authentication-agent-1
    /usr/libexec/polkit-kde-authentication-agent-1
    "/usr/lib/*/libexec/polkit-kde-authentication-agent-1"
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    /usr/libexec/polkit-gnome-authentication-agent-1
    /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
    /usr/libexec/polkit-mate-authentication-agent-1
    /usr/bin/lxqt-policykit-agent
    /usr/bin/lxpolkit
)
RUNNING='hyprpolkitagent|polkit-kde-authentication-agent|polkit-gnome-authentication-agent|polkit-mate-authentication-agent|lxqt-policykit-agent|lxpolkit'

find_agent() {
    local p f
    for p in "${AGENTS[@]}"; do
        for f in $R$p; do [ -x "$f" ] && { printf '%s\n' "$f"; return 0; }; done
    done
    return 1
}

case "${1:-}" in
    --find) find_agent; exit ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

pgrep -u "$(id -u)" -f "$RUNNING" >/dev/null 2>&1 && exit 0
if agent="$(find_agent)"; then exec "$agent"; fi
echo "polkit-agent.sh: no polkit agent installed (e.g. hyprpolkitagent); admin prompts will not appear" >&2
exit 0
