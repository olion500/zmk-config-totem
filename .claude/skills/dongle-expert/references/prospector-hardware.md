# Prospector hardware

Hardware-side reference for Prospector (https://github.com/carrefinho/prospector). This is the "what's actually on the PCB / wired up in the case" layer. The firmware repo (`prospector-zmk-module`) assumes this layout and references these components.

## Bill of materials (canonical)

| Part | Role | Notes |
|---|---|---|
| Seeed Studio XIAO nRF52840 | MCU | The dongle is **always** XIAO nRF52840. Don't substitute `nice_nano_v2` without rewiring — the case's USB-C cutout and the SPI/I²C pin choices target XIAO's pinout specifically. |
| Waveshare 1.69" round LCD module (model 27057) | Display | 240×280 IPS, capacitive touch (touch isn't wired/used by ZMK widgets), curved cover glass. |
| Adafruit APDS9960 | Ambient light + proximity + gesture sensor | Used only for ambient-light auto-brightness in firmware. Gesture/proximity are unused. |
| 3D-printed case (top + bottom + accent ring) | Enclosure | STL files in the hardware repo. Externally-accessible reset button cutout. |
| M2 and M2.5 pan/wafer head screws | Assembly | Lengths vary by case revision — check the assembly manual in the hardware repo. |
| USB-C cable | Host connection | The dongle is USB-powered; battery is irrelevant. |

There is a **no-sensor case variant** that omits the APDS9960 (smaller cutout). If you build that, set `CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR=n` so the firmware doesn't try to talk I²C to a missing device.

## Why XIAO nRF52840 specifically

- USB-C native (matches the case opening).
- nRF52840's BLE stack is what ZMK targets; both `seeeduino_xiao_ble` (Zephyr board name) and `xiao_ble` resolve to it.
- The XIAO footprint exposes enough SPI + I²C lines to drive both the LCD and the sensor.

In ZMK build files, the dongle's `board:` is `seeeduino_xiao_ble`. This is the older Zephyr alias; current Zephyr uses `xiao_ble`. Either works in modern ZMK — match whichever your keyboard halves are using to keep the matrix consistent, or just use `seeeduino_xiao_ble` if the module's docs/examples use it.

## Pin / bus assignments

The `prospector_adapter` shield overlay declares the exact pinmap; you don't (and shouldn't) redefine it in your dongle shield. The defaults it ships with:

- **LCD (SPI)**: shares SPI with the XIAO's primary SPI pins.
- **APDS9960 (I²C)**: uses XIAO's I²C0.
- **LCD backlight**: PWM-controlled GPIO for brightness.
- **Reset**: physical button on the case routed to the XIAO's reset line.

If you need to know the exact GPIOs (e.g., for a bring-up board where you're hand-wiring before printing the case), check `prospector_adapter`'s overlay in the `prospector-zmk-module` repo — that's the source of truth. **Don't infer pin assignments from this file** — they belong to the module and may evolve.

## Orientation and `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180`

The round LCD is physically symmetric, but the rendered content has a clear "up." Default orientation puts the USB-C jack at one specific side of the case; if your case revision points it the other way (or you prefer the cable coming out the opposite side relative to your typing position), flip via `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180=y`. There's no third or fourth rotation — round display, only two meaningful orientations.

## Ambient light sensor behavior

The APDS9960 reports a single lux-equivalent value periodically. The firmware maps that to backlight PWM duty cycle:

- Bright room (office, daylight) → near-max backlight
- Dim room (evening, mood lighting) → low backlight
- Total dark → minimum readable, NOT zero (you should still see the layer name)

If the sensor reports nonsense (case occluding it, sensor not seated), the screen will flicker between brightness levels. Two quick fixes:

1. Set `CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR=n` and pick a fixed brightness — diagnostic step to confirm it's the sensor.
2. Reseat the APDS9960 module and reflash. If the dongle was working before and started flickering, it's almost certainly a mechanical issue with the sensor module.

## What's NOT in the firmware repo

The hardware repo (`carrefinho/prospector`) owns:

- STL/STEP files for the case
- Assembly manual (visual guide)
- BOM with sourcing links
- PCB design files if/where a custom PCB is used
- Photos and case revisions

If a user asks "what screws do I need?" or "where do I solder the APDS9960?", those answers live in the hardware repo. The firmware side (this skill's domain) starts at "the LCD lights up and ZMK can render to it."

## Companion project: Forager

The same author maintains `carrefinho/forager`, a related keyboard project. It's not part of Prospector and not required — just sometimes mentioned in the same breath because users buy both.

## Compatibility with other ZMK keyboards

Prospector is **keyboard-agnostic** at the firmware level. Any ZMK split that supports being demoted from central role can drive a Prospector dongle:

- Corne, Lily58, Sweep, Sofle — all known-working.
- Anything where the existing central uses `zmk,kscan-gpio-matrix` or `zmk,kscan-direct` — fine.
- ZMK Studio-enabled keyboards — fine, just move the studio snippet to the dongle's build row.

What you DO need from your keyboard:

- A matrix transform you can copy into the dongle overlay (most keyboards have this in `<keyboard>.dtsi`).
- A physical layout (`physical_layout0` style) — most keyboards have this in `<keyboard>-layouts.dtsi` or inline in the main `.dtsi`.
- The shield's `Kconfig.defconfig` to be editable (i.e., it's in your config repo's `boards/shields/<keyboard>/`, not buried in a read-only upstream).

What you do NOT need:

- Any specific keymap structure — Prospector reads `display-name` if present, ignores it if not.
- Any specific behavior set — Prospector doesn't care about your homerow mods or combos.
- Bluetooth profiles — typical Prospector setups don't bother (USB-only to one host). They still work if you want them, just don't unlock anything special.

## Sourcing notes

- Waveshare 1.69" round LCD: Waveshare's own store and Aliexpress; ~$20-25 USD as of recent runs.
- XIAO nRF52840: Seeed Studio direct or third-party resellers; ~$11 USD.
- APDS9960: Adafruit (with breakout) or Aliexpress (bare module) — both work; Adafruit's has better documentation.
- Case: print yourself (PLA or PETG, supports off, 0.2mm layer height) from STLs in the hardware repo.

The total parts cost is usually under $50 if you have access to a 3D printer.
