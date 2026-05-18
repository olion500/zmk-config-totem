---
name: zmk-expert
description: Expert assistance for ZMK firmware keyboard configuration. Use whenever the user asks about editing a ZMK keymap, adding or modifying behaviors (hold-tap, mod-tap, layer-tap, mod-morph, sticky-key, sticky-layer, caps-word, key-repeat), defining combos, configuring layers, troubleshooting devicetree parse errors, debugging ZMK GitHub Actions build failures, working with zmk-helpers macros (ZMK_HOLD_TAP, ZMK_COMBO, ZMK_MOD_MORPH, ZMK_TAP_DANCE, ZMK_BEHAVIOR, ZMK_MACRO, ZMK_CONDITIONAL_LAYER), explaining ZMK concepts like homerow mods, positional hold-tap, or "balanced" vs "tap-preferred" flavor, or any work on .keymap, .conf, .dtsi, or .overlay files in a ZMK config repo. ALSO trigger for related topics: BLE/USB output selection, ZMK Studio, encoder/sensor bindings, west.yml configuration, .uf2 flashing, split-keyboard build issues, ZMK Kconfig flags. Use this skill even when the user doesn't mention "ZMK" by name — phrases like "my keyboard firmware", "the homerow mods are misfiring", "add this combo", "the build is failing on the keymap", or anything involving .keymap files in this repo all indicate ZMK work.
---

# ZMK Expert

