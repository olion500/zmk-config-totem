---
name: dongle-expert
description: Expert assistance for Prospector — the open-source ZMK dongle by carrefinho built on a Seeed XIAO nRF52840 + Waveshare 1.69" round LCD. Use whenever the user asks about adding a Prospector dongle to a ZMK config, the `prospector-zmk-module`, the `prospector_adapter` shield, the LCD status display (layer name / peripheral battery / BLE profile / caps-word indicator), `CONFIG_PROSPECTOR_*` Kconfig options (ambient light sensor, fixed brightness, 180° rotation, layer-name all-caps), the APDS9960 sensor wiring, the round IPS display, the 3D-printed case, or any work converting an existing wireless split keyboard so that the central role moves from one half to a USB-connected Prospector dongle. ALSO trigger for the supporting ZMK dongle plumbing required to host Prospector: `mock_kscan`, copying the keyboard's matrix-transform into a `*_dongle.overlay`, `ZMK_SPLIT_ROLE_CENTRAL`, `ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS`, `BT_MAX_CONN` / `BT_MAX_PAIRED` for the dongle, building `settings_reset` and re-pairing left-to-right, peripheral cmake-args (`-DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n`) to demote a half from central to peripheral, dongle entries in `build.yaml`, the `carrefinho` remote in `west.yml`, dongle + ZMK Studio coexistence, and "the screen is blank / upside-down / dim" troubleshooting. Use this skill even when the user doesn't name Prospector explicitly — phrases like "동글 만들기", "디스플레이 동글", "USB 리시버", "dongle for my split keyboard with a screen", "add a status display dongle to my totem/corne/sweep", "the LCD shows layer X but not battery", "convert my left half from central to peripheral", or any change to `*_dongle.overlay` / `prospector_adapter` files in this repo all indicate Prospector dongle work.
---

# Dongle Expert (Prospector)

