# ZMK Build Troubleshooting

When a GitHub Actions build fails, the actionable info is buried in the job log. Knowing what to look for makes the difference between a 10-second fix and a half-hour goose chase.

## How to read a CI build log

1. Open the failing run on GitHub: Actions tab → click the run → click the failing job (`Build (totem_left)` or similar) → expand the "Build" step.
2. The Zephyr/west build output is verbose. The error you care about is usually 20–80 lines from the BOTTOM. Look for:
   - `devicetree error:` — devicetree compile error
   - `Error: ` (capital E, Zephyr style)
   - `error:` (lowercase) — gcc preprocessing or compile error
   - `FATAL ERROR: ` — west itself failed (rare; usually means a manifest issue)
3. File:line references in the error point to `<something>.dts.pre.tmp` — the PREPROCESSED devicetree (with includes inlined). Line numbers won't match your source 1:1. Search the source by the offending token instead.

The first error is the one that matters; later errors are often cascade effects of the first. Fix and rebuild.

---

## Catalog of common errors

### "Reference to non-existent node or label"

```
error: keymap.dts.pre.tmp:127.30-127.35:
       Reference to non-existent node or label "hml"
```

**Cause**: a binding uses `&hml` but no `hml: ...` node is defined (or it's defined AFTER its use — devicetree allows forward references, but only within the same file unit).

**Fixes**:
- Check spelling. `&hmll` vs `&hml`.
- Ensure the file defining `hml` is `#include`d BEFORE the file using it.
- Ensure `behaviors { hml: ... }` is correctly nested under `/`.

### "Value not in enumeration"

```
error: 'flavour' is not in the enumeration: ('tap-preferred', 'hold-preferred',
       'balanced', 'tap-unless-interrupted')
```

**Cause**: typo or invalid value for a property with a fixed allowed set.

Most common culprits:
- `flavour` (British) instead of `flavor`. ZMK uses American spelling.
- `release-after-ms = "1000ms"` instead of `release-after-ms = <1000>` — value should be an int in angle brackets.
- `compatible = "zmk,hold-tap"` instead of `compatible = "zmk,behavior-hold-tap"`.

### "Property has invalid type" / "expected integer"

**Cause**: wrong syntax for the value. Devicetree integer literals are angle-bracketed: `<200>`. Strings are quoted: `"balanced"`. Lists are space-separated inside the brackets: `<1 2 3>`.

```dts
tapping-term-ms = <200>;       // OK
tapping-term-ms = 200;          // wrong — int needs angle brackets
flavor = "balanced";            // OK
flavor = balanced;              // wrong — string needs quotes
```

### "cells in 'bindings' must be a multiple of N"

```
error: Number of cells in 'bindings' (47) is not a multiple of N (?)
```

**Cause**: wrong number of key bindings in a layer. Each binding cell count depends on the behavior; for a uniform `&kp X` layer the cell count is `2 * keys` (one for behavior reference, one for keycode). Layer with the wrong total fails this check.

Most common cause: copy-paste error left a layer with the wrong number of keys, OR a binding got dropped.

**Fix**: count `&` references in the layer; should equal the number of keys in the matrix transform.

### "Behavior cannot have N params"

```
error: Behavior cannot have 2 params
```

**Cause**: passed a multi-param behavior somewhere expecting a single-param one. Most common spot: `bindings = <&bt>, <&kp>;` in a hold-tap definition (since `&bt BT_SEL 0` is two-arg).

**Fix**: wrap the multi-param behavior in a zero-param macro:

```dts
ZMK_MACRO(bt_sel_0, bindings = <&bt BT_SEL 0>;)
// Then use &bt_sel_0 in the hold-tap's bindings.
```

### "'<KEYCODE>' undeclared (first use in this function)"

```
keymap.dts.pre.tmp:127:30: error: 'BSPCE' undeclared (first use in this function)
```

**Cause**: typo in a keycode constant. The preprocessor doesn't know what `BSPCE` is, so it leaves it as a literal identifier that the next step rejects.

**Fix**: check the spelling against `references/keycodes.md`. Common typos: `BCKSP` should be `BSPC`, `SCLN` should be `SEMI`, `MINS` should be `MINUS`.

Also possible: missing `#include <dt-bindings/zmk/keys.h>` (you'd see ALL keycodes undeclared, not just one).

### "'BT_SEL' undeclared" or "'OUT_USB' undeclared"

**Cause**: missing the relevant header.

**Fix**:
```dts
#include <dt-bindings/zmk/bt.h>          // for BT_SEL, BT_CLR, etc.
#include <dt-bindings/zmk/outputs.h>     // for OUT_USB, OUT_BLE, etc.
#include <dt-bindings/zmk/rgb.h>         // for RGB_TOG, etc.
#include <dt-bindings/zmk/ext_power.h>   // for EP_TOG, etc.
#include <dt-bindings/zmk/pointing.h>    // for MOVE_UP, SCRL_UP, etc.
#include <dt-bindings/zmk/hid_usage_pages.h>   // for HID_USAGE_KEY, HID_USAGE_CONSUMER
```

### "Conditional layer ... could not be found"

```
devicetree error: condition tri_layer: then-layer 2 is lower than if-layers <2 3>
```

**Cause**: `then-layer` index is not strictly greater than all `if-layers` indices.

**Fix**: renumber layers so the conditional target has the highest index. E.g. if you want `NUM + FN → SYS`, put SYS at the highest layer index.

### "inclusion is duplicated" / redefinition errors

```
error: 'hml' is redefined
```

**Cause**: a `.dtsi` file is included twice, defining the same nodes twice.

**Fix**: wrap headers with include guards:

```dts
#ifndef MY_DEFS_DTSI
#define MY_DEFS_DTSI

/* ... contents ... */

#endif // MY_DEFS_DTSI
```

`zmk-helpers/helper.h` is already guarded; only your project-local files need this.

### "Could not find 'zmk,studio-rpc-uart'" or similar Studio errors

**Cause**: `CONFIG_ZMK_STUDIO=y` is set but the build doesn't have the `studio-rpc-usb-uart` snippet.

**Fix**: in `build.yaml`, add the snippet to each shield row:

```yaml
include:
  - board: xiao_ble
    shield: totem_left
    snippet: studio-rpc-usb-uart
```

Both halves need it. Or, set the snippet at the top level if you have a `shield:` array.

### "Unknown shield 'foo_left'"

**Cause**: the shield name in `build.yaml` doesn't match the shield's `Kconfig.shield` `config SHIELD_FOO_LEFT` entry.

**Fix**: check `boards/shields/foo/Kconfig.shield` for the canonical names. Capitalisation in `build.yaml` is lowercase: `shield: foo_left` matches `config SHIELD_FOO_LEFT`.

### "central side does not include shield foo" or split mismatches

**Cause**: only one half of a split build matrix is configured, or the central/peripheral roles are crossed.

**Fix**: ensure `build.yaml` has BOTH `foo_left` AND `foo_right` entries. Check `boards/shields/foo/Kconfig.defconfig` for which side is `CONFIG_ZMK_SPLIT_ROLE_CENTRAL` (usually the left).

### "no rule to make target..." (Zephyr's make output)

**Cause**: a referenced source file doesn't exist. Almost always: a typo in a file path in `Kconfig.shield` or in a `CMakeLists.txt`.

**Fix**: check the listed paths exist. Capitalisation matters on Linux CI even if it doesn't on macOS.

### Warnings that aren't errors but should be fixed

- `Property 'X' has no minimum length specified` — non-fatal but indicates a property is missing/empty. Usually means a `bindings` block is empty when it shouldn't be.
- `Node '...' is unused; could be deleted` — informational. You defined a behavior but never referenced it.

---

## Pattern: I changed nothing and now it doesn't build

Almost always: upstream ZMK or a module's `main` branch has a breaking change.

**Fix options:**
1. Pin to a known-good revision in `config/west.yml`:
   ```yaml
   - name: zmk
     remote: zmkfirmware
     revision: 0331b7d16e80954b807917f9323e59ffc1e3b626  # main, 2026-04-19
     import: app/west.yml
   ```
2. Check `zmkfirmware/zmk` recent commits and `Discussions` tab for breaking-change announcements.
3. If a community module (e.g. `zmk-helpers`) is at `revision: main`, it might have updated to match a ZMK API change. Pin it too.

## Pattern: build succeeds but the keyboard doesn't behave right

Compilation success only checks syntax. Semantic errors:

- **`hold-trigger-key-positions` references wrong positions**. Re-check against the position-label header for your board.
- **Layer index used as keycode** (or vice versa). `&mo NAV` works if `#define NAV 1`; `&kp NAV` does NOT — NAV is an integer, not a keycode.
- **`bindings = <&kp NUM_1>` where you want NUM_1 the keycode but NUM is a layer alias**. Use `&kp N1` instead.
- **Combo positions span the wrong keys**. Some keymaps' `key-positions` is in a different order than expected for split keyboards. Test combos one at a time.
- **`require-prior-idle-ms` makes the HRM feel sluggish**. Tune down.
- **Two HRMs on the same hand don't chord**. You forgot `hold-trigger-on-release`.

## Quick sanity checks

When something feels off, check these in order:

1. The keymap actually got flashed. Did the GitHub Action's build artifact actually copy onto the keyboard? (`.uf2` file size in the bootloader vs. file size in Actions.)
2. The central half (usually the left) was flashed. Many changes need only the central side reflashed.
3. The keymap reference in `&behavior` actually points to the right thing. Greps: `grep -n 'hml:' config/*` (should find one definition).
4. Layer indices match between `&mo N` calls and the layer ordering in `keymap { ... }`.
5. Position indices in HRM `hold-trigger-key-positions` are the right keys (use the position-label header).

## When all else fails

- Look at the `build_info.yml` in the build artifact — it lists the exact ZMK + module revisions used. If you can reproduce locally with `west build` against those revisions, you can iterate faster.
- The `#zmk` Discord and the `zmkfirmware/zmk` GitHub Discussions are the canonical help channels. Search before posting.
- Compare against urob's config or other community configs for the same board on `github.com/zmkfirmware/zmk-config-list`.
