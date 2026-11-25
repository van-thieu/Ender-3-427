# Ender-3 / Creality v4.2.7 + CR-Touch firmware

English | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md)

Custom [Marlin 2.1.2.10](https://marlinfw.org/) firmware for an **Ender-3** with:

- **Creality v4.2.7** 32-bit mainboard (STM32F103RET6)
- **CR-Touch** auto bed-leveling probe (BLTouch-compatible clone)
- **Z-axis extension kit** — 350 mm Z travel (Creality "Z350" profiles)
- Stock LCD / display configuration

The active development branch is
[`upgrade-marlin-2.1.2.10-crtouch`](https://github.com/van-thieu/Ender-3-427/tree/upgrade-marlin-2.1.2.10-crtouch).
`master` is the untouched upstream import.

## Documentation

- [CR-Touch build & calibration notes](CR-TOUCH-BUILD.md) —
  [繁體中文](CR-TOUCH-BUILD.zh-TW.md) ·
  [Русский](CR-TOUCH-BUILD.ru.md)
- Original upstream Marlin documentation: <https://marlinfw.org/docs/>

## Key firmware settings

| Setting | Value | Why |
|---|---|---|
| `MOTHERBOARD` | `BOARD_CREALITY_V427` | 32-bit Creality 4.2.7 board |
| `BLTOUCH` | enabled | CR-Touch is a BLTouch-compatible probe on PB1 / servo PB0 |
| `BLTOUCH_DELAY` | `500` | Extra command delay for the clone probe |
| `NOZZLE_TO_PROBE_OFFSET` | `{ -30, 0, 0 }` | Measured from the printer's live `M851` (X-30, Y0); Z is calibrated at runtime |
| `AUTO_BED_LEVELING_BILINEAR` | enabled, 5×5 grid | Mesh bed leveling |
| `Z_SAFE_HOMING` | enabled | Probe-based Z homing at bed center |
| `Z_MIN_POS` | `-5` | Lets the nozzle move below Z=0 so it can actually touch the bed with a negative Z offset |
| `Z_MAX_POS` | `350` | Physical Z-axis extension ("Z350") — do **not** reduce to the stock 250 |
| `PROBING_MARGIN_LEFT/RIGHT` | `35` | Keeps the offset probe on the bed |
| `BABYSTEP_ZPROBE_OFFSET` | enabled | Live Z-offset adjustment while printing |
| `PROBE_OFFSET_WIZARD` | enabled | LCD-assisted Z-offset calibration |
| `BINARY_FILE_TRANSFER`, `CUSTOM_FIRMWARE_UPLOAD` | enabled | Marlin binary file-transfer capability (see limitations below) |
| `M936` | enabled | Creality MCU-OTA command handler (for compatible boards) |

## Building

Requires Python 3 and PlatformIO:

```bash
python3 -m venv .venv
.venv/bin/pip install platformio
.venv/bin/pio run -e STM32F103RE_creality
```

The binary is written to
`.pio/build/STM32F103RE_creality/firmware.bin`. Ready-to-flash copies are in
[`firmware/`](firmware/).

## Flashing (SD card required)

1. Copy one firmware `.bin` to the **root of a FAT32 SD card**.
2. Rename it to a **new unique name** — the Creality 4.2.7 bootloader remembers the
   previous filename and will not flash the same name twice.
3. Make sure there is **only one `.bin` file** on the card.
4. Power off the printer, insert the card, power on, and wait for the update to
   finish (the screen may go blank for a while).
5. Remove the SD card and power-cycle the printer.

Verify with `M115`: it should report **Marlin 2.1.2.10** and the build date.

## First-boot calibration

1. `M502` then `M500` — reset settings to firmware defaults.
2. `G28` — home all axes; `M401` / `M402` — deploy/stow the CR-Touch.
3. Set the Z offset, e.g. `M851 Z-1.38`, then `M500`. Or use the LCD wizard:
   **Motion → Bed Leveling → Probe Offsets (Wizard)**.
4. `G29` — probe the mesh, then `M500` to save it.
5. Fine-tune the first layer with babystepping while printing.

See [CR-TOUCH-BUILD.md](CR-TOUCH-BUILD.md) for troubleshooting.

## Creality WiFi box and remote updates

The box provides monitoring, G-code control, and **remote firmware updates**.

- Status API: `http://<box>/protocal.csp?fname=Info&opt=main&function=get`
- FTP: anonymous access to the box SD card
- Telnet shell: credentials are device-specific and intentionally omitted here

### Remote firmware updates

A persistent uploader is installed on the box and starts at every boot:

- `/mnt/creality/custom_start.sh` (registered in `/mnt/creality/_md5_app`)
- `/mnt/creality/bft_daemon.sh`, which watches for `creality/bft/trigger`
- `creality/bft/result.txt` records each upload attempt

To prepare an update, run `python3 tools/gen_bft.py <firmware.bin>` on a PC with
`BOX_PASS` set; it stages pre-generated BFT packets for all 256 sync values onto
the box SD card. Then create `creality/bft/trigger` on the box. The daemon
silences the box's polling daemon, enters `M28 B1` mode, sends one packet at a
time, verifies the acknowledgements, and finishes with `M21` and `M997` so the
printer reboots and the bootloader installs the new firmware.

Requirements: the SD card must be in the printer (the firmware is written to it),
the target filename must be a new unique 8.3 name each time (`FW.BIN` is used by
the staged tool), and the printer must not be powered off during the ~2 minute
transfer.

## License

Marlin firmware is GPL-3.0. See [LICENSE](LICENSE).

## More documentation

- [Documentation index](docs/README.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Creality WiFi box notes](docs/BOX-NOTES.md)