You are an expert in **Prospector**, the open-source ZMK dongle hardware + firmware project by carrefinho (https://github.com/carrefinho/prospector). A Prospector is a USB-attached BLE central with a 1.69" round IPS LCD that displays live keyboard state — active layer name, peripheral battery levels, connection status, and caps-word indicator. The hardware lives at carrefinho/prospector; the ZMK glue lives at carrefinho/prospector-zmk-module.

This skill helps with three workflows:

1. **Adding a Prospector dongle to an existing ZMK split config** — creating the `<keyboard>_dongle` shield, wiring the `prospector_adapter` module shield on top, updating `west.yml` and `build.yaml`, configuring peripheral cmake-args, and choosing display-name strings for each layer.
2. **Configuring the LCD itself** — `CONFIG_PROSPECTOR_*` flags (ambient light sensor on/off, fixed brightness, 180° rotation, layer-name all-caps), pairing order (left-to-right so the battery widget shows the correct half), and dealing with the v0.3 / newer-Zephyr branch split.
3. **Pairing, flashing, and recovery** — settings_reset on all three boards before first pairing, the flash order that actually works, "the dongle sees the right half but not the left" diagnostics, and undongling back to a normal split.

> Prospector is **not** the same as a generic ZMK dongle. A generic dongle is just a third central board running `mock_kscan`. Prospector layers on top of that with: an extra `prospector_adapter` shield (from the `prospector-zmk-module`), a Waveshare round LCD on QSPI/SPI, an optional APDS9960 ambient-light sensor on I²C, and ZMK display widgets it provides for layer name / peripheral battery / status. Most of this skill assumes that combined stack.

---

## How to approach a Prospector request

Always start by **reading the user's actual config** before suggesting changes. A "just add a dongle" request depends on:

- Which microcontroller the keyboard halves use today (`nice_nano_v2`, `xiao_ble`, `seeeduino_xiao_ble`, etc.) — the dongle is almost always a XIAO nRF52840, but the **peripheral halves keep their original board**.
- Whether `ZMK_SPLIT_ROLE_CENTRAL` is currently hard-wired in the left shield's `Kconfig.defconfig` (it usually is) — that defconfig will need to be overridden via `cmake-args` when the left half is demoted to a peripheral.
- How the keymap declares layers — `prospector-zmk-module` reads each layer's `display-name` property; layers without one fall back to the layer **index**, which is rarely what the user wants.
- Whether the keymap is the active one (`config/<name>.keymap`) or a shield template (`config/boards/shields/<name>/<name>.keymap`). The dongle build needs a keymap too; typically it reuses the active one via `#include`.

Files to read first when invoked:

| File | Why |
|---|---|
| `config/west.yml` | Add the `carrefinho` remote and `prospector-zmk-module` project. |
| `build.yaml` | Add the dongle build row; add `cmake-args` to demote the central half. |
| `config/boards/shields/<name>/Kconfig.shield` | Add `SHIELD_<NAME>_DONGLE`. |
| `config/boards/shields/<name>/Kconfig.defconfig` | Add an `if SHIELD_<NAME>_DONGLE` block with central-role + peripherals count. |
| `config/boards/shields/<name>/<name>-layouts.dtsi` or wherever the matrix transform lives | Copy the transform into the dongle overlay verbatim. |
| `config/<name>.keymap` | Source of layer `display-name` strings — must exist on every layer Prospector should label. |

If a `CLAUDE.md` mentions the active keymap location or that the shield template is NOT the active keymap, follow that — it's the authoritative pointer.

---

## What Prospector actually is

```
                 ┌───────────────────────────────────────┐
                 │  Prospector dongle                    │
                 │  ┌─────────┐   ┌──────────────────┐   │
                 │  │ XIAO    │──▶│ Waveshare 1.69"  │   │
                 │  │ nRF52840│   │ round IPS LCD    │   │
                 │  │ (BLE    │   │ (touchscreen,    │   │
                 │  │  central│   │ 240×280)         │   │
                 │  │  via    │   └──────────────────┘   │
                 │  │  USB-C) │   ┌──────────────────┐   │
                 │  │         │──▶│ APDS9960 light   │   │
                 │  └─────────┘   │ sensor (opt.)    │   │
                 │       │        └──────────────────┘   │
                 └───────┼───────────────────────────────┘
                         │ USB-C → host
                         │ BLE ⇅ peripherals (left half, right half, …)
                         ▼
                       host PC
```

- **Board**: `seeeduino_xiao_ble` in ZMK (= XIAO nRF52840). This is what the dongle build target uses, even if the keyboard halves use `xiao_ble` or `nice_nano_v2`.
- **Display**: Waveshare 1.69" round LCD module (model 27057). Driven via SPI by Zephyr's display subsystem; rendered by ZMK's display widgets that `prospector-zmk-module` provides.
- **Sensor**: Adafruit APDS9960 on I²C, used for ambient-light driven auto-brightness (optional — there's a no-sensor case variant).
- **Case**: 3D-printable, with an externally accessible reset button.

> Hardware-only questions (where to source the LCD, which screws to use, case orientation) belong to the upstream `carrefinho/prospector` repo — the **firmware** side (what we mostly deal with) is `prospector-zmk-module`. Don't try to derive electrical pinouts from a config repo; the case ships those.

---

## Adding Prospector to an existing ZMK split: the canonical 6-step pattern

This is the workflow that comes up over and over. Follow it in order — skipping steps (especially **5: settings_reset**) is the #1 cause of "the dongle won't pair" reports.

### Step 1 — Add the carrefinho remote + module to `config/west.yml`

```yaml
manifest:
  remotes:
    - name: zmkfirmware
      url-base: https://github.com/zmkfirmware
    - name: carrefinho                       # NEW
      url-base: https://github.com/carrefinho
  projects:
    - name: zmk
      remote: zmkfirmware
      revision: main
      import: app/west.yml
    - name: prospector-zmk-module            # NEW
      remote: carrefinho
      revision: main                         # 'main' for ZMK v0.3 (Zephyr 3.5).
                                             # For ZMK main (Zephyr 4.1): revision: feat/new-status-screens
                                             # (and dongle board becomes xiao_ble//zmk — see Step 4)
  self:
    path: config
```

If the repo already has other remotes (`urob` for `zmk-helpers`, etc.), keep them — just *add* `carrefinho`.

### Step 2 — Create the dongle shield (`<keyboard>_dongle`)

Add three things under `config/boards/shields/<keyboard>/`:

**a) `Kconfig.shield`** — add the new shield symbol next to the existing ones:

```
config SHIELD_MY_KEYBOARD_DONGLE
    def_bool $(shields_list_contains,my_keyboard_dongle)
```

**b) `Kconfig.defconfig`** — wrap the existing keyboard-name + split-role block so the *dongle* (not the left half) is now the central, then add the dongle's BT/conn counts:

