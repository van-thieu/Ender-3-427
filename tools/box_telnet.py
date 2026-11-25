import os
#!/usr/bin/env python3
"""Run commands on the Creality WiFi box over telnet and print the output."""
import socket, sys, time

HOST = "192.168.1.126"
USER = "root"
PW = os.environ.get("BOX_PASS", "")

def main():
    cmds = sys.argv[1:]
    s = socket.create_connection((HOST, 23), timeout=8)
    s.settimeout(1.5)

    def read():
        out = b""
        try:
            while len(out) < 200000:
                d = s.recv(8192)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        return out.decode(errors="replace")

    read()
    s.sendall(USER.encode() + b"\n"); time.sleep(0.3); read()
    s.sendall(PW.encode() + b"\n"); time.sleep(0.6); read()
    for cmd in cmds:
        s.sendall(cmd.encode() + b"\n")
        time.sleep(0.7)
        out = read()
        print(f"\n### {cmd}\n{out}")
    s.close()

if __name__ == "__main__":
    main()
