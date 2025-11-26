# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a ZMK firmware configuration repository for the TOTEM wireless split mechanical keyboard. The keyboard uses Seeeduino XIAO BLE microcontrollers and supports both wired (USB-C) and wireless (Bluetooth) operation.

## Build System

Firmware builds are automated via GitHub Actions. Pushing changes triggers a build workflow that:
1. Uses the ZMK build system (`zmkfirmware/zmk/.github/workflows/build-user-config.yml@main`)
2. Generates `.uf2` firmware files for both keyboard halves
3. Makes artifacts available in the Actions tab

The build matrix is defined in `build.yaml` and specifies:
- Board: `seeeduino_xiao_ble`
- Shields: `totem_left` and `totem_right`
- Snippet: `studio-rpc-usb-uart` (enables ZMK Studio support)

## Keymap Files

There are TWO keymap files in this repository:

1. **`config/totem.keymap`** - The active keymap file that defines the actual keyboard behavior
   - This is the primary file to edit for layout changes
   - Includes custom homerow mods with balanced flavor hold-tap behaviors
   - Defines 4 layers: base (0), nav_num (1), sym_func (2), device (3)
   - Uses conditional layers to activate device layer when both nav_num and sym_func are active

2. **`config/boards/shields/totem/totem.keymap`** - Shield definition reference keymap
   - Contains an older Colemak-DH layout with different behavior configurations
   - Uses standard `&mt` (mod-tap) behaviors
   - Defines 4 layers: BASE, NAVI, SYM, ADJ
   - This file exists for shield compatibility but is NOT the active keymap

When making keymap changes, edit `config/totem.keymap` unless explicitly working on shield definitions.

## Keymap Architecture

The active keymap (`config/totem.keymap`) uses:
- **Custom hold-tap behaviors**: `hml` (homerow_mod_left) and `hmr` (homerow_mod_right) with:
  - `flavor = "balanced"`: Provides natural typing flow
  - `tapping-term-ms = 280`: Hold activation threshold
  - `quick-tap-ms = 175`: Rapid repeat threshold
  - `require-prior-idle-ms = 150`: Prevents accidental mods during fast typing
- **Layer structure**:
  - Layer 0 (base): QWERTY layout with homerow mods (GUI/ALT/CTRL/SHIFT on home row)
  - Layer 1 (nav_num): Navigation keys and numbers
  - Layer 2 (sym_func): Symbols and function keys
  - Layer 3 (device): Bluetooth controls, media keys, brightness
- **Conditional layers**: Device layer activates automatically when both nav_num and sym_func are held

## Configuration

`config/totem.conf` enables:
- `CONFIG_ZMK_STUDIO=y`: Enables ZMK Studio for live keymap editing via web UI
- `CONFIG_ZMK_STUDIO_LOCKING=n`: Allows unrestricted editing

## Shield Definition Structure

The shield is defined across multiple files in `config/boards/shields/totem/`:
- `totem.dtsi`: Core hardware definitions
- `totem_left.overlay` / `totem_right.overlay`: Half-specific configurations
- `totem-layouts.dtsi`: Physical layout mappings
- `Kconfig.shield` / `Kconfig.defconfig`: Build system integration
- `totem.zmk.yml`: ZMK metadata

## Development Workflow

1. **Local edits**: Modify `config/totem.keymap` for layout changes
2. **Test via ZMK Studio**: Use https://zmk.studio for live testing without flashing
3. **Commit and push**: Triggers GitHub Actions build
4. **Download firmware**: Get `.uf2` files from Actions tab
5. **Flash**: Double-press reset button, drag `.uf2` to USB drive

For most changes, flashing only the left half is sufficient. Flash both halves if changes don't take effect.

## West Manifest

`config/west.yml` pulls the main ZMK firmware from `zmkfirmware/zmk@main`. Update the revision to pin to specific ZMK versions if needed.
