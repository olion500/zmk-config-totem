# Dongle shield anatomy

A deep-dive on the `<keyboard>_dongle` shield — the part of the Prospector setup that's "just ZMK" (not Prospector-specific). The `prospector_adapter` shield layers on top of this; everything in this file would apply equally to a screenless generic dongle.

## Three files, in order of build relevance

```
config/boards/shields/<keyboard>/
├── Kconfig.shield             ← adds SHIELD_<KEYBOARD>_DONGLE symbol
├── Kconfig.defconfig          ← sets keyboard name, central role, BT limits
└── <keyboard>_dongle.overlay  ← devicetree: mock_kscan + transform + chosen
```

## Kconfig.shield

Adds the dongle symbol next to the existing left/right symbols. Just one line, mirroring the existing pattern:

```
config SHIELD_MY_KEYBOARD_LEFT
    def_bool $(shields_list_contains,my_keyboard_left)

config SHIELD_MY_KEYBOARD_RIGHT
    def_bool $(shields_list_contains,my_keyboard_right)

config SHIELD_MY_KEYBOARD_DONGLE
    def_bool $(shields_list_contains,my_keyboard_dongle)
```

`def_bool` + `shields_list_contains` is the Zephyr idiom for "this symbol is true when the user requests this shield in `-DSHIELD=...`." Don't try to invent something else.

## Kconfig.defconfig

This is where most of the dongle's split-protocol setup lives. The pattern: each shield gets its own `if SHIELD_<NAME> ... endif` block, then a "common" block for things both halves and the dongle want.

```
if SHIELD_MY_KEYBOARD_LEFT

config ZMK_KEYBOARD_NAME
    default "MY KEYBOARD"

config ZMK_SPLIT_ROLE_CENTRAL
    default y           # ← STILL DEFAULTS y. We override this via cmake-args in build.yaml.

endif

if SHIELD_MY_KEYBOARD_DONGLE

config ZMK_KEYBOARD_NAME
    default "MY KEYBOARD"

config ZMK_SPLIT_ROLE_CENTRAL
    default y

config ZMK_SPLIT
    default y

config ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS
    default 1           # adjust for your number of peripheral halves

config BT_MAX_CONN
    default 6

config BT_MAX_PAIRED
    default 6

endif

if SHIELD_MY_KEYBOARD_LEFT || SHIELD_MY_KEYBOARD_RIGHT || SHIELD_MY_KEYBOARD_DONGLE

config ZMK_SPLIT
    default y

endif
```

### Pick `ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS` correctly

This is "number of peripherals this central will connect to" — NOT "number of keyboard halves total." A normal split keyboard with a dongle has:

- 1 central = the dongle
- 2 peripherals = left half + right half (both demoted to peripheral)

So `default 2`, not `default 1`. The ZMK official docs example uses `default 1` because their example pretends there's only one peripheral; in practice nearly every dongle setup is `default 2`. Symptoms of getting it wrong (set to 1 when you have 2 halves):

- The first half (whichever pairs first) connects fine — battery slot 0 lights up on the LCD.
- The other half advertises forever, dongle ignores it. Permanent red X on slot 1.
- No error message anywhere — the dongle simply hits its configured peripheral cap.

Tune N to match your wireless half count. 3-piece keyboard (left + right + macro pad)? N=3. The cost of overshooting is small (a few KB of settings storage); the cost of undershooting is permanent disconnection of the excess halves.

### Why `BT_MAX_CONN` and `BT_MAX_PAIRED` at 6, not 1+peripherals?