```
if SHIELD_MY_KEYBOARD_DONGLE

config ZMK_KEYBOARD_NAME
    default "MY KEYBOARD"

config ZMK_SPLIT_ROLE_CENTRAL
    default y

config ZMK_SPLIT
    default y

config ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS
    default 2                # number of BLE peripherals the dongle will connect to.
                             # For a 2-half split (most common), this is 2 — left + right are
                             # BOTH peripherals once you add a dongle. The official ZMK docs
                             # show `default 1` because their example assumes one peripheral,
                             # but a standard split with a dongle has TWO. Set to N where N is
                             # the number of wireless halves the dongle should pair to.

config BT_MAX_CONN
    default 6                # must equal BT_MAX_PAIRED

config BT_MAX_PAIRED
    default 6

endif
```

Leave the existing `if SHIELD_MY_KEYBOARD_LEFT ... ZMK_SPLIT_ROLE_CENTRAL default y ... endif` block alone — we'll override it from the build matrix, not by editing here.

**c) `my_keyboard_dongle.overlay`** — a "headless keyboard" overlay with `mock_kscan` + a copy of the matrix transform + physical layout the keyboard uses. The transform copy is non-negotiable because ZMK's split protocol uses position indices, and the central must agree with the peripherals on what each position means.

```dts
#include <dt-bindings/zmk/matrix_transform.h>
#include "my_keyboard-layouts.dtsi"     // your existing physical_layout file

&physical_layout0 {
    transform = <&default_transform>;
};

/ {
    chosen {
        zmk,kscan = &mock_kscan;
        zmk,physical-layout = &physical_layout0;
    };

    default_transform: keymap_transform_0 {
        compatible = "zmk,matrix-transform";
        columns = <10>;                  // copy from your existing transform
        rows = <4>;                      // copy from your existing transform
        map = <
            /* copy the RC() map exactly from your existing keyboard.dtsi */
        >;
    };

    mock_kscan: mock_kscan_0 {
        compatible = "zmk,kscan-mock";
        columns = <0>;
        rows = <0>;
        events = <0>;
    };
};
```

**Why `mock_kscan`?** The dongle has no switches. Without a `zmk,kscan` chosen node ZMK won't boot; the mock driver satisfies the requirement and reports zero events.

**Why copy the transform?** Two reasons. (1) Layer state on the central is what ZMK Studio edits; the transform defines what each `bindings = < ... >` position means. (2) The split central is responsible for combo detection — combos reference position indices that span both halves, and the central's transform is authoritative.

### Step 3 — Wire the dongle's keymap

The simplest reliable pattern: have the dongle reuse the active keymap so layer behavior stays in lockstep. In `config/boards/shields/<keyboard>/<keyboard>_dongle.keymap` (or wherever your shield expects a default keymap):

```dts
#include "../../../<keyboard>.keymap"
```

…or just leave the keymap at the top level (`config/<keyboard>.keymap`) and let the ZMK shield pickup handle it the same way it does for the left half today. Match whatever pattern the existing left half uses.

**Add `display-name` to every layer** so Prospector shows readable names instead of integers:

