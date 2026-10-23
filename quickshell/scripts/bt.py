#!/usr/bin/env python3
"""Bluetooth helper for the Quickshell Bluetooth dropdown.

Talks to BlueZ over the system D-Bus (org.bluez) through Gio, so it returns real
adapter/device state instead of screen-scraping bluetoothctl. Each invocation is a
short-lived process, which keeps the Quickshell side simple (one Process per
action) while still being fast (a single D-Bus round trip).

Usage:
  bt.py list                 -> JSON list of devices {mac,name,paired,connected,type,rssi}
  bt.py state                -> JSON {available,powered,discovering,alias}
  bt.py power on|off|toggle  -> turn the adapter on/off
  bt.py scan on|off          -> start/stop discovery
  bt.py connect MAC          -> connect
  bt.py disconnect MAC       -> disconnect
  bt.py pair MAC [PIN]       -> pair (PIN optional; a daemon agent handles prompts)
  bt.py remove MAC           -> unpair / remove

Pairing prompts (PIN / passkey / confirm) are handled by a small agent registered
for the lifetime of this process. If the device needs a passkey and none was
given, the agent accepts BlueZ's generated one where possible and reports back.
"""
import json
import os
import sys
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BLUEZ = "org.bluez"
OM = "org.freedesktop.DBus.ObjectManager"
PROPS = "org.freedesktop.DBus.Properties"
ADAPTER = "org.bluez.Adapter1"
DEVICE = "org.bluez.Device1"
AGENT_MGR = "org.bluez.AgentManager1"
AGENT_PATH = "/org/quickshell/btagent"
AGENT_CAP = "KeyboardDisplay"


def bus():
    return Gio.bus_get_sync(Gio.BusType.SYSTEM, None)


def call(b, service, path, iface, method, params=None, timeout=25000):
    return b.call_sync(
        service, path, iface, method,
        params if params is not None else None,
        None, Gio.DBusCallFlags.NONE, timeout, None,
    )


def managed(b):
    res = call(b, BLUEZ, "/", OM, "GetManagedObjects")
    return res.unpack()[0]


def get_adapter(b):
    objects = managed(b)
    for path, ifaces in objects.items():
        if ADAPTER in ifaces:
            return path
    return None


def norm_mac(mac):
    return "dev_" + mac.upper().replace(":", "_")


def device_path(b, mac):
    want = norm_mac(mac)
    for path in managed(b):
        if path.split("/")[-1].upper() == want.upper():
            return path
    return None


def prop(b, path, iface, name, default=None):
    try:
        res = call(b, BLUEZ, path, PROPS, "Get", GLib.Variant("(ss)", (iface, name)))
        return res.unpack()[0]
    except GLib.Error:
        return default


def device_type(klass, icon):
    if icon:
        if icon.startswith("audio"):
            return "audio"
        if icon.startswith("input"):
            return "input"
        if icon.startswith("phone"):
            return "phone"
    if klass:
        major = klass & 0x1F00
        if major == 0x0400:
            return "audio"
        if major == 0x0500:
            return "input"
        if major == 0x0200:
            return "phone"
    return "other"


def cmd_state(b):
    path = get_adapter(b)
    if not path:
        print(json.dumps({"available": False, "powered": False,
                          "discovering": False, "alias": ""}))
        return 0
    print(json.dumps({
        "available": True,
        "powered": bool(prop(b, path, ADAPTER, "Powered", False)),
        "discovering": bool(prop(b, path, ADAPTER, "Discovering", False)),
        "alias": prop(b, path, ADAPTER, "Alias", "") or "",
    }))
    return 0


def cmd_list(b):
    objects = managed(b)
    out = []
    for path, ifaces in objects.items():
        if DEVICE not in ifaces:
            continue
        d = ifaces[DEVICE]
        mac = d.get("Address", "")
        name = d.get("Alias") or d.get("Name") or mac
        out.append({
            "mac": mac,
            "name": name,
            "paired": bool(d.get("Paired", False)),
            "connected": bool(d.get("Connected", False)),
            "type": device_type(d.get("Class", 0), d.get("Icon", "")),
            "rssi": int(d.get("RSSI", 0)) if d.get("RSSI") is not None else 0,
        })
    out.sort(key=lambda x: (not x["connected"], not x["paired"], x["name"].lower()))
    print(json.dumps(out))
    return 0


# ---- pairing agent -------------------------------------------------------

# BlueZ hands pairing prompts to the most recently registered agent, so this
# script must not register one while a desktop agent (blueman) is already
# running - otherwise it would shadow the GUI prompt.
DESKTOP_AGENTS = ("blueman-applet", "blueman-manager")

# BlueZ errors we can explain in a sentence instead of leaking D-Bus jargon.
FRIENDLY = {
    "pin-required": "Device wants a PIN - pair it from the Bluetooth manager",
    "passkey-required": "Device wants a passkey - pair it from the Bluetooth manager",
    "AuthenticationRejected": "Pairing was rejected by the device",
    "AuthenticationFailed": "Pairing failed - try removing the device and pairing again",
    "AuthenticationTimeout": "Pairing timed out - is the device in pairing mode?",
    "NotReady": "Device is not ready - try again",
    "AlreadyExists": "Device is already paired",
}