- `BT_MAX_CONN` = max simultaneous BLE connections. Includes the *host* (the PC the dongle is plugged into for BLE profile, if you support that — usually not needed since you're already on USB) AND each peripheral.
- `BT_MAX_PAIRED` = max stored pairings. Must be ≥ `BT_MAX_CONN`.
- ZMK's BLE profile system stores 5 profile slots by default. Even though a Prospector usually doesn't use those (USB-only), the symbol counts. **Just set both to 6.** The cost is a couple of KB of settings storage.

You'll see a build error like `BT_MAX_CONN must be ≥ ...` if you set them too low. The error message tells you the floor; pick something at least that high.

### Why not `default n` for the left half?

Because the left half is **the same firmware** the keyboard ships with as a non-dongle build. Editing `Kconfig.defconfig` to flip the default would break the regular split-without-dongle build. Instead, the dongle build's `build.yaml` row passes `-DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n` as a `cmake-args` override, which wins over the defconfig default for that one matrix entry only.

## The overlay (`<keyboard>_dongle.overlay`)

The minimum-viable dongle overlay:

```dts
#include <dt-bindings/zmk/matrix_transform.h>

/ {
    chosen {
        zmk,kscan = &mock_kscan;
    };

    mock_kscan: mock_kscan_0 {
        compatible = "zmk,kscan-mock";
        columns = <0>;
        rows = <0>;
        events = <0>;
    };
};
```

This compiles and produces a working "headless central," but it's missing two things that matter for Prospector and for combos:

1. **No matrix transform** → combos with `key-positions` will reference positions the central doesn't know exist. Combos run on the central; they'll silently fail to fire even if both halves report the right keys.
2. **No physical layout** → ZMK Studio's "visual" view of the keyboard is broken (it can't render the keys without a physical layout).

The full overlay copies the keyboard's existing transform + layout in:

```dts
#include <dt-bindings/zmk/matrix_transform.h>
#include "my_keyboard-layouts.dtsi"     // brings in &physical_layout0

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
        columns = <10>;
        rows = <4>;
        map = <
                RC(0,0) RC(0,1) RC(0,2) RC(0,3) RC(0,4)    RC(0,5) RC(0,6) RC(0,7) RC(0,8) RC(0,9)
                RC(1,0) RC(1,1) RC(1,2) RC(1,3) RC(1,4)    RC(1,5) RC(1,6) RC(1,7) RC(1,8) RC(1,9)
        RC(3,0) RC(2,0) RC(2,1) RC(2,2) RC(2,3) RC(2,4)    RC(2,5) RC(2,6) RC(2,7) RC(2,8) RC(2,9) RC(3,9)
                                RC(3,2) RC(3,3) RC(3,4)    RC(3,5) RC(3,6) RC(3,7)
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

### Matrix-transform copy gotchas

- **Copy verbatim** from the existing `keyboard.dtsi` (or wherever `default_transform: keymap_transform_0` is defined). Position indices ARE the contract between central and peripheral; mismatch = misrouted keys.
- **Keep the label `default_transform`** so the `&physical_layout0 { transform = <&default_transform>; };` line resolves correctly.
- **Do NOT also `#include "keyboard.dtsi"`** in the dongle overlay — that file usually also pulls in `kscan` (the GPIO matrix), which conflicts with `mock_kscan`. Re-declare just what you need.

### Why `mock_kscan` and not no kscan at all?

`zmk,kscan` is a required `chosen` property; without it the build fails. `zmk,kscan-mock` is a no-op driver that satisfies the requirement and reports zero key events. Don't try to use `zmk,kscan-gpio-matrix` with all-empty GPIO arrays — it'll throw a devicetree validation error.

## Where the keymap lives for a dongle build

Two patterns are common; either works:

### Pattern A: shared top-level keymap

The active `config/<keyboard>.keymap` is used by all three shields (left, right, dongle). The shield's overlay doesn't include a keymap; ZMK's build picks up `config/<shield>.keymap` if it exists, otherwise `config/<keyboard>.keymap`.

This is the simplest pattern and what most repos use. Edit one keymap; all three firmwares update on the next build.

### Pattern B: dongle-specific keymap that includes the top-level

```dts
// config/my_keyboard_dongle.keymap
#include "my_keyboard.keymap"

// optionally override specific layers or add dongle-only behaviors here
```

Useful if you want the dongle to expose extra layers (e.g., a Bluetooth profile management layer accessible via combos detected on the dongle) without cluttering the regular keyboard keymap.

## Multi-peripheral configs (>2 halves)

For three-piece keyboards (e.g., left + right + macro pad) or any setup with N>1 peripherals, change:

```
config ZMK_SPLIT_BLE_CENTRAL_PERIPHERALS
    default N      # 2 for left+right+macro, 3 for left+right+macro+thumb, etc.
```

And bump `BT_MAX_CONN` / `BT_MAX_PAIRED` accordingly:

