# zmk-helpers Macro Reference

`zmk-helpers` is urob's macro library for writing ZMK keymaps with less devicetree boilerplate. It's a ZMK module — added to `config/west.yml` and `#include`d at the top of the keymap.

The macros expand to standard devicetree nodes; they're not magic. Reading the expanded output (the actual `.dts.pre.tmp` from a build) is sometimes useful when debugging.

## Setting up

```yaml
# config/west.yml
manifest:
  remotes:
    - name: zmkfirmware
      url-base: https://github.com/zmkfirmware
    - name: urob
      url-base: https://github.com/urob
  projects:
    - name: zmk
      remote: zmkfirmware
      revision: main
      import: app/west.yml
    - name: zmk-helpers
      remote: urob
      revision: main
      path: modules/zmk/helpers
  self:
    path: config
```

```dts
// In your keymap:
#include "zmk-helpers/helper.h"
#include "zmk-helpers/key-labels/<board>.h"     // e.g. totem.h, sweep.h, glove80.h
```

Available board key-label headers (as of 2026-05): `34.h`, `36.h`, `42.h`, `corneish_zen.h`, `cradio.h`, `glove80.h`, `kyria.h`, `planck.h`, `sweep.h`, `totem.h`, and many more in `zmk-helpers/include/zmk-helpers/key-labels/`.

If your board isn't in the list, define position aliases locally in a `*_defs.dtsi` file (see the project's `totem_defs.dtsi` for an example).

---

## Behavior macros

### `ZMK_BEHAVIOR(name, compat, ...)`

Generic wrapper for any behavior node. Rarely needed directly; use the specific macros below.

```dts
ZMK_BEHAVIOR(my_thing, behavior-foo,
    bindings = <&kp>, <&kp>;
    some-property = <42>;
)
// Expands to:
// my_thing: my_thing {
//     compatible = "zmk,behavior-foo";
//     #binding-cells = <0>;
//     bindings = <&kp>, <&kp>;
//     some-property = <42>;
// };
```

### `ZMK_HOLD_TAP(name, ...)`

Custom hold-tap. Sets `compatible = "zmk,behavior-hold-tap"` and `#binding-cells = <2>` automatically.

```dts
ZMK_HOLD_TAP(hml,
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    bindings = <&kp>, <&kp>;
    hold-trigger-key-positions = <KEYS_R THUMBS>;
    hold-trigger-on-release;
)

// Use: &hml LGUI A
```

### `ZMK_MOD_MORPH(name, ...)`

Mod-morph. Sets `compatible = "zmk,behavior-mod-morph"` and `#binding-cells = <0>` automatically.

```dts
ZMK_MOD_MORPH(bs_del,
    bindings = <&kp BSPC>, <&kp DEL>;
    mods = <(MOD_LSFT|MOD_RSFT)>;
    keep-mods = <MOD_RSFT>;          // optional
)

// Use: &bs_del
```

### `ZMK_TAP_DANCE(name, ...)`

Tap-dance: action varies by tap count.

```dts
ZMK_TAP_DANCE(copy_cut,
    bindings = <&kp LC(INS)>, <&kp LC(X)>;     // single tap, double tap
    tapping-term-ms = <200>;
)

// Use: &copy_cut
```

### `ZMK_MACRO(name, ...)` / `ZMK_MACRO_ONE_PARAM(name, ...)` / `ZMK_MACRO_TWO_PARAM(name, ...)`

Macros with 0/1/2 parameter cells.

```dts
ZMK_MACRO(dot_spc,
    wait-ms = <0>;
    tap-ms = <5>;
    bindings = <&kp DOT &kp SPACE &sk LSHFT>;
)

// Use: &dot_spc
```

For parameterised macros, use the `&macro_param_*` control verbs:

```dts
ZMK_MACRO_ONE_PARAM(parametric,
    bindings
        = <&macro_param_1to1 &macro_press &kp MACRO_PLACEHOLDER>
        , <&macro_pause_for_release>
        , <&macro_param_1to1 &macro_release &kp MACRO_PLACEHOLDER>
        ;
)
```

### `ZMK_KEY_REPEAT(name, ...)`

Variant of `&key_repeat` with custom usage-pages.

```dts
ZMK_KEY_REPEAT(repeat, usage-pages = <HID_USAGE_KEY HID_USAGE_CONSUMER>;)

// Use: &repeat
```

Requires `#include <dt-bindings/zmk/hid_usage_pages.h>`.

---

## Layer & combo macros

### `ZMK_LAYER(name, bindings)`

Define a single layer.

```dts
ZMK_LAYER(Base,
    &kp Q  &kp W  &kp E  &kp R  &kp T   /* etc. */
)
// Expands to a child node of `keymap` with display-name = "Base" and the bindings.
```

### `ZMK_BASE_LAYER(name, LT, RT, LM, RM, LB, RB, LH, RH)`

Multi-board polymorphic base layer. Each board provides its own definition of this macro that pads the eight zone arguments around the board-specific extra keys, then `#include "base.keymap"`.

Default (no padding, for 34-key sweep/cradio):

```dts
#define ZMK_BASE_LAYER(name, LT, RT, LM, RM, LB, RB, LH, RH) \
    ZMK_LAYER(name, LT RT LM RM LB RB LH RH)
```

For a 42-key board you'd override before `#include`-ing `base.keymap`:

```dts
#define ZMK_BASE_LAYER(name, LT, RT, LM, RM, LB, RB, LH, RH)  \
    ZMK_LAYER(name,                                            \
        &none LT &none      &none RT &none                     \
        &none LM &none      &none RM &none                     \
        &none LB &none      &none RB &none                     \
                 LH                  RH                        \
    )
```

