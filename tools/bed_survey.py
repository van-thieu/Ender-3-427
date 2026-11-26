#!/usr/bin/env python3
"""Survey bed heights at the spring / corner locations through the WiFi box.

Runs G30 at the center, the four edge midpoints, the four quadrant (spring)
centers and the four inset corners, then prints a height table.

Usage:
  BOX_PASS=<password> python3 tools/bed_survey.py          # home first, then survey
  BOX_PASS=<password> python3 tools/bed_survey.py --no-home
"""
import os
import re
import socket
import sys
import time
from ftplib import FTP

BOX = "192.168.1.126"
USER = "root"
PW = os.environ.get("BOX_PASS", "")
LOG_DIR = "/mmcblk0p1/creality/log"
FIFO = "/tmp/serailupfifo"

# Probe coordinates (mm). Inset by the clip-safe probing margins:
# X 35..200 (probe is 30mm left of the nozzle), Y 20..215.
POINTS = [
    ("center",    117.5, 117.5),
    ("front",     117.5,  20.0),
    ("back",      117.5, 215.0),
    ("left",       35.0, 117.5),
    ("right",     200.0, 117.5),
    ("quad FL",    76.25, 68.75),
    ("quad FR",   158.75, 68.75),
    ("quad BL",    76.25, 166.25),
    ("quad BR",   158.75, 166.25),
    ("corner FL",  35.0,  20.0),
    ("corner FR", 200.0,  20.0),
    ("corner BL",  35.0, 215.0),
    ("corner BR", 200.0, 215.0),
]

BED_RESULT = re.compile(r"Bed X:\s*([-\d.]+)\s*Y:\s*([-\d.]+)\s*Z:\s*([-\d.]+)")


def box_cmd(cmd):
    s = socket.create_connection((BOX, 23), timeout=8)
    s.settimeout(0.8)

    def read():
        out = b""
        try:
            while len(out) < 100000:
                d = s.recv(8192)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        return out.decode(errors="replace")

    read()
    s.sendall(USER.encode() + b"\n")
    time.sleep(0.25)
    read()
    s.sendall(PW.encode() + b"\n")
    time.sleep(0.5)
    read()
    s.sendall(cmd.encode() + b"\n")
    time.sleep(0.5)
    out = read()
    s.close()
    return out


def log_bytes():
    f = FTP(BOX, timeout=8)
    f.login("anonymous", "anonymous@")
    f.cwd(LOG_DIR)
    data = []
    f.retrbinary("RETR prt_com.log", data.append)
    f.quit()
    return b"".join(data)


def send_gcode(gcode):
    box_cmd("echo %s > %s" % (gcode, FIFO))


def main():
    do_home = "--no-home" not in sys.argv
    if not PW:
        print("Set BOX_PASS to the WiFi box root password.", file=sys.stderr)
        return 1

    offset = len(log_bytes())
    if do_home:
        print("Homing (G28)...", flush=True)
        send_gcode("G28")
        time.sleep(18)
        offset = len(log_bytes())

    results = []
    for name, x, y in POINTS:
        print("Probing %-10s X%6.2f Y%6.2f ... " % (name, x, y), end="", flush=True)
        send_gcode("G30 X%g Y%g" % (x, y))
        time.sleep(22)
        new = log_bytes()[offset:].decode(errors="replace")
        offset += len(new.encode(errors="replace"))
        match = None
        for m in BED_RESULT.finditer(new):
            match = m
        if match:
            z = float(match.group(3))
            print("Z %+.3f" % z, flush=True)
            results.append((name, x, y, z))
        else:
            reason = "Probing Failed" if "Probing Failed" in new else "no reply"
            print("FAIL (%s)" % reason, flush=True)
            results.append((name, x, y, None))

    if not results:
        return 1
    ok = [r for r in results if r[3] is not None]
    print("\n%-10s %8s %8s %9s" % ("point", "X", "Y", "Z (mm)"))
    for name, x, y, z in results:
        print("%-10s %8.2f %8.2f %9s" % (name, x, y, "%+.3f" % z if z is not None else "FAIL"))
    if ok:
        zs = [r[3] for r in ok]
        lo, hi = min(ok, key=lambda r: r[3]), max(ok, key=lambda r: r[3])
        print("\n%d/%d points probed; spread %.3f mm (low: %s, high: %s)" %
              (len(ok), len(results), hi[3] - lo[3], lo[0], hi[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
