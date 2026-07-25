#!/usr/bin/env python3
"""Drive Plane Mobile on a connected Android device over adb.

Flutter renders to a single surface, so `uiautomator` sees nothing useful unless
the widget tree is exposed through accessibility. It is: Flutter turns semantics
on as soon as an accessibility client attaches, and `uiautomator dump` is such a
client. Every labelled widget then appears as a node with `content-desc`.

That means the whole app is driveable from the outside with no instrumentation
build, no integration_test harness and no Dart-side hooks — provided every
interactive control carries a label. `check` below is what enforces that: it
reports controls that are tappable but anonymous, which are exactly the ones
automation cannot reach.

    tool/adb_drive.py tree               # every labelled node with tap coords
    tool/adb_drive.py check              # unlabelled tappable nodes (the gaps)
    tool/adb_drive.py tap "New issue"    # tap by label, substring match
    tool/adb_drive.py shot inbox         # screenshot to /tmp
    tool/adb_drive.py flow smoke         # scripted walk through the main screens

Requires: adb on PATH or at the standard SDK location, device unlocked.
"""
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PKG = "com.slimshaggy.plane_mobile"
SHOTS = os.environ.get("PLANE_SHOTS", "/tmp/plane-shots")


def _adb_path():
    found = shutil.which("adb")
    if found:
        return found
    fallback = os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")
    if os.path.exists(fallback):
        return fallback
    sys.exit("adb not found on PATH or at ~/Library/Android/sdk/platform-tools")


ADB = _adb_path()


def sh(*args, binary=False):
    r = subprocess.run([ADB] + list(args), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def awake():
    """Wake and keep the screen on; a dark screen screenshots as solid black."""
    if "mScreenState=ON" not in sh("shell", "dumpsys", "display"):
        sh("shell", "input", "keyevent", "KEYCODE_WAKEUP")
        time.sleep(1)
    if "mDreamingLockscreen=true" in sh("shell", "dumpsys", "window"):
        sys.exit("Device is locked. Unlock it and re-run — adb must not bypass a keyguard.")


def nodes():
    sh("shell", "uiautomator", "dump", "/sdcard/plane-ui.xml")
    raw = sh("shell", "cat", "/sdcard/plane-ui.xml")
    start = raw.find("<hierarchy")
    if start < 0:
        return []
    try:
        root = ET.fromstring(raw[start:].strip())
    except ET.ParseError:
        return []
    out = []
    for n in root.iter("node"):
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        out.append({
            # hint is where Android puts a text field's placeholder; it is a
            # legitimate accessible name, though a poor one — it disappears
            # once the field has content.
            "label": (n.get("content-desc") or n.get("text")
                      or n.get("hint") or "").strip(),
            "box": (x1, y1, x2, y2),
            "center": ((x1 + x2) // 2, (y1 + y2) // 2),
            "size": (x2 - x1, y2 - y1),
            "clickable": n.get("clickable") == "true",
            "selected": n.get("selected") == "true",
            "pkg": n.get("package", ""),
        })
    return out


def ours(ns):
    """Nodes belonging to this app.

    Warns instead of silently returning nothing when something else is on top —
    another app's dialog or permission prompt stealing focus otherwise looks
    identical to "this screen has no controls".
    """
    mine = [n for n in ns if n["pkg"] == PKG]
    if not mine and ns:
        other = next((n["pkg"] for n in ns if n["pkg"]), "?")
        print(f"WARNING: {other} is in the foreground, not {PKG}", file=sys.stderr)
    return mine


def cmd_tree():
    awake()
    for n in ours(nodes()):
        if not n["label"]:
            continue
        head = n["label"].split("\n")[0][:64]
        more = " …" if "\n" in n["label"] else ""
        mark = "*" if n["clickable"] else " "
        sel = " [selected]" if n["selected"] else ""
        print(f'{mark} {n["center"][0]:>5},{n["center"][1]:<5}  {head}{more}{sel}')


def cmd_check():
    """Report tappable-but-anonymous nodes — the automation blind spots.

    A clickable node with no name of its own is still reachable if one of its
    descendants carries the label, because tapping the label's centre lands
    inside the clickable node. Compose does exactly this — it emits the click
    target and the text as separate nodes — so treating every anonymous
    clickable as a gap would flag the whole native ButtonGroup falsely.
    """
    awake()
    mine = ours(nodes())
    labelled = [n for n in mine if n["label"]]

    def covered(box):
        x1, y1, x2, y2 = box
        return any(x1 <= n["center"][0] <= x2 and y1 <= n["center"][1] <= y2
                   for n in labelled)

    gaps = [n for n in mine
            if n["clickable"] and not n["label"]
            # Ignore hairline nodes; those are dividers and scroll shims, not
            # controls a user or a script would ever target.
            and n["size"][0] > 24 and n["size"][1] > 24
            and not covered(n["box"])]
    if not gaps:
        print("OK — every tappable node on this screen has a label")
        return 0
    print(f"{len(gaps)} unlabelled tappable node(s):")
    for n in gaps:
        print(f'  at {n["center"][0]},{n["center"][1]}  size {n["size"][0]}x{n["size"][1]}')
    return 1


def cmd_tap(needle):
    awake()
    for n in ours(nodes()):
        if needle.lower() in n["label"].lower():
            x, y = n["center"]
            sh("shell", "input", "tap", str(x), str(y))
            print(f'tap "{n["label"].splitlines()[0][:48]}" @ {x},{y}')
            return 0
    print(f'NOT FOUND: "{needle}"')
    return 1


def cmd_type(text):
    sh("shell", "input", "text", text.replace(" ", "%s"))


def cmd_shot(name):
    awake()
    os.makedirs(SHOTS, exist_ok=True)
    path = f"{SHOTS}/{name}.png"
    with open(path, "wb") as f:
        f.write(sh("exec-out", "screencap", "-p", binary=True))
    print(path)


def cmd_flow(_name):
    """Walk the primary destinations, screenshotting and checking each."""
    awake()
    sh("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(3)
    failures = 0
    for dest in ["Inbox", "My Tasks", "Projects", "More"]:
        if cmd_tap(dest) != 0:
            failures += 1
            continue
        time.sleep(2)
        cmd_shot(f"flow-{dest.lower().replace(' ', '-')}")
        if cmd_check() != 0:
            failures += 1
    print(f"\nflow finished with {failures} problem(s)")
    return 1 if failures else 0


COMMANDS = {
    "tree": (cmd_tree, 0),
    "check": (cmd_check, 0),
    "tap": (cmd_tap, 1),
    "type": (cmd_type, 1),
    "shot": (cmd_shot, 1),
    "flow": (cmd_flow, 1),
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        return 1
    fn, argc = COMMANDS[sys.argv[1]]
    args = sys.argv[2:2 + argc]
    if len(args) < argc:
        print(f"{sys.argv[1]} needs {argc} argument(s)")
        return 1
    return fn(*args) or 0


if __name__ == "__main__":
    sys.exit(main())