(Exact padding depends on the board's matrix transform.)

### `ZMK_COMBO(name, bindings, key-positions, layers, [timeout-ms, [require-prior-idle-ms]])`

Standard combo. The 4-arg, 5-arg, and 6-arg forms all work depending on how specific you want to be.

```dts
ZMK_COMBO(esc, &kp ESC, LT3 LT2, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST)
//        name binding  key-pos  layers       timeout         prior-idle
```

If you omit `timeout-ms` it defaults to ZMK's combo default; same for `require-prior-idle-ms`. Always passing both explicitly is clearer.

### `ZMK_COMBO_8(...)` — NOT IN zmk-helpers BY DEFAULT

This is urob's hack to make combos overlap with HRMs cleanly. It's defined inline in the project's keymap or a local `*_defs.dtsi`:

```dts
// In totem_defs.dtsi or similar:
#define ZMK_COMBO_8(NAME, TAP, POS, LAYERS, COMBO_MS, IDLE_MS, HOLD, SIDE)     \
  MAKE_HRM(hm_combo_##NAME, &kp, TAP, SIDE THUMBS)                             \
  ZMK_COMBO_6(NAME, &hm_combo_##NAME HOLD 0, POS, LAYERS, COMBO_MS, IDLE_MS)
```

This bootstraps a new HRM (`hm_combo_NAME`) wrapping the tap action, then defines the combo on top of it. The 7th arg (`HOLD`) is the mod that fires on hold; the 8th (`SIDE`) is the opposite-hand positions for the positional gating. You invoke it as a 7+1 arg `ZMK_COMBO` call:

```dts
ZMK_COMBO(lpar, &lpar_lt, RM1 RM2, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST, RS(LCTRL), KEYS_L)
//                                                                                  ^HOLD     ^SIDE
```

See `urob-patterns.md` for the rationale (workaround for ZMK issue #544).

### `ZMK_CONDITIONAL_LAYER(name, if-layers, then-layer)`

Tri-layer.

```dts
ZMK_CONDITIONAL_LAYER(sys, FN NUM, SYS)    // FN + NUM both active → SYS
```

Expands to a child node of `conditional_layers` with the appropriate `if-layers` and `then-layer` properties.

---

## Common factory patterns

### `MAKE_HRM` — HRM factory

```dts
#define MAKE_HRM(NAME, HOLD, TAP, TRIGGER_POS)                                 \
  ZMK_HOLD_TAP(NAME, bindings = <HOLD>, <TAP>; flavor = "balanced";            \
               tapping-term-ms = <280>; quick-tap-ms = <QUICK_TAP_MS>;         \
               require-prior-idle-ms = <150>; hold-trigger-on-release;         \
               hold-trigger-key-positions = <TRIGGER_POS>;)

MAKE_HRM(hml, &kp, &kp, KEYS_R THUMBS)
MAKE_HRM(hmr, &kp, &kp, KEYS_L THUMBS)
```

You're not limited to `&kp` for the hold action. Want an HRM whose hold sends a sticky-mod instead? `MAKE_HRM(hml_sk, &sk, &kp, KEYS_R THUMBS)`.

### `SIMPLE_MORPH` — single-mod shift-style morph

```dts
#define SIMPLE_MORPH(NAME, MOD, BINDING1, BINDING2)                            \
  ZMK_MOD_MORPH(NAME, mods = <(MOD_L##MOD | MOD_R##MOD)>;                      \
                bindings = <BINDING1>, <BINDING2>;)

SIMPLE_MORPH(qexcl, SFT, &kp QMARK, &kp EXCL)
```

The `MOD_L##MOD` token pasting expands to `MOD_LSFT` when `MOD = SFT`. Available short suffixes: `SFT`, `CTL`, `ALT`, `GUI`.

### `MASK_MODS` — modifier-eating mod-morph

```dts
#define MASK_MODS(NAME, MODS, BINDING)                                         \
  ZMK_MOD_MORPH(NAME, bindings = <BINDING>, <BINDING>; mods = <MODS>;)

MASK_MODS(masked_home, (MOD_LCTL), &kp HOME)
```

Both bindings identical, but the `mods` property silently consumes the matched modifier. Use to suppress `Ctrl+Home` (doc-start) when the user is intentionally just pressing Home.

---

## When to use raw devicetree instead

- **Repo doesn't already use zmk-helpers.** Adding it changes the build dependency (modifies `west.yml`). Don't introduce silently.
- **You're learning ZMK and want to see the underlying structure.** The macros hide `compatible` and `#binding-cells`; reading the raw form first builds the mental model.
- **You need a property the macro doesn't expose.** This is rare — macros pass through extra properties.
- **You're working in `boards/shields/`** — shield definitions typically use raw devicetree, since they're upstream-style code.

For a normal keymap edit in a repo that already uses `helper.h`, use the macros.

---

## Gotchas

1. **Macros are preprocessor-time, not runtime.** `MAKE_HRM(hml, &sk, &kp, ...)` produces a behavior named literally `hml`. Two calls with the same name conflict.

2. **Token pasting with `##` requires the operand to be a bare token.** `MOD_L##SFT` works; `MOD_L##(SFT)` doesn't.

3. **Helper macros set `#binding-cells` for you.** Don't include `#binding-cells = <X>;` in the macro body — you'll get a redefinition error.

4. **`ZMK_COMBO_8` is project-local, not part of zmk-helpers.** Copy it into your `*_defs.dtsi`; don't expect it from the upstream library.

5. **The position-label headers depend on the exact board.** A 34-key sweep header is different from a 36-key Corne header is different from a 38-key Totem header. Use the right one.

6. **Macros expand without preprocessor guards.** If you include `helper.h` twice (e.g. once in `base.keymap`, once in a board adapter), you'll get redefinition warnings. The helper itself is guarded; your project-local macros must be too.
