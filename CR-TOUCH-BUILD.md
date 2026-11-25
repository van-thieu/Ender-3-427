# Ender-3 / Creality v4.2.7 + CR-Touch build notes

English | [繁體中文](CR-TOUCH-BUILD.zh-TW.md) | [Русский](CR-TOUCH-BUILD.ru.md)

Built from **Marlin 2.1.2.10** using the official
`Creality/Ender-3/CrealityV427` example configuration as the base, with the
CR-Touch settings from the previous configuration carried over.

## Build

```bash
python3 -m venv .venv
.venv/bin/pip install platformio
.venv/bin/pio run -e STM32F103RE_creality
```

Output: `.pio/build/STM32F103RE_creality/firmware.bin`.
Ready-to-flash copies are kept in [`firmware/`](firmware/).

## Board / probe settings

- `MOTHERBOARD BOARD_CREALITY_V427` — 32-bit Creality 4.2.7 board
- `#define BLTOUCH` — the CR-Touch is a BLTouch-compatible clone
  - Probe signal: `PB1` (`Z_MIN_PROBE_PIN`, the 5-pin probe port)
  - Servo/actuator: `PB0` (`SERVO0_PIN`)
- `#define BLTOUCH_DELAY 500` — extra command delay for the clone probe
- `NOZZLE_TO_PROBE_OFFSET { -30, 0, 0 }` — measured from the printer's live
  `M851` (`X-30.00 Y0.00 Z-1.38`); X/Y match the physical bracket, Z is
  re-calibrated after flashing
- `#define AUTO_BED_LEVELING_BILINEAR`, 5×5 grid
- `#define Z_SAFE_HOMING`
- `PROBING_MARGIN_LEFT/RIGHT 35`, `FRONT/BACK 15` so the offset probe stays on the bed
- `#define BABYSTEP_ZPROBE_OFFSET` — Z probe offset can be babystepped live
- `#define PROBE_OFFSET_WIZARD` — LCD-assisted Z-offset calibration
  (`PROBE_OFFSET_WIZARD_START_Z -1.0`)
- `Z_MIN_POS -5` — fixes the "nozzle can't reach the bed" issue: with a negative
  probe Z offset (`M851 Z-1.38`) the nozzle must travel below Z=0 to touch the
  bed, and the stock `Z_MIN_POS 0` software limit prevents that
- `Z_MAX_POS 350` — intentional: the printer has Creality's physical **Z-axis
  extension / "Z350" profiles kit** (the official firmware for this setup is
  named `Ender-3 HD4.2.7-Z350-...`). Do not reduce this to the stock 250.
- `BINARY_FILE_TRANSFER` + `CUSTOM_FIRMWARE_UPLOAD` — Marlin binary transfer
  capability (see "Remote updates" below for its practical limitations)
- `OTA_FIRMWARE_UPDATE` + `M936` — Creality MCU-OTA command handler. `M936 V2`
  now replies with `mcu reset ok` before rebooting, as the box expects.

## Flashing

The 4.2.7 board boots from a `.bin` file in the root of a FAT32 SD card.

1. Copy **one** firmware `.bin` to the card root.
2. Use a **new unique filename** — the Creality bootloader remembers the last
   filename and will not flash the same name twice.
3. Ensure there are **no other `.bin` files** on the card (a partial `.bin`
   from a failed transfer can be flashed by mistake).
4. Power off, insert the card, power on, and wait for the update to finish.
5. Remove the card and power-cycle the printer.

Verify with `M115` (expect Marlin 2.1.2.10) and `M211`
(expect `Zmin -5.00`, `Zmax 350.00`).

## After flashing (important)

1. `M502` then `M500` — reset settings to firmware defaults.
2. Home all axes (`G28`), then deploy/stow the probe with `M401` / `M402` to
   confirm the CR-Touch moves correctly.
3. Set the Z offset, e.g. `M851 Z-1.38`, then `M500`.
   Or use the LCD wizard: **Motion → Bed Leveling → Probe Offsets (Wizard)**.
   (`Z` in `NOZZLE_TO_PROBE_OFFSET` is only a starting value.)
4. Run `G29` to build the mesh, then `M500` to save it.
5. Fine-tune the first layer with babystepping while printing.

### Troubleshooting the probe

- If the probe does not deploy: `M280 P0 S10` (deploy) / `M280 P0 S90` (stow)
  and check the brown/red/orange wiring.
- If the trigger is not detected, check the black/white wires.
- If probing is flaky: increase `BLTOUCH_DELAY` or enable
  `BLTOUCH_FORCE_SW_MODE` in `Marlin/Configuration_adv.h` and rebuild.

## Remote updates via the Creality WiFi box

Remote firmware updates now work through the box using Marlin's BFT protocol.
See [README.md](README.md#creality-wifi-box-and-remote-updates) for the procedure.
The tooling is in [`tools/`](tools/): `gen_bft.py` stages the packets,
`bft_daemon.sh` runs on the box, and `box_telnet.py` / `printer_gcode.py` are
helpers for the box shell and G-code control.

## Optional

If your CR-Touch bracket uses a different X/Y offset, change
`NOZZLE_TO_PROBE_OFFSET` in `Marlin/Configuration.h`, rebuild, and re-calibrate.
