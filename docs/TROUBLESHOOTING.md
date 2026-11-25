# Troubleshooting

English | [繁體中文](TROUBLESHOOTING.zh-TW.md) | [Русский](TROUBLESHOOTING.ru.md)

## Firmware does not flash from SD

- Use **one** `.bin` in the SD card root, with a **new unique filename** each time —
  the Creality 4.2.7 bootloader remembers the last name and refuses to reflash it.
- Delete any partial `.bin` left by a failed transfer before trying again.
- Card must be FAT32. Power off, insert, power on; wait for the screen to finish.
- Verify with `M115` (expect Marlin 2.1.2.10) and `M211` (`Zmin -5.00`, `Zmax 350.00`).

## CR-Touch does not deploy

- Test manually: `M280 P0 S10` (deploy), `M280 P0 S90` (stow).
- Check the brown/red/orange wiring to the probe port (PB1 / PB0 on the 4.2.7 board).
- If the probe triggers but the mesh is wrong, re-check `M851 X/Y` (currently X-30, Y0).
- If probing is flaky, increase `BLTOUCH_DELAY` or enable `BLTOUCH_FORCE_SW_MODE`
  in `Marlin/Configuration_adv.h` and rebuild.

## Nozzle cannot touch the bed

This was fixed in firmware with `Z_MIN_POS -5`. If it recurs:
- `M851 Z...` must be negative enough (start around `Z-1.38`).
- `M211` must report `Zmin -5.00`; if it reports `0.00`, the new firmware is not installed.
- Use the LCD wizard: **Motion → Bed Leveling → Probe Offsets (Wizard)**.

## Remote update fails

- Read `creality/bft/result.txt` on the box SD card.
- `no stream for sync <n>`: regenerate the staged files with `tools/gen_bft.py`.
- `resend requested`: packet corruption. Check that the SD card is inserted in the
  printer, that no other process is sending G-code, and retry — the daemon retries
  automatically with a fresh sync.
- `quiet daemon unavailable`: copy `prt_com.quiet` to `/mnt/creality/` on the box.
- If the printer stops answering ASCII commands after a failed transfer, it is stuck
  in BFT mode. Power-cycle the printer, or send a connection-CLOSE packet via
  `tools/gen_bft.py` output (`close_<sync>.bin`).
- A full transfer takes ~2 minutes. Do not power off the printer during it.

## Box is unreachable

- Check the box's IP and that it is on the same network (`192.168.1.126` by default).
- The HTTP status API is `http://<box>/protocal.csp?fname=Info&opt=main&function=get`.
- FTP is anonymous; telnet credentials are device-specific (not documented here).