def desktop_agent_present():
    """True when a GUI Bluetooth agent is running and owns the prompt slot."""
    try:
        pids = os.listdir("/proc")
    except OSError:
        return False
    for pid in pids:
        if not pid.isdigit():
            continue
        try:
            with open("/proc/%s/comm" % pid) as f:
                if f.read().strip() in DESKTOP_AGENTS:
                    return True
        except OSError:
            continue
    return False


def friendly_error(message):
    """Map a BlueZ error string onto something readable."""
    msg = message or ""
    for key, text in FRIENDLY.items():
        if key.lower() in msg.lower():
            return text
    return msg or "Bluetooth action failed"


class Agent:
    """Minimal BlueZ agent.

    It answers the two prompts that can be answered without user input
    (just-works and numeric comparison) and refuses the ones that cannot
    (PIN / passkey entry), so BlueZ reports a clean error instead of hanging
    on a made-up "0000".
    """

    def __init__(self, b, pin=None):
        self.b = b
        self.pin = pin
        self.node = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
        self.reply = None
        self.sent = False
        self.code = ""      # passkey or PIN the peer asked us to show
        self.code_kind = ""  # "pin" or "passkey"
        self.secret = False  # peer demanded a secret we do not have
        b.register_object(AGENT_PATH, self.node.interfaces[0], self._on_call, None, None)

    def _on_call(self, conn, sender, path, iface, method, params, inv):
        if method == "RequestPinCode":
            if self.pin is not None:
                inv.return_value(GLib.Variant("(s)", (str(self.pin),)))
                self.sent = True
                return None
            # We cannot know the PIN the device expects. Answer with an empty
            # one so the pairing is rejected, and remember that a secret was
            # demanded so the caller can explain what happened.
            self.secret = True
            inv.return_value(GLib.Variant("(s)", ("",)))
        elif method == "RequestPasskey":
            if self.pin is not None:
                inv.return_value(GLib.Variant("(u)", (int(self.pin),)))
                self.sent = True
                return None
            self.secret = True
            inv.return_value(GLib.Variant("(u)", (0,)))
        elif method in ("DisplayPinCode", "DisplayPasskey"):
            if len(params) > 1 and params[1]:
                self.code = str(params[1])
                self.code_kind = "pin" if method == "DisplayPinCode" else "passkey"
            inv.return_value(None)
        elif method == "RequestConfirmation":
            # Numeric comparison: accept, but show the code so it can be
            # verified against the one on the device.
            if len(params) > 1 and params[1]:
                self.code = str(params[1])
                self.code_kind = "passkey"
            inv.return_value(None)
        else:
            # RequestAuthorization, AuthorizeService, Cancel, Release
            inv.return_value(None)
        return None


AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
    <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
    <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
    <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
    <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
    <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="Cancel"/>
  </interface>