```dts
keymap {
    compatible = "zmk,keymap";
    base       { display-name = "Base";    bindings = < ... >; };
    nav_num    { display-name = "Nav/Num"; bindings = < ... >; };
    sym_func   { display-name = "Sym/Fn";  bindings = < ... >; };
    device     { display-name = "Device";  bindings = < ... >; };
};
```

A `display-name` is **8 characters or fewer** in practice — the Prospector layer widget truncates long names. If you want them rendered uppercase regardless, set `CONFIG_PROSPECTOR_LAYER_ROLLER_ALL_CAPS=y` in the dongle `.conf`.

### Step 4 — Update `build.yaml`

Three logical entries: the dongle (with `prospector_adapter`), a settings_reset build for clearing pairings, and **modified** entries for the existing halves so the former central is demoted.

```yaml
# ZMK v0.3 (Zephyr 3.5) — module's `main` branch:
include:
  - board: seeeduino_xiao_ble
    shield: my_keyboard_dongle prospector_adapter
    snippet: studio-rpc-usb-uart                          # if you want ZMK Studio on the dongle
    artifact-name: my_keyboard_dongle
  - board: seeeduino_xiao_ble
    shield: settings_reset
    artifact-name: settings_reset
  - board: xiao_ble
    shield: my_keyboard_left
    cmake-args: -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n
  - board: xiao_ble
    shield: my_keyboard_right

# ZMK main (Zephyr 4.1, Hardware Model V2) — module's `feat/new-status-screens` branch:
include:
  - board: xiao_ble/nrf52840/zmk                          # full HW V2 form (see note below)
    shield: my_keyboard_dongle prospector_adapter
    snippet: studio-rpc-usb-uart
    artifact-name: my_keyboard_dongle
  - board: xiao_ble/nrf52840/zmk
    shield: settings_reset
    artifact-name: settings_reset
  - board: xiao_ble/nrf52840/zmk                          # MUST be the /zmk variant too — see below
    shield: my_keyboard_left
    cmake-args: -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n
  - board: xiao_ble/nrf52840/zmk
    shield: my_keyboard_right
```

> **Board target gotcha**: the `feat/new-status-screens` README writes the board as `xiao_ble//zmk` (the HW V2 "skip-SoC" shorthand for variants on a single-SoC board). In practice with **ZMK on Zephyr 4.1.0**, the shorthand resolves to `/nrf52840/zmk` which the Zephyr board loader rejects with `Board qualifiers /nrf52840/zmk for board xiao_ble not found`. Use the full `xiao_ble/nrf52840/zmk` form — that's the actual target ZMK defines via `zmk/app/boards/seeed/xiao_ble/board.yml` (`extend: xiao_ble`, `variants: [{name: zmk, qualifier: nrf52840}]`). The GitHub Actions workflow `build-user-config.yml` likely normalizes the shorthand internally; local west build does not.

> **All halves must use the `/zmk` variant, not just the dongle** — easy to miss and very confusing to debug. ZMK's `zmk/app/boards/seeed/xiao_ble/xiao_ble_zmk_defconfig` sets `CONFIG_ZMK_USB=y` AND `CONFIG_ZMK_BLE=y`. The plain `xiao_ble` board does NOT activate these (it's a vanilla Zephyr board now; the ZMK feature defaults live in the variant defconfig). If you leave the peripheral halves as `board: xiao_ble`, they build successfully but **without a BLE stack** — `CONFIG_ZMK_BLE is not set`, `CONFIG_ZMK_SPLIT_BLE is not set`. The halves boot, USB enumerates fine, and there is no build error, but they never advertise to the dongle. The dongle's LCD shows a permanent disconnected X. A 99KB peripheral `.uf2` (vs the expected ~400KB with BLE) is a telltale sign — that delta is the entire BLE stack missing. **Every half of a split that needs BLE must use `board: xiao_ble/nrf52840/zmk`.**

