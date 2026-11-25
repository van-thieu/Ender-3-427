# Creality WiFi box notes

English | [繁體中文](BOX-NOTES.zh-TW.md) | [Русский](BOX-NOTES.ru.md)

This documents what was learned about the `CXSWBox` (firmware V3.04b06) connected
to the printer by USB and to the network by Ethernet. A full snapshot of the
running box (binaries, scripts, config) is kept at `/tmp/box_snapshot/` on the
workstation; it can be used to restore the box.

## Access

- HTTP status API on port 81: `/protocal.csp?fname=Info&opt=main&function=get`
- Anonymous FTP to the box SD card (`/mmcblk0p1/`)
- Telnet shell (credentials are device-specific and intentionally omitted here)

The box runs a MediaTek RT2880 / Linux 2.6.36 SDK build. Its `prt_com` daemon owns
`/dev/ttyUSB0` (CH341 USB-serial, 115200 baud) and polls the printer with
`M105`/`M27`/`M31`. Direct writes to the serial port do not work reliably unless
that daemon is running.

## Firmware image

`cxsw_update.tar.bz2` is the official box firmware package: a U-Boot image with a
kernel plus an encrypted/obfuscated root filesystem (high entropy, no recognizable
squashfs/JFFS2 signature), `install.sh`, and a writable `rw_dir/` hook. It does not
contain source code for `prt_com`, and matching its root filesystem to the running
box does not provide a patchable source tree.

## Built-in MCU OTA (not usable on this board)

The box has an MCU OTA routine triggered by the FIFO command `mcu_ota`:

1. It looks for `creality/mcu_ota.bin` on its SD card.
2. Sends `M936 V2` to the printer and waits for `mcu reset ok`.
3. Streams the firmware to the bootloader.

On the 4.2.7 board this fails: Creality's stock 4.2.7 firmware contains no `M936`
handler, and the bootloader never enters OTA mode. Even after adding `M936` and
patching the box's wait loop, the streamed bytes were interpreted by Marlin as
invalid G-code. This path is therefore not used.

## The working solution: Marlin BFT

Marlin 2.1.2.10 has `BINARY_FILE_TRANSFER` enabled (`M28 B1 <file>`). A persistent
uploader on the box drives it:

- Boot hook: `/mnt/creality/custom_start.sh`, registered in `_md5_app`, starts
  `bft_daemon.sh` on every boot.
- `creality/bft/` holds pre-generated `stream_<sync>.bin`, `packets_<sync>.txt`,
  `close_<sync>.bin`, and `sync.bin` for all 256 sync values.
- Creating `creality/bft/trigger` starts an upload. The daemon swaps in a silenced
  `prt_com`, enters binary mode, writes exactly one packet at a time with ~30 ms
  gaps (BusyBox `sleep` cannot do fractions; `awk` is used), verifies >1700 `okN`
  replies, sends CLOSE, then `M21` and `M997` so the printer reboots and installs
  the firmware. The original daemon is restored afterward.
- Progress/errors go to `creality/bft/result.txt`.

Important details that made it reliable:

- Never split a BFT packet across writes — Marlin times out waiting for the rest.
- Do not run `stty` while the transfer is active: opening/closing the port toggles
  DTR and resets the Creality board.
- The daemon's `M105`/`M27`/`M79`/`M930`/`M115` traffic corrupts the binary stream,
  so it is silenced during transfers.
- Parse log responses from a fresh byte/line offset; old `ok`/`rs` lines cause false
  success/failure detection.
