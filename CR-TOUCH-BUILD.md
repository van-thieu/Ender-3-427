# Ender-3 / Creality v4.2.7 + CR-Touch firmware

Built from **Marlin 2.1.2.10** using the official `Creality/Ender-3/CrealityV427`
example configuration as the base, with the CR-Touch settings from the previous
configuration carried over.

## Build

```bash
python3 -m venv .venv
.venv/bin/pip install platformio
.venv/bin/pio run -e STM32F103RE_creality
```

Output: `.pio/build/STM32F103RE_creality/firmware.bin`
(copied to `firmware/Ender3_4.2.7_CRTouch_Marlin2.1.2.10.bin`).

## Board / probe settings

- `MOTHERBOARD BOARD_CREALITY_V427` — 32-bit Creality 4.2.7 board
- `#define BLTOUCH` — the CR-Touch is a BLTouch-compatible clone
  - Probe signal: `PB1` (`Z_MIN_PROBE_PIN`, the 5-pin probe port)
  - Servo/actuator: `PB0` (`SERVO0_PIN`)
- `#define BLTOUCH_DELAY 500` — extra command delay for the clone probe
- `NOZZLE_TO_PROBE_OFFSET { -42, -10, 0 }` — for the CR-Touch bracket left of the nozzle
- `#define AUTO_BED_LEVELING_BILINEAR`, 5x5 grid
- `#define Z_SAFE_HOMING`
- `PROBING_MARGIN_LEFT/RIGHT 45`, `FRONT/BACK 15` so the offset probe stays on the bed
- `#define BABYSTEP_ZPROBE_OFFSET` — Z probe offset can be babystepped live
- `Z_MAX_POS 350` — intentional: the printer has Creality's physical **Z-axis
  extension / "Z350" profiles kit** (the official firmware for this setup is named
  `Ender-3 HD4.2.7-Z350-...`). Do not reduce this value to the stock 250.

## Flashing

The 4.2.7 board boots from the `firmware.bin` / `Ender3...bin` file in the root of a
FAT32-formatted SD card. Power off, insert the card, power on, and wait for the
update to finish (the screen may go blank for a while). Remove the SD card and
power-cycle afterwards.

## After flashing (important)

1. `M502` then `M500` to reset settings to the firmware defaults.
2. Home all axes (`G28`), then deploy the probe with `M401` and stow with `M402`
   to confirm the CR-Touch moves correctly.
3. Measure the probe Z offset and set it, e.g. `M851 Z-2.50`, then `M500`.
   (The `Z` value in `NOZZLE_TO_PROBE_OFFSET` is only a starting value; calibrate it.)
4. Run `G29` to generate the mesh, then `M500` to save it.
5. If the probe does not deploy: run `M280 P0 S10` (deploy) / `M280 P0 S90` (stow)
   and check the brown/red/orange wiring. If the trigger is not detected, check the
   black/white wires.
6. If probing is flaky: increase `BLTOUCH_DELAY` or enable `BLTOUCH_FORCE_SW_MODE`
   in `Marlin/Configuration_adv.h` and rebuild.

## Optional

If your CR-Touch bracket uses a different X/Y offset, change
`NOZZLE_TO_PROBE_OFFSET` in `Marlin/Configuration.h`, rebuild, and re-calibrate.
