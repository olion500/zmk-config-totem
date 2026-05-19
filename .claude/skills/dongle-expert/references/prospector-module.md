# prospector-zmk-module

The full reference for the `prospector-zmk-module` (https://github.com/carrefinho/prospector-zmk-module) — the ZMK module that provides the `prospector_adapter` shield, the LCD widgets, and the `CONFIG_PROSPECTOR_*` Kconfig surface.

## What the module provides

- A `prospector_adapter` shield (overlay + Kconfig) that wires the Waveshare 1.69" LCD over SPI, the APDS9960 over I²C, and pulls in Zephyr's display + LVGL support automatically.
- ZMK display **widgets** for: active layer name, peripheral battery (per-slot bar), connection status, caps-word indicator.
- A handful of `CONFIG_PROSPECTOR_*` Kconfig switches for behavior tuning.

It does **not** define the underlying split topology, mock_kscan, or matrix transform — those still come from your `<keyboard>_dongle.overlay`. The adapter shield "plugs into" any dongle shield you provide.

## west.yml entry (canonical)

```yaml
manifest:
  remotes:
    - name: zmkfirmware
      url-base: https://github.com/zmkfirmware
    - name: carrefinho
      url-base: https://github.com/carrefinho
  projects:
    - name: zmk
      remote: zmkfirmware
      revision: main
      import: app/west.yml
    - name: prospector-zmk-module
      remote: carrefinho
      revision: main          # see "branch selection" below
  self:
    path: config
```

### Branch selection

The module documents two branches (from its README, as of late 2025):

| Branch | Targets | Dongle board target (README) | Dongle board target (what actually works locally) |
|---|---|---|---|
| `main` | ZMK **v0.3** (Zephyr 3.5) | `seeeduino_xiao_ble` | `seeeduino_xiao_ble` |
| `feat/new-status-screens` | ZMK **main** (Zephyr 4.1, HW Model V2) — WIP | `xiao_ble//zmk` | **`xiao_ble/nrf52840/zmk`** |

**How to tell which you need**: look at the ZMK project's `revision:` in your `west.yml`.

- `revision: v0.3` → module `main` branch, dongle board `seeeduino_xiao_ble`.
- `revision: main` → module `feat/new-status-screens` branch, dongle board `xiao_ble/nrf52840/zmk`.

The `feat/new-status-screens` branch is explicitly marked work-in-progress by the maintainer; expect occasional churn. Pin to a commit SHA if you want stability, or stay on the branch name to track updates.

#### The `xiao_ble//zmk` vs `xiao_ble/nrf52840/zmk` snag

The module README says to build with `xiao_ble//zmk`. This is the HW Model V2 "skip-SoC" shorthand (the empty slot between the two slashes means "the board's single SoC"). In **GitHub Actions** the upstream ZMK workflow accepts the shorthand. In **local west build under Zephyr 4.1.0** it fails:

```
CMake Error at zephyr/cmake/modules/boards.cmake:304 (message):
  Board qualifiers `/nrf52840/zmk` for board `xiao_ble` not found.
  Valid board targets for xiao_ble are:
    xiao_ble/nrf52840
    xiao_ble/nrf52840/sense
```

Use the explicit `xiao_ble/nrf52840/zmk` form. That's the target ZMK actually defines in `zmk/app/boards/seeed/xiao_ble/board.yml`:

```yaml
board:
  extend: xiao_ble
  variants:
    - name: zmk
      qualifier: nrf52840   # this is the SoC the variant attaches to
```

If your build framework normalizes either form, great. If it passes the board string through to cmake unchanged (Justfile, hand-rolled wrappers, etc.), use the full form.

If the LCD never lights up and the Actions build log shows Zephyr API mismatches (`undefined reference to`, deprecated display API symbols, LVGL version errors), that's almost always a branch / board-variant mismatch.

### Peripheral halves also need the `/zmk` variant (not just the dongle)

This is the most subtle and frequently missed pitfall in the entire setup. Under HW Model V2 + current ZMK:

| Board target | Default `CONFIG_ZMK_BLE` | Default `CONFIG_ZMK_USB` |
|---|---|---|
| `xiao_ble` (plain Zephyr board) | **not set** | **not set** |
| `xiao_ble/nrf52840/zmk` (ZMK variant) | `=y` (via `xiao_ble_zmk_defconfig`) | `=y` |

A natural-looking `build.yaml` puts the dongle on `xiao_ble/nrf52840/zmk` (it has to, for Prospector overlays to apply) and leaves the existing halves on `xiao_ble` (which is what they had before dongling). **Don't.** With `board: xiao_ble`, the halves build cleanly with no error, USB enumerates, but `CONFIG_ZMK_BLE is not set` → no BLE stack → no advertising → dongle LCD shows a permanent disconnected X.

Signature symptoms:

- `grep CONFIG_ZMK_BLE .build/<peripheral>/zephyr/.config` → `# CONFIG_ZMK_BLE is not set`
- Peripheral `.uf2` is ~100KB (no BLE stack). With BLE it should be ~400KB. The ~300KB delta is the missing Bluetooth subsystem + ZMK BLE code.
- Dongle USB enumerates fine, peripheral USB enumerates fine, but the dongle LCD never picks up either peripheral.

Fix: every row in `build.yaml` that needs ZMK features should use `board: xiao_ble/nrf52840/zmk` (or the equivalent for whatever ZMK board you're using — `nice_nano_v2//zmk`, etc. — same principle applies wherever ZMK ships a variant defconfig).

If the build error catch in upstream `build-user-config.yml` is active (the "Missing ZMK Compat" check, see https://zmk.dev/blog/2025/12/09/zephyr-4-1#zmk-board-variant), this is caught at CI time. Local builds via `just`/`west` bypass that check, so the misconfiguration ships silently. The fix is mechanical (one board-string change per row); the diagnostic is the painful part.

### Local west build needs explicit `BOARD_ROOT`

When you run `west build -s zmk/app -b xiao_ble/nrf52840/zmk ...` directly (no GitHub Actions), Zephyr 4.1's board loader does not automatically register `zmk/app/boards/` as a board search root for variant extensions. The build fails to find the `zmk` variant and either:

- (with the shorthand `xiao_ble//zmk`) rejects the qualifier outright, or
- (with the full form) builds against plain `xiao_ble/nrf52840`, missing the variant-specific overlay → `prospector_adapter` can't find `&st7789` → devicetree error `undefined node label 'st7789'`.

The fix is to pass `-DBOARD_ROOT=<repo>/zmk/app` to cmake (i.e., after the `--` in the west invocation). Example bare-west command:

```bash
west build -s zmk/app -d .build/totem_dongle \
    -b xiao_ble/nrf52840/zmk \
    -S studio-rpc-usb-uart \
    -- \
    -DZMK_CONFIG="$PWD/config" \
    -DBOARD_ROOT="$PWD/zmk/app" \
    -DSHIELD="totem_dongle prospector_adapter"
```

For Justfile-driven builds, the equivalent change to `_build_single` is:

```just
west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
    -DZMK_CONFIG="{{ config }}" \
    -DBOARD_ROOT="{{ justfile_directory() }}/zmk/app" \
    ${shield:+-DSHIELD="$shield"} \
    ${cmake_args}
```

(Adding `BOARD_ROOT` is harmless for non-dongle builds — Zephyr just gets one extra path to search and continues to find the standard `xiao_ble/nrf52840`.)

The GitHub Actions workflow handles this implicitly because the upstream `build-user-config.yml` runs `west boards --board-root .../zmk/app/module --board-root .../zmk/app ...` for the post-build "ZMK Compat" check, and the `find_package(Zephyr)` path it uses ends up walking those roots. Local west builds don't get the same treatment.

## build.yaml: how `prospector_adapter` is invoked

`prospector_adapter` is a **secondary shield** — it's always combined with the dongle shield you wrote, never alone:

```yaml
# ZMK v0.3 (Zephyr 3.5):
include:
  - board: seeeduino_xiao_ble
    shield: my_keyboard_dongle prospector_adapter
    artifact-name: my_keyboard_dongle

# ZMK main (Zephyr 4.1, Hardware Model V2):
include:
  - board: xiao_ble//zmk
    shield: my_keyboard_dongle prospector_adapter
    artifact-name: my_keyboard_dongle
```

The order in the `shield:` string is `<your dongle shield> prospector_adapter`. Zephyr concatenates shield overlays; the dongle shield establishes the split + mock_kscan + transform, and `prospector_adapter` adds the display/sensor overlay on top.

## CONFIG_PROSPECTOR_* reference

Put these in the dongle's `.conf` — either at the shield level (`config/boards/shields/<name>/<name>_dongle.conf`) or top-level (`config/<name>_dongle.conf` matching the shield name).

### `CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR` (default: `y`)

Enables I²C reads from the APDS9960 and uses the lux reading to scale the LCD backlight. When `n`, the backlight is held at `CONFIG_PROSPECTOR_FIXED_BRIGHTNESS`.

Set to `n` if:
- You built the no-sensor case variant.
- The APDS9960 didn't seat properly and you don't want I²C errors flooding the log.
- You want a consistent brightness regardless of room lighting (e.g., for photo/video work).

### `CONFIG_PROSPECTOR_FIXED_BRIGHTNESS` (default: `50`, range: `1..100`)

The brightness used when the ambient sensor is disabled or unavailable. `100` is full; `1` is barely visible. `50` is a reasonable office-light default. Below `10` is hard to read in normal room light; above `80` causes noticeable glare from the round cover lens at night.

### `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180` (default: `n`)

Rotates the rendered display 180°. Useful when the case was assembled with the USB-C jack pointing the "wrong" way relative to the user's preferred sight line — flip this rather than disassembling.

### `CONFIG_PROSPECTOR_LAYER_ROLLER_ALL_CAPS` (default: `n`)

Renders the active-layer text uppercase regardless of the source `display-name` casing. Set `y` if you've named your layers mixed-case for the keymap source but want consistent caps on the display.

## Display widgets and what they show

The module provides a fixed set of widgets that compose the LCD layout. From the module README:

| Widget | Pulls from | Notes |
|---|---|---|
| Active layer name | `display-name` property on the currently-topmost active layer in `keymap { }` | Falls back to layer index (0, 1, 2, …) when `display-name` is missing. |
| Peripheral battery bar | `zmk,battery-reporting` events from each peripheral half | Slot index = pairing order. Pair left first to get slot 0 = left. |
| Connection indicator | Each peripheral's BLE link state | Goes red/off when a peripheral disconnects (e.g., sleeps). |
| Caps-word indicator | `caps_word_state` from the ZMK runtime | Lights up while caps-word is active. |

There is currently **no widget for**: WPM, HID/USB output mode, profile selection, custom text. The layout is fixed by the module; you can't reorder widgets without modifying the module source.

## Keymap requirements (display-name)

Every layer Prospector should label needs a `display-name`. Without it, the widget shows the integer index:

```dts
keymap {
    compatible = "zmk,keymap";
    base       { display-name = "Base";    bindings = < ... >; };
    nav_num    { display-name = "Nav/Num"; bindings = < ... >; };
    sym_func   { display-name = "Sym/Fn";  bindings = < ... >; };
    device     { display-name = "Device";  bindings = < ... >; };
};
```

**Length**: Aim for ≤ 8 visible characters. The widget on the 240×280 round LCD truncates beyond that. Some configs use very short names ("Nav", "Sym") to maximize legibility at a glance.

**Casing**: Either match your taste or use `CONFIG_PROSPECTOR_LAYER_ROLLER_ALL_CAPS=y` for uniformity. Lowercase is harder to read on a small display in low light.

**Reserved layers**: If you have `extra1 { status = "reserved"; };` placeholder layers, you don't need `display-name` — they never become active so the widget never shows their label.

## Pairing order semantics

Prospector assigns peripheral slot indices in **first-pair-wins** order. The dongle records the first peripheral that pairs as slot 0, the second as slot 1, and so on. This persists across reboots (Zephyr's settings module saves the bond + the slot mapping).

This is why the canonical pattern is:

1. `settings_reset` all three boards (wipes the slot map).
2. Flash dongle firmware.
3. Flash **left** half first → it pairs → slot 0 = left.
4. Flash **right** half → it pairs → slot 1 = right.

If the slot order is wrong on screen (left half's battery showing on the right side of the LCD), redo from step 3.

## Disabling individual widgets

The module doesn't expose per-widget enable flags in its public Kconfig as of this writing. If you need a custom layout (e.g., hide caps-word indicator, show only layer + battery), you'd fork `prospector-zmk-module` and edit the widget composition in its overlay. For most users this is overkill — the default layout is the practical reason to use Prospector.

## Z-axis: how the module interacts with ZMK Studio

ZMK Studio talks RPC over USB-CDC to the central. Once the Prospector is the central, Studio reaches the keyboard through the dongle's USB-C — not through the left half's USB anymore.

To enable Studio on a Prospector dongle, the dongle build row needs:

```yaml
- board: seeeduino_xiao_ble
  shield: my_keyboard_dongle prospector_adapter
  snippet: studio-rpc-usb-uart
```

…and the dongle's `.conf` needs `CONFIG_ZMK_STUDIO=y` (often with `CONFIG_ZMK_STUDIO_LOCKING=n` for permissionless editing).

There's no conflict between the LCD and Studio — they coexist fine. The LCD continues to reflect runtime state while Studio is connected.

## Performance / latency notes

- Prospector adds **~1ms** of latency to whichever half used to be central (it now relays through BLE → dongle → USB instead of USB-direct).
- The other halves see a **~6.5ms average reduction** (BLE-to-USB-central → BLE-to-USB-dongle is unchanged in protocol but the dongle's BLE stack tends to be less loaded than a half running matrix scan + sleep state).
- The LCD redraws are async to keyboard handling; there's no measurable input latency cost from the screen.

These come from the upstream ZMK dongle docs (https://zmk.dev/docs/development/hardware-integration/dongle), confirmed by the module README.