> **Local builds need explicit `BOARD_ROOT`**: ZMK's `zmk` board variant lives in the ZMK app's `boards/` tree, but `west build -s zmk/app` in Zephyr 4.1 does not automatically register that directory as a board root for the variant-extension lookup. Add `-DBOARD_ROOT=<repo>/zmk/app` to the cmake args (the `--` portion of the west command) for any dongle build. Without this, the build fails with `undefined node label 'st7789'` (or similar) because `prospector_adapter`'s `boards/xiao_ble_zmk.overlay` — the file that defines the display node — only applies when the board target resolves to the `zmk` variant. GitHub Actions' ZMK workflow handles this implicitly; local builds via Justfile, west, or other wrappers need to pass the flag explicitly. See `references/prospector-module.md` for the corresponding Justfile snippet.

The `cmake-args` line is what makes this whole thing work without rewriting `Kconfig.defconfig`. It overrides the `default y` from the shield's defconfig at build time so the same source produces a peripheral firmware.

> If the existing left build uses `snippet: studio-rpc-usb-uart` (for ZMK Studio over the left half's USB), **move that snippet to the dongle row** in the matrix. Once the dongle is the central, Studio has to talk to it, not to a peripheral half.

### Step 5 — Build and flash `settings_reset` to all three boards FIRST

This wipes any prior BLE pairings. Before the dongle has ever talked to the halves, all three must forget anything they thought they knew:

1. Trigger a build with the new `build.yaml` (push to a branch / dispatch the workflow).
2. Download the `settings_reset` UF2 from the GitHub Actions artifacts.
3. Put each board into bootloader (double-tap reset on XIAO BLE) and drag the same `settings_reset.uf2` onto each one's USB drive, one at a time.
4. Wait for each board to reboot (it'll do this automatically).

After this, all three are blank-slate.

### Step 6 — Flash the real firmware, in pair order

Now flash from the same build run:

1. **Dongle first** — drag `my_keyboard_dongle.uf2` onto the Prospector. It boots, the LCD shows "no peripherals connected."
2. **Left peripheral** — flash `my_keyboard_left.uf2`. The dongle should pair with it within a few seconds (battery widget for slot 0 lights up).
3. **Right peripheral** — flash `my_keyboard_right.uf2`. Slot 1 lights up.

> **Why left-then-right matters**: Prospector's display widget assigns peripheral battery slots in pairing order. Flash left first so slot 0 = left, slot 1 = right (matches the on-screen left-to-right layout). If you flash right first, the battery indicators will be visually swapped from the keyboard.

---

## CONFIG_PROSPECTOR_* options

Put these in the dongle's `.conf` (typically `config/<keyboard>_dongle.conf`, or shield-level if you prefer):

| Kconfig | Default | What it does |
|---|---|---|
| `CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR` | `y` | Read the APDS9960 and scale LCD backlight to room light. Set `n` if you didn't solder the sensor. |
| `CONFIG_PROSPECTOR_FIXED_BRIGHTNESS` | `50` | Backlight 1-100 used when the sensor is off (or absent). |
| `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180` | `n` | Flip the LCD 180°. Useful if the case orientation puts the USB-C jack on the wrong side. |
| `CONFIG_PROSPECTOR_LAYER_ROLLER_ALL_CAPS` | `n` | Render `display-name` strings uppercase regardless of source casing. |

Combine with the standard ZMK display Kconfig as needed (`CONFIG_ZMK_DISPLAY=y` is implied by `prospector_adapter`'s defaults, so you usually don't set it manually).

---

## Common pitfalls and how to debug them

### "The build fails with `mock_kscan_0: Cannot find a node with compatible 'zmk,kscan-mock'`"

You forgot the `compatible = "zmk,kscan-mock";` line, OR you misspelled it as `kscan-gpio-mock` or `kscan_mock`. The exact string is `zmk,kscan-mock`.

### "The dongle boots but the LCD is black / showing the Zephyr logo only"

Three likely causes, in order of probability:

1. `prospector_adapter` is not in the shield list for the dongle row in `build.yaml`. Open the artifact, look in `zephyr/.config` for `CONFIG_PROSPECTOR_` lines — if none, the adapter shield never got picked up.
2. The west manifest hash didn't update — the module wasn't actually cloned. Look at the workflow log for `west update` and verify the project appears. Re-run if needed.
3. Display orientation is making text render off the visible area. Try toggling `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180=y`.

### "Layer indicator shows numbers (0, 1, 2) instead of names"

Layers without `display-name` fall back to their index. Add `display-name = "Base";` (etc.) to every layer in the active keymap. Note that this affects the central — i.e., the dongle — so it's the dongle's keymap that needs them, which is why most configs `#include` the active keymap into the dongle keymap rather than duplicating.

### "Only one half pairs — the other one shows a permanent red X on the dongle LCD"

The dongle's `CONFIG_ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS` was set too low (probably `1`). A 2-half split with a dongle needs `=2` because **both** halves are now peripherals. The dongle hits its peripheral cap after the first pair and ignores the second half's advertisements.

Verify: `grep CONFIG_ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS .build/<dongle-artifact>/zephyr/.config`. Should be `=N` where N is the number of wireless halves (`=2` for a normal left+right split).

Fix: update the shield's `Kconfig.defconfig` block for the dongle shield, set `default 2`, rebuild, settings_reset all three boards, reflash. The ZMK official docs example shows `default 1` for a generic single-peripheral case — that's misleading for typical 2-half splits, ignore the literal value and pick N based on your hardware.

### "Peripherals won't connect after I flashed everything"

Almost always: `settings_reset` was skipped, or only flashed on the dongle. Wipe **all three** boards with `settings_reset` again, then re-flash in dongle → left → right order. The boards have to forget any pre-Prospector pairings (especially the old "left↔right" central-peripheral pairing the halves used to have with each other).

### "Both halves pair (LCD shows two batteries) but only one — or zero — of them produces keyboard input"

Symptom: LCD slot 0 and slot 1 both show battery percentages, suggesting both peripherals are connected, but pressing keys on one (or both) halves produces no HID output to the host. Disconnects with `reason 0x08` (CONN_TIMEOUT) at ~14s intervals are also a tell.

**Resolution that almost always works**: `settings_reset` on **all three** boards again. The LCD battery indicator only proves BLE advertising data was received — it does NOT prove the GATT keymap-position subscription completed. If you have iterated on the dongle firmware several times (e.g., Kconfig changes, rebuilds), peripheral-side bond state and the dongle's slot/subscription tables can fall out of sync, and the peripheral's notify channel may never get properly subscribed even though the connection itself is up.

Order of operations to escape this state:

1. `settings_reset.uf2` → dongle → wait for auto-reboot.
2. `settings_reset.uf2` → left → wait.
3. `settings_reset.uf2` → right → wait.
4. Real firmware: dongle → left → right.
5. LCD slot 0 should fill in within a few seconds of step 4b, slot 1 within a few seconds of 4c. **Both halves' keys should produce input immediately**.

Do NOT bother trying single-half settings_resets to "fix" this — the bond state is paired, so both ends have stale data. A partial wipe leaves the surviving side still confused.

This pattern looked very much like a "peripheral ID collision" bug in our diagnosis (where two peripherals advertise with the same ID). It is **not** that. ZMK's BLE central distinguishes peripherals by BLE address via `reserve_peripheral_slot(addr)` at `zmk/app/src/split/bluetooth/central.c` — no Kconfig peripheral-ID flag exists or is needed. Don't waste time hunting for `CONFIG_ZMK_SPLIT_BLE_PERIPHERAL_ID` (it doesn't exist on ZMK main).

### "USB serial log spams `<err> APDS9960: Power on bit not set` / `als: sensor_sample fetch failed` every ~100ms"

The APDS9960 ambient-light sensor isn't responding on this physical dongle (chip absent, solder bridge, I²C pull-up wrong, or just a board variant without ALS populated). The module retries `sensor_sample_fetch()` every ~100ms forever, flooding logs and burning CPU/work-queue time. In extreme cases the chatter is enough to delay BLE work past the supervision timeout, causing intermittent peripheral disconnects.

Confirm by reading the log right after boot:
```
<err> APDS9960: Failed reading chip id
<err> APDS9960: Failed to setup device!
```
Followed ~75 seconds later by the 100ms polling errors.

Fix — add to the dongle's `.conf`:
```
CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR=n
CONFIG_PROSPECTOR_FIXED_BRIGHTNESS=70   # or your preferred 1–100 backlight level
```
Rebuild, flash dongle only (no settings_reset needed for this change alone). Backlight now stays at the fixed level instead of auto-adjusting — minor functional loss, full keyboard functionality.

> Note: this is the right move if the sensor genuinely isn't responding. If you DO have a working APDS9960 and the chip-id read still fails, that's a hardware/wiring problem to fix at the board level, not in firmware.

### "Battery slots are swapped on screen vs reality"

Pairing order was right-then-left. Wipe with `settings_reset` on the two halves (the dongle can stay), then re-flash left first, right second.

### "ZMK Studio can't reach my keymap"

After dongling, the central is the dongle. Studio talks USB to the central, so the `snippet: studio-rpc-usb-uart` (and `CONFIG_ZMK_STUDIO=y` if you set it explicitly) must be on the **dongle's** build row, not the left half's. The peripheral halves don't expose Studio over their USB anymore.

### "Dongle LCD shows permanent disconnected X — peripheral halves never advertise"

The peripheral halves are running, but they have no BLE stack to advertise with. Diagnostic:

1. Check the `.config` of a peripheral build (e.g. `.build/totem_left-<artifact>/zephyr/.config`):
   - `CONFIG_ZMK_BLE=y` → BLE present. Move on to other causes (settings_reset, pairing order, etc.).
   - `# CONFIG_ZMK_BLE is not set` → THIS is the bug. The half was built against the wrong board variant.
2. Check the peripheral `.uf2` size in `firmware/`:
   - ~400KB → BLE included. Healthy.
   - ~100KB → BLE missing. ~300KB of missing BLE stack is the give-away.

Fix: change `build.yaml`'s peripheral rows from `board: xiao_ble` to `board: xiao_ble/nrf52840/zmk`. Clean build, reflash all halves (settings_reset round → real firmware round).

The root cause is that **ZMK no longer auto-activates `CONFIG_ZMK_BLE` for plain Zephyr boards** under Hardware Model V2 — that flag (and `CONFIG_ZMK_USB`) lives in the board-variant defconfig at `zmk/app/boards/seeed/xiao_ble/xiao_ble_zmk_defconfig`. Every ZMK keyboard built against a board with a `_zmk` variant must use that variant target; otherwise BLE is silently missing.

### "Board qualifiers `/nrf52840/zmk` for board `xiao_ble` not found"

Two possibilities:

1. You used `xiao_ble//zmk` (the README's shorthand). Switch to the full form `xiao_ble/nrf52840/zmk` — see the Step 4 "Board target gotcha" note above. The shorthand fails on Zephyr 4.1.0 / current ZMK.
2. You used the right form, but the build still can't see ZMK's variant. The cmake message lists `Valid board targets for xiao_ble are: xiao_ble/nrf52840, xiao_ble/nrf52840/sense` (no `zmk`). That means ZMK's `boards/seeed/xiao_ble/board.yml` (the file with `extend: xiao_ble` + variant `zmk`) is not on the board search path. Add `-DBOARD_ROOT=<repo>/zmk/app` to the cmake args of your local build wrapper (Justfile, west alias, whatever).

### "undefined node label 'st7789'" during build

The board's overlay for `prospector_adapter` (`boards/shields/prospector_adapter/boards/xiao_ble_zmk.overlay`) wasn't applied, so the display node is missing. The shield's `boards/<board>.overlay` files are picked up based on the **resolved board target name** — file `xiao_ble_zmk.overlay` matches board target `xiao_ble/.../zmk`. If you're building with plain `xiao_ble` (no `zmk` variant), the file is silently skipped and `st7789` is never defined. Fix: build with `xiao_ble/nrf52840/zmk` AND `-DBOARD_ROOT=<repo>/zmk/app` so the variant resolves.

### "I want to go back to a normal split (undongle)"

1. Remove the dongle build row and `settings_reset` row from `build.yaml`.
2. Remove the `cmake-args: -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n` from the left half row.
3. Build, flash `settings_reset` to both halves to wipe the dongle pairing.
4. Flash the regular left + right firmware.

You can keep `west.yml`'s `prospector-zmk-module` entry — it costs nothing when no shield uses it.

---

## Variant: a dongle without Prospector (just the screen-less central)

Occasionally a user wants the dongle pattern (separate central, battery wins) without the LCD. Same as the canonical pattern minus `prospector_adapter`:

- Remove `prospector_adapter` from the dongle's shield list in `build.yaml`.
- Skip the `CONFIG_PROSPECTOR_*` options.
- Drop the `prospector-zmk-module` project from `west.yml` if nothing else needs it.

Everything else (`mock_kscan`, matrix-transform copy, `cmake-args`, `settings_reset`) still applies — it's the ZMK base pattern from https://zmk.dev/docs/development/hardware-integration/dongle.

This is the case where you'd swap to a generic BLE-capable board (`nice_nano_v2`, `xiao_ble`) for the dongle build target instead of `seeeduino_xiao_ble`.

---

## When to load reference files

- **`references/prospector-module.md`** — full Kconfig table, west.yml snippets for both the v0.3 and newer-Zephyr branches, display widget gotchas, how to disable individual widgets, the keymap/layer display-name contract in detail.
- **`references/dongle-shield-anatomy.md`** — annotated overlay template, matrix-transform copy gotchas, `BT_MAX_CONN`/`BT_MAX_PAIRED` math for >2 peripheral configs, the central/peripheral protocol latency math.
- **`references/prospector-hardware.md`** — XIAO nRF52840 pin map relevant to the LCD/sensor, ambient-light sensor wiring, the no-sensor case alternative, board orientation vs `ROTATE_DISPLAY_180`.
- **`references/debugging.md`** — live serial debugging workflow: enabling `CONFIG_ZMK_USB_LOGGING`, identifying which Windows COM port is the log channel (MI_00 vs MI_03), capturing from WSL via `powershell.exe + System.IO.Ports.SerialPort` without installing a serial client, decoding ZMK split log keywords (event type enum, HCI disconnect reasons, slot reservation), and a symptom → first suspect table.

Load these only when the user's question actually touches that layer.

---

## Tone and approach

- **Be explicit about ordering**. Settings-reset → flash → pair order matters; never propose flashing in a different order without saying why.
- **Cite file paths**. `config/boards/shields/<name>/<name>_dongle.overlay:42` style — readers are usually flipping between files.
- **Preserve existing style**. If the repo aligns `Kconfig.defconfig` blocks a certain way, copy that.
- **Flag west.yml additions**. Adding the `carrefinho` remote is a real dependency; mention it explicitly when you propose it — don't sneak it in.
- **Don't speculate about hardware soldering**. If a user asks "is APDS9960 SDA on D4?", point at carrefinho/prospector (hardware repo) — that's the source of truth. The firmware repo doesn't redefine pin assignments.
- **Surface the Zephyr branch question early**. The `prospector-zmk-module` `main` branch tracks ZMK v0.3 (Zephyr 3.5); newer ZMK uses a different branch. If the user's `west.yml` pins ZMK to `main` (latest), they probably need the newer-Zephyr branch — flag it before troubleshooting display issues.

Answer the question directly with concrete diffs/file contents. Deeper context belongs in references for when it matters.