</node>
"""


def _code_info(code, kind):
    """Turn a code the peer asked us to show into a one-line instruction."""
    if not code:
        return ""
    if kind == "pin":
        return "Type PIN %s on the device" % code
    return "Confirm code %s on the device" % code


def _pair_and_connect(b, dpath, agent):
    """Pair, then try to connect. Returns (ok, error_text, code, kind)."""
    try:
        call(b, BLUEZ, dpath, DEVICE, "Pair", None, timeout=45000)
    except GLib.Error as e:
        code = agent.code if agent else ""
        kind = agent.code_kind if agent else ""
        return False, e.message or "", code, kind
    try:
        call(b, BLUEZ, dpath, DEVICE, "Connect", None, timeout=45000)
    except GLib.Error:
        pass   # paired but not connectable yet; the row shows it as disconnected
    return True, "", (agent.code if agent else ""), (agent.code_kind if agent else "")


def cmd_pair(b, mac, pin=None):
    dpath = device_path(b, mac)
    if not dpath:
        # Unknown device: search for it briefly, then try again.
        apath = get_adapter(b)
        if apath:
            try:
                call(b, BLUEZ, apath, ADAPTER, "SetDiscoveryFilter",
                     GLib.Variant("(a{sv})", ({"Transport": GLib.Variant("s", "auto")},)))
                call(b, BLUEZ, apath, ADAPTER, "StartDiscovery")
                deadline = time.time() + 12
                while time.time() < deadline:
                    if device_path(b, mac):
                        break
                    _pump(0.3)
                call(b, BLUEZ, apath, ADAPTER, "StopDiscovery")
            except GLib.Error:
                pass
        dpath = device_path(b, mac)
    if not dpath:
        print(json.dumps({"ok": False, "error": "device not found"}))
        return 1

    agent = None
    registered = False
    if not desktop_agent_present():
        # No GUI agent owns the prompt slot, so we answer it ourselves.
        try:
            agent = Agent(b, pin)
            call(b, BLUEZ, "/org/bluez", AGENT_MGR, "RegisterAgent",
                 GLib.Variant("(os)", (AGENT_PATH, AGENT_CAP)))
            registered = True
        except GLib.Error:
            agent = None

    ok, err, code, kind = False, "", "", ""
    try:
        ok, err, code, kind = _pair_and_connect(b, dpath, agent)
        if not ok and agent is None and pin is None:
            # A desktop agent is running but did not answer (not registered, or
            # it ignored the request): retry with our own agent so just-works
            # and numeric comparison still pair.
            try:
                agent = Agent(b, pin)
                call(b, BLUEZ, "/org/bluez", AGENT_MGR, "RegisterAgent",
                     GLib.Variant("(os)", (AGENT_PATH, AGENT_CAP)))
                registered = True
                ok, err, code, kind = _pair_and_connect(b, dpath, agent)
            except GLib.Error:
                pass
    finally:
        if registered:
            _unregister(b)

    if not ok:
        print(json.dumps({"ok": False, "mac": mac,
                          "error": friendly_error(err),
                          "info": _code_info(code, kind)}))
        return 1

    paired = bool(prop(b, dpath, DEVICE, "Paired", False))
    if not paired:
        print(json.dumps({"ok": False, "mac": mac, "error": "pairing failed"}))
        return 1
    print(json.dumps({"ok": True, "mac": mac, "error": "",
                      "info": _code_info(code, kind)}))
    return 0


def _unregister(b):
    try:
        call(b, BLUEZ, "/org/bluez", AGENT_MGR, "UnregisterAgent",
             GLib.Variant("(o)", (AGENT_PATH,)), timeout=5000)
    except GLib.Error:
        pass


def _pump(seconds):
    ctx = GLib.MainContext.default()
    end = time.time() + seconds
    while time.time() < end:
        while ctx.iteration(False):
            pass
        time.sleep(0.02)


def main():
    b = bus()
    if len(sys.argv) < 2:
        print("usage: bt.py {list|state|power|scan|connect|disconnect|pair|remove} [args]",
              file=sys.stderr)
        return 2
    cmd = sys.argv[1]
    try:
        if cmd == "list":
            return cmd_list(b)
        if cmd == "state":
            return cmd_state(b)
        if cmd == "power":
            apath = get_adapter(b)
            if not apath:
                print(json.dumps({"ok": False, "error": "no adapter"}))
                return 1
            arg = sys.argv[2] if len(sys.argv) > 2 else "toggle"
            cur = bool(prop(b, apath, ADAPTER, "Powered", False))
            want = (not cur) if arg == "toggle" else (arg == "on")
            call(b, BLUEZ, apath, PROPS, "Set",
                 GLib.Variant("(ssv)", (ADAPTER, "Powered", GLib.Variant("b", want))))
            print(json.dumps({"ok": True, "powered": want}))
            return 0
        if cmd == "scan":
            apath = get_adapter(b)
            if not apath:
                print(json.dumps({"ok": False, "error": "no adapter"}))
                return 1
            arg = sys.argv[2] if len(sys.argv) > 2 else "on"
            seconds = int(sys.argv[3]) if len(sys.argv) > 3 else 30
            if arg == "on":
                # BlueZ stops discovery as soon as the requesting client drops, so
                # we hold the connection open for `seconds` (default 30) while the
                # dropdown is open. Called as a background Process by Quickshell.
                try:
                    call(b, BLUEZ, apath, ADAPTER, "SetDiscoveryFilter",
                         GLib.Variant("(a{sv})", ({"Transport": GLib.Variant("s", "auto")},)))
                except GLib.Error:
                    pass
                call(b, BLUEZ, apath, ADAPTER, "StartDiscovery")
                _pump(seconds)
                try:
                    call(b, BLUEZ, apath, ADAPTER, "StopDiscovery")
                except GLib.Error:
                    pass
            else:
                try:
                    call(b, BLUEZ, apath, ADAPTER, "StopDiscovery")
                except GLib.Error:
                    pass
            print(json.dumps({"ok": True}))
            return 0
        if cmd in ("connect", "disconnect", "remove"):
            dpath = device_path(b, sys.argv[2])
            if not dpath:
                print(json.dumps({"ok": False, "error": "device not found"}))
                return 1
            if cmd == "connect":
                call(b, BLUEZ, dpath, DEVICE, "Connect", None, timeout=30000)
            elif cmd == "disconnect":
                call(b, BLUEZ, dpath, DEVICE, "Disconnect", None, timeout=15000)
            else:
                apath = get_adapter(b)
                call(b, BLUEZ, apath, ADAPTER, "RemoveDevice",
                     GLib.Variant("(o)", (dpath,)))
            print(json.dumps({"ok": True}))
            return 0
        if cmd == "pair":
            return cmd_pair(b, sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    except GLib.Error as e:
        print(json.dumps({"ok": False, "error": e.message}))
        return 1
    print("unknown command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
