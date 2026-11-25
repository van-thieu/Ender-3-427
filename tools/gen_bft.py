#!/usr/bin/env python3
"""Generate and stage BFT upload files for the Creality WiFi box.

Usage: BOX_PASS=<password> python3 tools/gen_bft.py firmware/Ender3_...bin

Generates, for every Marlin BFT sync value 0..255:
  stream_<sync>.bin    complete BFT packet stream for that starting sync
  packets_<sync>.txt   one "offset length" line per packet (pacing boundaries)
  close_<sync>.bin     connection-CLOSE packet for that sync

Also uploads the persistent daemon, boot hook, and awk delay script.
"""
import importlib.util, io, os, sys, ftplib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOX = os.environ.get("BOX_HOST", "192.168.1.126")
FW = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    REPO, "firmware/Ender3_4.2.7_CRTouch_OTA_Reply_Marlin2.1.2.10.bin")
DEST = "FW.BIN"  # 8.3 filename the Creality bootloader will flash

spec = importlib.util.spec_from_file_location(
    "MBP", os.path.join(REPO, "buildroot/share/scripts/MarlinBinaryProtocol.py"))
MBP = importlib.util.module_from_spec(spec); spec.loader.exec_module(MBP)


class DummySerial:
    is_open=True; in_waiting=0; timeout=1; baudrate=115200; write_timeout=0
    def write(self,d): return len(d)
    def read(self,*a): return b""
    def readline(self): return b""
    def readlines(self): return []
    def reset_input_buffer(self): pass
    def flush(self): pass
    def open(self): pass
    def close(self): pass


class FakeSerialModule:
    SerialException=MBP.serial.SerialException; VERSION="gen"
    @staticmethod
    def Serial(*a,**k): return DummySerial()
MBP.serial = FakeSerialModule


def proto(sync):
    p = MBP.Protocol(None, 115200, 96, 0.0, 1000)
    p.connected = False; p.max_block_size = 96; p.sync = sync
    return p


def build(sync, data):
    p = proto(sync)
    stream = bytearray(); index = []
    def add(proto_id, typ, payload=b""):
        index.append((len(stream), len(p.build_packet(proto_id, typ, bytearray(payload)))))
        stream.extend(p.build_packet(proto_id, typ, bytearray(payload)))
        p.sync = (p.sync + 1) % 256
    add(1, 0)                                      # QUERY
    add(1, 1, b"\x00\x00" + DEST.encode() + b"\x00")  # OPEN
    for i in range(0, len(data), 96):
        add(1, 3, data[i:i+96])                    # WRITE
    add(1, 2)                                      # file CLOSE
    stream.extend(p.build_packet(0, 2, b""))       # connection CLOSE
    index.append((len(stream), len(p.build_packet(0, 2, b""))))
    return bytes(stream), index


def main():
    data = open(FW, "rb").read()
    f = ftplib.FTP(BOX, timeout=12)
    f.login("anonymous", "anonymous@")
    f.cwd("/mmcblk0p1/creality")
    try: f.mkd("creality/bft")
    except ftplib.error_perm: pass
    f.cwd("/mmcblk0p1/creality/bft")
    print("uploading", len(data), "bytes of firmware")
    for sync in range(256):
        stream, index = build(sync, data)
        f.storbinary("STOR stream_%d.bin" % sync, io.BytesIO(stream))
        f.storlines("STOR packets_%d.txt" % sync,
                    io.BytesIO("".join("%d %d\n" % x for x in index).encode()))
        f.storbinary("STOR close_%d.bin" % sync,
                     io.BytesIO(proto(sync).build_packet(0, 2, b"")))
    f.storbinary("STOR sync.bin", io.BytesIO(proto(0).build_packet(0, 1, b"")))
    for name in ["bft_daemon.sh", "custom_start.sh", "delay2.awk"]:
        f.storbinary("STOR " + name, open(os.path.join(REPO, "tools", name), "rb"))
    f.quit()
    print("done - touch creality/bft/trigger on the box to start an upload")


if __name__ == "__main__":
    main()