You are an expert in ZMK firmware (https://zmk.dev) keyboard configuration. ZMK is the open-source firmware that runs on wireless mechanical keyboards built from boards like the Seeeduino XIAO BLE, nice!nano, and Proton-C. Configuration lives in a `zmk-config` repository as devicetree (`.keymap`, `.dtsi`, `.overlay`) + Kconfig (`.conf`) files; building is delegated to a GitHub Actions workflow.

This skill helps with two main workflows:

1. **Editing keymaps** — adding or modifying behaviors, combos, layers, mod-morphs, macros, homerow mods.
2. **Troubleshooting builds** — diagnosing devicetree parse errors, missing includes, wrong cell counts, and other GitHub Actions build failures.

## How to approach a ZMK request

Always start by **reading the user's actual keymap and helpers** before suggesting changes. Even a small request like "add a combo for Tab" depends on:

- Whether the repo uses `zmk-helpers` macros (`ZMK_HOLD_TAP`, `ZMK_COMBO`, etc.) or raw devicetree.
- The position-label scheme (`LT0`, `LM3`, ... defined in a `*_defs.dtsi` or in `zmk-helpers/key-labels/<board>.h`).
- The layer indices and `#define` aliases (e.g. `DEF`, `NAV`, `NUM`).
- Existing behaviors with overlapping concerns (don't duplicate an existing mod-morph).

Files to read first when invoked:

| File | Why |
|---|---|
| `config/*.keymap` | The active layout. Holds layers, behavior references, includes. |
| `config/*_defs.dtsi` (if present) | Position labels (`LT0`...`RH2`), layer aliases, custom helper macros, HRM factories. |
| `config/combos.dtsi` (if present) | Combo definitions, fast/slow timing constants. |
| `config/*.conf` | Kconfig — Studio, sleep, BLE TX power, debug logging, etc. |
| `config/west.yml` | Which ZMK revision + modules (zmk-helpers, zmk-leader-key, etc.). |
| `build.yaml` | Board/shield matrix for GitHub Actions. |

If the user has a `boards/shields/<name>/` directory, there is usually a SECOND `.keymap` in there that ships with the shield. **It is almost never the active keymap.** The active one is `config/<name>.keymap`. Check `CLAUDE.md` if present — it often calls this out.

---

## ZMK 5-minute fundamentals

A keymap file is a devicetree overlay. The top level looks like:

```dts
#include <behaviors.dtsi>
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/bt.h>

/ {
    behaviors    { /* custom hold-taps, mod-morphs, tap-dances */ };
    macros       { /* multi-step sequences */ };
    combos       { compatible = "zmk,combos"; /* combos */ };
    conditional_layers { compatible = "zmk,conditional-layers"; /* tri-layer rules */ };
    keymap {
        compatible = "zmk,keymap";
        base_layer { display-name = "Base"; bindings = < /* one binding per key */ >; };
        /* more layers */
    };
};
```

**Layer indices** are determined by declaration order: first layer is `0`, second `1`, etc. Most configs use `#define LAYER_NAME N` aliases (e.g. `#define DEF 0`, `#define NAV 1`) so reordering is safer.

**Position indices** start at 0 and follow the matrix transform — the same order keys appear in `bindings`. They're used by:
- `hold-trigger-key-positions` (positional hold-tap)
- `key-positions` (combos)

The shield's `boards/shields/<name>/*-layouts.dtsi` is what defines the canonical numbering. If the repo uses `zmk-helpers`, key labels like `LT0`, `LM3`, `RH1` will be defined either in `zmk-helpers/key-labels/<board>.h` or in a local `*_defs.dtsi` file.

**Built-in behaviors** (no need to define — included by `<behaviors.dtsi>`):

| Behavior | Syntax | Purpose |
|---|---|---|
| `&kp` | `&kp A` | Send a keycode while held. |
| `&mt` | `&mt LSHIFT A` | Modifier on hold, key on tap. **Not** a homerow mod out of the box. |
| `&lt` | `&lt 1 SPACE` | Layer on hold, key on tap. |
| `&mo` | `&mo 1` | Momentary layer (active while held). |
| `&to` | `&to 2` | Switch to layer (disable others). |
| `&tog` | `&tog 3` | Toggle layer on/off. |
| `&sl` | `&sl 1` | Sticky layer (latch until next key press). |
| `&sk` | `&sk LSHIFT` | Sticky key (one-shot modifier). |
| `&caps_word` | `&caps_word` | Auto-shift letters until a non-letter. |
| `&key_repeat` | `&key_repeat` | Resend last keycode. |
| `&trans` | `&trans` | Pass through to next-lower active layer. |
| `&none` | `&none` | Block — no output, no fall-through. |
| `&bt` | `&bt BT_SEL 0` | Select BT profile. Also `BT_NXT`, `BT_PRV`, `BT_CLR`, `BT_CLR_ALL`. |
| `&out` | `&out OUT_USB` | Force output USB / BLE / toggle. |
| `&sys_reset` / `&bootloader` | (no args) | Reboot to firmware / UF2 bootloader. |
| `&studio_unlock` | (no args) | Allow runtime edits via ZMK Studio. |

**`&trans` vs `&none`**: `&trans` means "look at the layer below"; `&none` means "this position does nothing on this layer." Use `&trans` to inherit; `&none` to deliberately deaden.

---

## Editing keymaps: the four main tasks

### 1. Adding or changing a key on a layer

Find the layer in `config/<name>.keymap`, locate the position you want by counting from 0 left-to-right top-to-bottom (or use the position-label header if the keymap uses one). Replace the binding.

```dts
base {
    bindings = <
        &kp Q  &kp W  &kp E  &kp R  &kp T   ...
        // position 0,    1,    2,    3,    4  ...
    >;
};
```

Keep alignment with whatever the file uses (most ZMK keymaps align columns with spaces — preserve this; it makes review readable).

For repeated identical bindings (like `&trans` on placeholder layers), this is fine — `&trans` everywhere on a layer means "this layer is reserved but currently a passthrough."

### 2. Adding a hold-tap (homerow mod, layer-tap, custom)

Hold-tap is ZMK's central abstraction for "different action on hold vs tap." It's parameterized by **flavor** (when to commit to the hold) and timing (`tapping-term-ms`, `quick-tap-ms`, `require-prior-idle-ms`).

#### Flavor cheat sheet

| Flavor | Hold fires when... | Good for |
|---|---|---|
| `hold-preferred` | next key is pressed, OR term expires | Hot-corner mods that you never roll into. **Default for `&mt`** — DO NOT use for homerow mods. |
| `tap-preferred` | term expires (other keys ignored) | Layer-tap on thumbs (default for `&lt`). Long-press alternates. |
| `balanced` | next key is pressed *and released* while held, OR term expires | **The homerow mod choice.** Rolling typing produces taps. |
| `tap-unless-interrupted` | (inverted) — only if interrupted before term | Niche. |

#### Properties you'll actually tune

- `tapping-term-ms` (default 200) — how long until the timer decides hold. HRMs use 280ms; nav-cluster long-press uses 220–250ms.
- `quick-tap-ms` (default 0) — within this many ms of the last tap of THIS hold-tap, the next press is forced to tap. Lets you tap-tap-and-hold for repeat. ZMK measures press-to-press; QMK measures release-to-press — port from QMK by using a larger value.
- `require-prior-idle-ms` (default 0) — if any non-modifier key was pressed within this many ms before this hold-tap pressed, force tap. The killer feature for "timeless" HRMs. Rule of thumb: `10500 / your_WPM`.
- `hold-trigger-key-positions = < ... >` — only THESE positions trigger the hold; pressing anything else within the term forces tap. For bilateral HRMs, list the OPPOSITE hand's positions + thumbs.
- `hold-trigger-on-release` — delay positional check until the interrupting key *releases*. Enables chording two same-hand mods (e.g. Ctrl+Shift+Tab).
- `retro-tap` — if the timer expired but no other key was pressed, fire tap on release. Incompatible with mouse behaviors.
- `hold-while-undecided` / `hold-while-undecided-linger` — send hold immediately (retract if it turns out tap) — for Shift-Click etc. where the host needs to see the mod down before the click.

#### The "timeless HRM" recipe (urob — battle-tested)

```dts
ZMK_HOLD_TAP(hml,                                    // left-hand HRM
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-on-release;
    hold-trigger-key-positions = <KEYS_R THUMBS>;    // only fires with opposite-hand or thumb
    bindings = <&kp>, <&kp>;                         // both branches are kp
)
ZMK_HOLD_TAP(hmr,                                    // right-hand HRM (mirrors)
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-on-release;
    hold-trigger-key-positions = <KEYS_L THUMBS>;
    bindings = <&kp>, <&kp>;
)
```

Then in the layer: `&hml LGUI A` (Left-GUI on hold, A on tap), `&hmr RSHFT J`, etc.

Why these numbers work — see `references/hold-tap.md` for the full rationale and tuning guide.

#### Raw devicetree equivalent (when not using zmk-helpers)

```dts
/ {
    behaviors {
        hml: home_row_mod_left {
            compatible = "zmk,behavior-hold-tap";
            #binding-cells = <2>;
            flavor = "balanced";
            tapping-term-ms = <280>;
            quick-tap-ms = <175>;
            require-prior-idle-ms = <150>;
            hold-trigger-on-release;
            hold-trigger-key-positions = <5 6 7 8 9 /* ... */>;
            bindings = <&kp>, <&kp>;
        };
    };
};
```

The `zmk-helpers` macro version is functionally identical but cuts the boilerplate. If the repo uses `#include "zmk-helpers/helper.h"`, prefer the macro form.

### 3. Adding a combo

```dts
// With zmk-helpers (preferred if available):
ZMK_COMBO(esc, &kp ESC, LT3 LT2, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST)
//        name,binding,positions,layers,      timeout-ms,     prior-idle-ms

// Raw devicetree:
combos {
    compatible = "zmk,combos";
    combo_esc {
        timeout-ms = <50>;
        key-positions = <1 2>;     // physical position indices
        bindings = <&kp ESC>;
        layers = <0 1 3>;          // optional; default: all layers
        require-prior-idle-ms = <125>;  // optional but recommended
    };
};
```

Combo design rules (from experience):

- **Timeout** 18–40ms for horizontal combos (typed quickly together), 30–50ms for vertical combos (less synchronizable).
- **`require-prior-idle-ms`** is your best defense against typo-triggered combos. Use 150ms for combos that overlap homerow positions.
- **Layer-conditional combos**: same physical positions, different bindings per layer (e.g. `( )` on Base, `< >` on Nav). Restrict via `layers = <NAV>;`.
- **`slow-release;`** keeps the combo binding pressed until *all* constituent keys release. Default is "release on first key up."
- **Split keyboards**: positions span both halves; position N corresponds to the same physical key as it does in the keymap bindings.

If a combo position overlaps a homerow mod, you'll need the **HRM-combo workaround** (urob's `ZMK_COMBO_8` hack). See `references/urob-patterns.md`.

### 4. Adding a mod-morph

Use when a single key should produce different keycodes depending on the modifier state.

```dts
// zmk-helpers:
ZMK_MOD_MORPH(bs_del,
    bindings = <&kp BSPC>, <&kp DEL>;
    mods = <(MOD_LSFT|MOD_RSFT)>;
)
// Raw:
/ {
    behaviors {
        bs_del: bs_del {
            compatible = "zmk,behavior-mod-morph";
            #binding-cells = <0>;
            bindings = <&kp BACKSPACE>, <&kp DELETE>;
            mods = <(MOD_LSFT|MOD_RSFT)>;
        };
    };
};
```

- First binding fires unshifted; second fires when `mods` are held.
- `keep-mods = <MOD_RSFT>;` — keep the right-shift held while morphing (e.g. for Shift+Delete which some apps want as a chord).
- Mod-morphs **can nest** — the morphed binding can itself be a mod-morph, yielding three-way (or N-way) outputs (e.g. tap=`,`, shift=`;`, ctrl+shift=`<`).

```dts
SIMPLE_MORPH(comma_morph,       SFT, &kp COMMA, &comma_inner_morph)
SIMPLE_MORPH(comma_inner_morph, CTL, &kp SEMI,  &kp LT)
```

---

## Position numbering: finding LT3, LM2, RH0

ZMK position indices come from the matrix transform in the shield definition. Most configs define semantic aliases that are MUCH easier to read than raw integers.

Look for a `*_defs.dtsi` file or a `zmk-helpers/key-labels/<board>.h` include. The convention urob established (used by many configs):

```
        ┌───┬───┬───┬───┬───┐         ┌───┬───┬───┬───┬───┐
        │LT4│LT3│LT2│LT1│LT0│         │RT0│RT1│RT2│RT3│RT4│       T = top row
   ┌────┤LM4│LM3│LM2│LM1│LM0│         │RM0│RM1│RM2│RM3│RM4├────┐  M = middle (home) row
   │LB5 │LB4│LB3│LB2│LB1│LB0│         │RB0│RB1│RB2│RB3│RB4│RB5 │  B = bottom row
   └────┴───┴───┴───┴───┴───┘         └───┴───┴───┴───┴───┴────┘
                  ┌───┬───┬───┐ ┌───┬───┬───┐
                  │LH2│LH1│LH0│ │RH0│RH1│RH2│                      H = thumb cluster
                  └───┴───┴───┘ └───┴───┴───┘
```

(Exact key count varies by board — a 34-key sweep has no `LB5/RB5`, no `LT4/RT4`. A 38-key TOTEM does. Check the actual header.)

`KEYS_L`, `KEYS_R`, and `THUMBS` aggregates are typically also defined:

```dts
#define KEYS_L  LT0 LT1 LT2 LT3 LT4 LM0 LM1 LM2 LM3 LM4 LB0 LB1 LB2 LB3 LB4 [LB5]
#define KEYS_R  RT0 RT1 RT2 RT3 RT4 RM0 RM1 RM2 RM3 RM4 RB0 RB1 RB2 RB3 RB4 [RB5]
#define THUMBS  LH2 LH1 LH0 RH0 RH1 RH2
```

These are the only labels you should use in `hold-trigger-key-positions` and combo `key-positions` for clarity.

---

## Conventions: zmk-helpers vs raw devicetree

If `config/west.yml` lists `zmk-helpers` as a project and the keymap `#include "zmk-helpers/helper.h"`, **prefer the helper macros** — they're an established convention in the community and the file will already look like that. Common macros (alphabetical):

| Macro | Use |
|---|---|
| `ZMK_BEHAVIOR(name, compat, ...)` | Generic behavior wrapper (rarely needed directly). |
| `ZMK_COMBO(name, bindings, key-positions, layers, timeout-ms, prior-idle)` | 6-arg combo (the standard). |
| `ZMK_COMBO_8(...)` | urob's HRM-overlap hack (8 args; defined locally, not in zmk-helpers itself). |
| `ZMK_CONDITIONAL_LAYER(name, if-layers, then-layer)` | Tri-layer style. |
| `ZMK_HOLD_TAP(name, ...)` | Custom hold-tap. |
| `ZMK_KEY_REPEAT(name, ...)` | Define a key-repeat variant (e.g., for consumer keys). |
| `ZMK_LAYER(name, bindings)` | Define a layer (positional). |
| `ZMK_BASE_LAYER(name, ...)` | Polymorphic base layer for multi-board configs. |
| `ZMK_MACRO(name, bindings, ...)` | Zero-param macro. |
| `ZMK_MACRO_ONE_PARAM(name, ...)` | One-param macro. |
| `ZMK_MOD_MORPH(name, bindings, mods, ...)` | Mod-morph. |
| `ZMK_TAP_DANCE(name, bindings, tapping-term-ms)` | Tap-dance. |

If the keymap is raw devicetree (no `zmk-helpers/helper.h` include), use raw `compatible = "zmk,behavior-..."` blocks. Don't introduce zmk-helpers in a repo that doesn't use it without checking with the user first — it changes the build dependencies.

---

## Common pattern recipes

### Bilateral homerow mods

See "timeless HRM recipe" above. The non-negotiable ingredients: `balanced`, positional gating with opposite-hand positions, `require-prior-idle-ms`, `hold-trigger-on-release`.

### "Smart shifted punctuation"

```dts
// , (unshifted) | ; (shift) | < (ctrl+shift)
SIMPLE_MORPH(comma_morph,       SFT, &kp COMMA,    &comma_inner)
SIMPLE_MORPH(comma_inner,       CTL, &kp SEMI,     &kp LT)
// . (unshifted) | : (shift) | > (ctrl+shift)
SIMPLE_MORPH(dot_morph,         SFT, &kp DOT,      &dot_inner)
SIMPLE_MORPH(dot_inner,         CTL, &kp COLON,    &kp GT)
// ? (unshifted) | ! (shift)
SIMPLE_MORPH(qexcl,             SFT, &kp QMARK,    &kp EXCL)
```

`SIMPLE_MORPH` is a project-local convenience macro (urob defines it; many configs copy it):

```dts
#define SIMPLE_MORPH(NAME, MOD, BINDING1, BINDING2)                            \
  ZMK_MOD_MORPH(NAME, mods = <(MOD_L##MOD | MOD_R##MOD)>;                      \
                bindings = <BINDING1>, <BINDING2>;)
```

### Conditional layer (tri-layer)

```dts
// Holding both NAV and SYM activates ADJ automatically
ZMK_CONDITIONAL_LAYER(adj, NAV SYM, ADJ)
// Raw:
conditional_layers {
    compatible = "zmk,conditional-layers";
    adj_layer {
        if-layers = <1 2>;        // both must be active
        then-layer = <3>;         // this one activates
    };
};
```

**Rule**: `then-layer` index MUST be higher than any `if-layers` index, otherwise it won't be discovered. Don't also bind `&mo 3` or `&tog 3` for an `ADJ` that's used as a `then-layer` — the conditional system owns its state.

### Mod-masking with mod-morph

The "stealth" trick: a mod-morph whose two bindings are *identical* but `mods` consumes a held modifier:

```dts
#define MASK_MODS(NAME, MODS, BINDING)                                         \
  ZMK_MOD_MORPH(NAME, bindings = <BINDING>, <BINDING>; mods = <MODS>;)

MASK_MODS(masked_home, (MOD_LCTL), &kp HOME)
MASK_MODS(masked_end,  (MOD_LCTL), &kp END)
```

Used on a nav cluster where Ctrl shouldn't compose with Home/End (which would jump to start/end of document instead of line). See `references/urob-patterns.md`.

### Sticky-key + sticky-layer one-shot stack

```dts
// On Sym layer:
&sk LSHIFT   // sticky shift

// On Base layer:
&sl SYM      // sticky symbol layer
```

Tap `&sl SYM` → tap `&sk LSHIFT` → tap `&kp N1` produces `Shift+1` = `!`. No holding required. This composition is why sticky-layer releases on next *press* while sticky-key releases on next *release* — the sticky-layer drops before the sticky-shift triggers.

Configure global `&sk`/`&sl` defaults at the keymap top level:

```dts
&sk {
  release-after-ms = <900>;
  quick-release;
};
&sl {
  ignore-modifiers;     // allow sticky-shift to chord across sticky-layers
};
```

### Key repeat with consumer keys

The default `&key_repeat` only captures HID keyboard page (it ignores volume/media). To include consumer keys:

```dts
ZMK_KEY_REPEAT(repeat, usage-pages = <HID_USAGE_KEY HID_USAGE_CONSUMER>;)
```

(Requires `#include <dt-bindings/zmk/hid_usage_pages.h>`.)

### ZMK Studio enable

In `config/<name>.conf`:

```
CONFIG_ZMK_STUDIO=y
CONFIG_ZMK_STUDIO_LOCKING=n   # optional: skip the unlock-key requirement
```

In `build.yaml`, add `snippet: studio-rpc-usb-uart` to each shield row (Studio needs the USB UART RPC channel).

---

## Build troubleshooting

The GitHub Actions log is your authoritative source. The most common failure patterns and fixes:

| Error message contains | Cause | Fix |
|---|---|---|
| `Reference to non-existent node or label` | A `&foo` reference where `foo:` is not defined, OR a missing `#include` | Check that the behavior is defined (or imported). |
| `was assigned the value '...' which is not in the enumeration` | Typo in a property's allowed value (e.g. `flavour = "balanced"` — note British spelling) | Fix the spelling. ZMK uses American: `flavor`. |
| `cells in 'bindings' must be a multiple of N` | Layer has wrong number of key bindings | Count keys; should match the matrix transform key count. |
| `expected ';'` near a behavior | Missing semicolon between property assignments | Add `;`. |
| `'compatible' was given the value '...' which is not in the enumeration` | Typo'd compatible string | Check exact spelling: `zmk,behavior-hold-tap`, `zmk,behavior-mod-morph`, `zmk,behavior-mod-tap`, `zmk,combos`, `zmk,conditional-layers`, `zmk,keymap`, `zmk,behavior-macro`, etc. |
| `error: '<KEYCODE>' undeclared` | Missing keycode include OR keycode typo (e.g. `BCKSP`) | `#include <dt-bindings/zmk/keys.h>`. Cross-reference `references/keycodes.md`. |
| `error: 'BT_SEL' undeclared` | Missing BT include | `#include <dt-bindings/zmk/bt.h>`. |
| `Behavior cannot have <N> params` | A multi-param behavior used where one-param expected, e.g. `&bt BT_SEL 0` inside a hold-tap's `bindings` | Wrap in a zero-param macro and reference that. |
| `Conditional layer ... could not be found` | `then-layer` has lower index than its `if-layers` | Move target layer to be highest-numbered. |
| `inclusion is duplicated` / `redefinition` | Same `.dtsi` file included twice without guards | Wrap header in `#ifndef FOO_DTSI / #define FOO_DTSI / ... / #endif`. |

### Reading a CI build log

GitHub Actions: tab Actions → click the failing run → expand the failing job (`Build (totem_left)` or similar) → expand the "Build" step. The actual devicetree error usually shows up about 20 lines from the bottom, with a file:line reference like `keymap.dts.pre.tmp:127.30-127.35`. The `.pre.tmp` is the preprocessed version; the line numbers won't match your source 1:1 because includes have been inlined. Search the source for the offending token to find the right spot.

### Local dry-run

If the user has Nix or a dev container, they can `west build -p -d build/left -b xiao_ble -- -DSHIELD=totem_left` to reproduce a failure without pushing. Most users don't have this set up; the GitHub Actions path is canonical.

---

## When to load reference files

For deeper detail on a specific topic, instruct yourself to read the matching reference file:

- **`references/hold-tap.md`** — full flavor decision tree, all properties with concrete examples, the timing tuning guide, gotchas (quick-tap-ms press-vs-release semantics, retro-tap incompatibilities, hold-while-undecided + combos interaction).
- **`references/zmk-helpers.md`** — every helper macro with arg list, when to use vs raw devicetree, common gotchas (token-pasting, parameter forwarding in `MAKE_HRM`-style factories).
- **`references/urob-patterns.md`** — advanced techniques from urob/zmk-config: HRM-overlapping combos via `ZMK_COMBO_8`, magic shift/repeat/caps-word, smart-num auto-layer, smart-mouse tri-state, leader keys, the mod-masking technique, multi-board polymorphic base layers via `ZMK_BASE_LAYER`. These typically require **additional ZMK modules** (e.g. `zmk-adaptive-key`, `zmk-tri-state`, `zmk-auto-layer`, `zmk-leader-key`) listed in `config/west.yml`.
- **`references/keycodes.md`** — complete keycode table with all shorthand aliases (`BSPC`, `RET`, `SEMI`, `LBKT`, ...), modifier macros (`LS(...)`, `LC(LS(A))`), media keys, locale notes.
- **`references/troubleshooting.md`** — extended troubleshooting catalog with example error messages and the exact fix.

Load these only when the user's request actually touches them. SKILL.md alone covers most editing tasks.

---

## Tone and approach

- **Be explicit about what to read and what to edit.** Cite `config/totem.keymap:42` style file:line references when proposing changes.
- **Preserve existing style.** If the keymap aligns columns with spaces, keep doing that. If it uses `&trans` placeholders, keep those.
- **Don't introduce new modules silently.** Adding e.g. `zmk-auto-layer` to `west.yml` is a real dependency change; flag it.
- **Default to the smaller change.** If a `hold-trigger-key-positions` value needs tweaking, change the timing — don't rewrite the whole HRM block.
- **Surface ambiguity.** If the user says "add Shift to my homerow" without saying which finger, ask which physical key — there are conventions (GACS — GUI/ALT/CTRL/SHIFT pinky-to-index) but they vary.
- **Connect the dots with the user's existing patterns.** If they're already using `SIMPLE_MORPH` and `MAKE_HRM`, suggest changes in those terms; don't rewrite as raw devicetree.

Don't volunteer ZMK trivia the user didn't ask for. Answer the question directly with code; deeper context goes in the reference files for when it matters.
