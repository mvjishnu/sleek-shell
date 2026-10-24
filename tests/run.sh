#!/usr/bin/env bash
# Run the test suites. Usage: tests/run.sh [suite...]   (default: all except live)
# Suites: static hygiene lua units distro gpu system deps calc app-themes installer greeter live
# Every suite works under /tmp and never touches your home, /etc or services; live is read-only.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
suites=("$@"); [ ${#suites[@]} -gt 0 ] || suites=(static hygiene lua units distro gpu deps calc app-themes installer greeter system)
failed=()
for s in "${suites[@]}"; do
    printf '\n### %s\n' "$s"
    case "$s" in
        calc)
            if (cd "$HERE/../calc" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q test_sleek_calc); then echo "== calc: passed"
            else failed+=(calc); fi ;;
        units)
            if (cd "$HERE" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -q -s . -p 'test_*.py'); then echo "== units: passed"
            else failed+=(units); fi ;;
        app-themes)
            if ! command -v jq >/dev/null; then echo "== app-themes: skipped (jq not installed)"
            elif bash "$HERE/app-themes.sh"; then echo "== app-themes: passed"
            else failed+=(app-themes); fi ;;
        static|hygiene|lua|distro|gpu|system|deps|installer|greeter|live)
            bash "$HERE/$s.sh" || failed+=("$s") ;;
        *) echo "unknown suite: $s" >&2; failed+=("$s") ;;
    esac
done
echo
if [ ${#failed[@]} = 0 ]; then echo "ALL SUITES PASSED (${suites[*]})"; else echo "FAILED: ${failed[*]}"; exit 1; fi