```
config BT_MAX_CONN
    default $((N + 5))    # peripherals + 5 profile slots, then round up
```

(Kconfig doesn't actually support arithmetic; just pick a value. Most configs use 6 or 8.)

## Latency math

The dongle replaces the BLE-from-peripheral-to-central + USB-from-central-to-host path with BLE-from-peripheral-to-dongle + USB-from-dongle-to-host. The former central (now peripheral) sees one extra BLE hop instead of direct USB — about **1ms** extra latency. The other peripherals see **~6.5ms** average improvement (the dongle's BLE stack has less competing work than a half doing matrix scan + sleep + status reporting).

Net effect on a 2-half split: roughly break-even for the previously-central half, big win for the previously-peripheral half. For a 3-piece, both former-peripheral halves win and the former central loses ~1ms. Most users don't notice either direction; the practical wins are battery life and visual status, not latency.

## What `settings_reset` actually does

`settings_reset` is a Zephyr-provided "shield" (it's actually a snippet/shield combo depending on board) that boots with code that wipes the Zephyr settings partition. It runs once, erases all stored pairings, then halts (or reboots into bootloader-friendly state depending on the board).

In a Prospector flow you build `settings_reset` for `seeeduino_xiao_ble` once and flash it to every board you need to wipe (dongle + each half). It's the same UF2 for all three.

If `settings_reset` isn't a known shield in your build (some older configs miss it), add it as a top-level row in `build.yaml`:

```yaml
- board: seeeduino_xiao_ble
  shield: settings_reset
  artifact-name: settings_reset
```

ZMK ships `settings_reset` as part of `app/` — you don't need any extra module for it.

## Common build errors specific to the dongle pattern

| Error | Cause | Fix |
|---|---|---|
| `'mock_kscan' undeclared` (referenced by chosen) | Forgot the `mock_kscan: mock_kscan_0 { ... };` node | Add the node literally as shown above. |
| `prop 'compatible' has value 'zmk,kscan_mock'` | Typo — underscore instead of hyphen | Use `"zmk,kscan-mock"` (hyphen). |
| `BT_MAX_CONN ... not in range` | Set too low (e.g., 2 when ZMK profiles need 5) | Set to 6. |
| Studio doesn't work after dongling | `snippet: studio-rpc-usb-uart` still on left, not on dongle | Move the snippet to the dongle's build row. |
| Combos that worked pre-dongle stop firing | Forgot to copy the matrix transform into the dongle overlay | Copy it verbatim from `keyboard.dtsi`. |
| Layer indicator shows numbers | Forgot `display-name = "..."` on each layer | Add to every layer in the keymap. |
| `Board qualifiers /nrf52840/zmk for board xiao_ble not found` (ZMK main / Zephyr 4.1) | Used `xiao_ble//zmk` shorthand that Zephyr 4.1 board loader rejects locally | Use the full form `xiao_ble/nrf52840/zmk`. See `references/prospector-module.md`. |
| `undefined node label 'st7789'` | The `zmk` board variant didn't resolve, so `prospector_adapter`'s `boards/xiao_ble_zmk.overlay` (which defines the display) was never applied | Add `-DBOARD_ROOT=<repo>/zmk/app` to the cmake args of your local build, so Zephyr can find ZMK's `zmk` variant extension. |
| `peripheral half still acts as central` (two centrals fighting) | Local build wrapper didn't forward `cmake-args` from build.yaml to cmake | Verify by checking `.build/<artifact>/zephyr/.config` — `CONFIG_ZMK_SPLIT_ROLE_CENTRAL` should be unset for the peripheral. If not, fix the wrapper. The Justfile in this repo handles this via the `_parse_targets` cmake-args extraction. |
| Build succeeds but peripheral never advertises, dongle LCD shows perpetual disconnected X, peripheral `.uf2` is ~100KB (vs ~400KB expected) | Peripheral built with `board: xiao_ble` instead of `xiao_ble/nrf52840/zmk` → `CONFIG_ZMK_BLE` silently not set in that build → no BLE stack to advertise with | Change every `board:` row in `build.yaml` that needs ZMK features to the `/zmk` variant target. See `references/prospector-module.md` "Peripheral halves also need the `/zmk` variant". |
