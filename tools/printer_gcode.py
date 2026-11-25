import os
#!/usr/bin/env python3
"""Send G-code to the Ender-3 through the Creality WiFi box and read the reply.

Usage: python3 /tmp/printer_gcode.py "M115" "M114" "M851"
"""
import socket, sys, time
from ftplib import FTP

BOX = "192.168.1.126"
USER, PW = "root", os.environ.get("BOX_PASS", "")


def telnet_cmd(cmd):
    s = socket.create_connection((BOX, 23), timeout=8)
    s.settimeout(1.0)

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
    s.sendall(USER.encode() + b"\n"); time.sleep(0.25); read()
    s.sendall(PW.encode() + b"\n"); time.sleep(0.5); read()
    s.sendall(cmd.encode() + b"\n"); time.sleep(0.4)
    out = read()
    s.close()
    return out


def log_bytes():
    f = FTP(BOX, timeout=8)
    f.login("anonymous", "anonymous@")
    f.cwd("/mmcblk0p1/creality/log")
    data = []
    f.retrbinary("RETR prt_com.log", data.append)
    f.quit()
    return b"".join(data)


def main():
    cmds = sys.argv[1:]
    if not cmds:
        print("Usage: printer_gcode.py 'M115' 'M114' ...")
        return
    offset = len(log_bytes())
    for cmd in cmds:
        telnet_cmd('echo -e "%s\\n" > /dev/ttyUSB0' % cmd)
        time.sleep(1.2)
        new = log_bytes()[offset:].decode(errors="replace")
        offset += len(new.encode(errors="replace"))
        print("\n### %s" % cmd)
        for line in new.splitlines():
            low = line.lower()
            if any(k in low for k in ("send_cmd_2_printer", "parse_prt_infor")):
                continue  # skip the daemon's own chatter
            if line.strip():
                print("  ", line.strip()[:300])


if __name__ == "__main__":
    main()
