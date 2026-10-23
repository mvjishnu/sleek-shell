#!/usr/bin/env python3
"""Exit 1 if the running Sleek Shell logged QML errors/warnings in its current generation
(from 3 s before the last 'Configuration Loaded' until now). Known-harmless Qt noise (text-input, portal re-registration) is ignored."""
import datetime, glob, os, sys
HARMLESS = ("textinput", "Connection already associated with an application ID")
logs = sorted(glob.glob(f"/run/user/{os.getuid()}/quickshell/by-id/*/log.log"), key=os.path.getmtime, reverse=True)
log = next((l for l in logs if os.path.expanduser("~/.config/quickshell/shell.qml") in open(l, errors="replace").read(4000)), None)
if not log: print("no shell log"); sys.exit(1)
lines = open(log, errors="replace").read().splitlines()
ts = lambda l: datetime.datetime.strptime(l[:23], "%Y-%m-%d %H:%M:%S.%f")
loads = [ts(l) for l in lines if "Configuration Loaded" in l]
if not loads: print("never loaded"); sys.exit(1)
since = loads[-1] - datetime.timedelta(seconds=3)
bad = [l for l in lines if (" WARN " in l or " ERROR " in l) and not any(h in l for h in HARMLESS) and l[:4].isdigit() and ts(l) >= since]
print("\n".join(bad) if bad else "clean since " + str(loads[-1]))
sys.exit(1 if bad else 0)
