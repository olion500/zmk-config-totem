# Advanced Patterns from urob/zmk-config

urob's [zmk-config](https://github.com/urob/zmk-config) is the de-facto reference for advanced ZMK techniques. This file catalogues the most-cited patterns so they can be applied (or adapted) to other configs.

**Important caveat**: many of these patterns require ZMK MODULES that aren't in upstream ZMK. They're listed in urob's `west.yml`:

- `zmk-helpers` — macros (covered in `zmk-helpers.md`); the only one most configs actually use.
- `zmk-adaptive-key` — context-dependent bindings ("repeat after a letter, else sticky-shift").
- `zmk-auto-layer` — auto-deactivating layers (`&num_word`).
- `zmk-tri-state` — start/continue/end state machines (smart-mouse, alt-tab swapper).
- `zmk-leader-key` — leader-key sequences with branching.
- `zmk-unicode` — Unicode input behaviors (`&uc UC_DE_AE` for `ä`).

If a pattern below references one of these, adding it means modifying `west.yml`. Flag this to the user — it's a real dependency.

## Table of contents

- [Timeless homerow mods](#hrm)
- [HRM-overlap combo workaround](#hrm-combo)
- [Magic Shift / Repeat / Caps-Word](#magic-shift)
- [Smart-Num auto-layer](#smart-num)
- [Smart-Mouse tri-state](#smart-mouse)
- [Alt-Tab swapper](#swapper)
- [Multi-purpose nav cluster with masked mods](#nav)
- [Smart shifted punctuation (nested mod-morph)](#punct)
- [Space/Nav layer-tap with shift→". space + sticky"](#space)
- [Leader key sequences](#leader)
- [Multi-board polymorphic base layer](#base-layer)

---

<a name="hrm"></a>
## Timeless homerow mods

The flagship. Covered in `hold-tap.md` (full rationale) and `SKILL.md` (the recipe). Key takeaway: a large tapping term (280ms) combined with three short-circuits (`balanced` flavor, `require-prior-idle-ms`, positional gating) yields virtually zero misfires.

```dts
MAKE_HRM(hml, &kp, &kp, KEYS_R THUMBS)
MAKE_HRM(hmr, &kp, &kp, KEYS_L THUMBS)
```

GACS order in the home row: GUI/ALT/CTRL/SHIFT (pinky-to-index, mirrored on the right). Use `RSHFT` on the right index (not `LSHFT`) to avoid OS shortcuts that expect specifically left-shift.

Rule of thumb for `require-prior-idle-ms`: `10500 / WPM`.

---

<a name="hrm-combo"></a>
## HRM-overlap combo workaround (ZMK_COMBO_8)

**Problem**: A combo on positions `LM3 LM2` (the R and S keys, which are HRM positions) forces a momentary pause when chording an HRM that overlaps with the combo positions. (ZMK issue [#544](https://github.com/zmkfirmware/zmk/issues/544).)

**Workaround**: implement HRM-overlapping combos AS hold-taps. The combo triggers the tap-action when fired, but holding the same chord produces the mod (with positional gating).

```dts
// In totem_defs.dtsi or base.keymap:
#define ZMK_COMBO_8(NAME, TAP, POS, LAYERS, COMBO_MS, IDLE_MS, HOLD, SIDE)     \
  MAKE_HRM(hm_combo_##NAME, &kp, TAP, SIDE THUMBS)                             \
  ZMK_COMBO_6(NAME, &hm_combo_##NAME HOLD 0, POS, LAYERS, COMBO_MS, IDLE_MS)
```

Then in `combos.dtsi`, invoke with the 8-arg `ZMK_COMBO`:

```dts
ZMK_COMBO(lpar, &lpar_lt, RM1 RM2, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST, RS(LCTRL), KEYS_L)
//        ^name ^tap-act  ^pos     ^layers      ^timeout         ^prior-idle      ^hold-mod   ^opposite-hand
```

This: defines a per-combo HRM named `hm_combo_lpar` whose hold is `RS(LCTRL)` and tap is `&lpar_lt`; then defines a combo on positions `RM1 RM2` that fires `&hm_combo_lpar RS(LCTRL) 0`. Same physical chord can be tapped (gets `(` via `&lpar_lt`'s mod-morph) or held (gets right-Ctrl).

Trade-off: each 8-arg combo creates an extra behavior in the tree. Don't apply to every combo — only the ones that genuinely overlap HRM positions.

---

<a name="magic-shift"></a>
## Magic Shift / Repeat / Caps-Word

**Goal**: one key (right thumb) that does FOUR things:
- Tap after an alpha → key-repeat (reduce same-finger-utilization)
- Tap otherwise → sticky-shift (to capitalize the next key)
- Hold → regular shift
- Double-tap (or shift+tap) → caps-word

**Requires**: `zmk-adaptive-key` module.

```dts
#define MAGIC_SHIFT &magic_shift LSHFT 0

ZMK_HOLD_TAP(magic_shift,
    flavor = "balanced";
    tapping-term-ms = <200>;
    quick-tap-ms = <175>;
    bindings = <&kp>, <&magic_shift_tap>;
)

ZMK_MOD_MORPH(magic_shift_tap,
    bindings = <&shift_repeat>, <&caps_word>;
    mods = <(MOD_LSFT)>;                            // if shift already held, escalate to caps-word
)

ZMK_ADAPTIVE_KEY(shift_repeat,
    bindings = <&sk LSHFT>;                         // default: sticky shift
    repeat {
        trigger-keys = <A B C D E F G H I J K L M N O P Q R S T U V W X Y Z>;
        bindings = <&key_repeat>;
        max-prior-idle-ms = <1200>;
        strict-modifiers;
    };
)

&caps_word {
    /delete-property/ ignore-modifiers;             // mods deactivate caps-word
};
```

**The "tap-dance without delay" insight** (urob): a tap-dance would force every tap to wait for the double-tap timer. Instead, this uses sticky-shift as a transient flag — the FIRST tap fires `&sk LSHFT`, which leaves the modifier active briefly; the SECOND tap sees that LSHFT in the mod-morph and escalates to caps-word. Zero delay on the first tap.

---

<a name="smart-num"></a>
## Smart-Num auto-layer

**Goal**: tap once to enter "numword" mode — number layer stays active while digits are typed, auto-deactivates on first non-digit.

**Requires**: `zmk-auto-layer` module.

```dts
#define SMART_NUM &smart_num NUM 0

ZMK_HOLD_TAP(smart_num,
    flavor = "balanced";
    tapping-term-ms = <200>;
    quick-tap-ms = <175>;
    bindings = <&mo>, <&num_dance>;
)

ZMK_TAP_DANCE(num_dance,
    bindings = <&num_word NUM>, <&sl NUM>;          // single tap: numword | double tap: sticky layer
    tapping-term-ms = <200>;
)
```

```dts
#include <behaviors/num_word.dtsi>    // from zmk-auto-layer module
```

- Hold → momentary NUM layer.
- Single tap → numword (auto-deactivates on non-digit).
- Double tap → sticky NUM layer (until next press).

For the rare case where you immediately type a letter that's also on the NUM layer (which would extend the auto-layer), there's a `K_CANCEL` key:

```dts
#define CANCEL &kp K_CANCEL    // Cancels caps-word, num-word, smart-mouse
```

---

<a name="smart-mouse"></a>
## Smart-Mouse tri-state

**Goal**: combo `W+P` enters mouse layer; layer persists while you press mouse-layer keys; auto-deactivates on any other key.

**Requires**: `zmk-tri-state` module.

```dts
ZMK_TRI_STATE(smart_mouse,
    bindings = <&tog MOUSE>, <&none>, <&tog MOUSE>;        // start, continue, end
    ignored-key-positions = <LT1 LT2 LH0 LH1 RT1 RT2 RT3 RM0 RM1 RM2 RM3 RM4 RB1 RB2 RB3 RH0 RH1>;
    ignored-layers = <MOUSE NAV FN>;
)

// Triggered via combo:
ZMK_COMBO(mouse, &smart_mouse, LT2 LT1, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST)
```

`ignored-key-positions` are the mouse layer's own keys — these don't end the state. Any OTHER key press deactivates.

The pattern generalises: a tri-state with `bindings = <&tog X>, <&none>, <&tog X>` is a "smart layer" that toggles on, persists, and auto-toggles off.

---

<a name="swapper"></a>
## Alt-Tab swapper

**Goal**: one key opens the task switcher (Alt+Tab) and you can tap repeatedly to cycle; on release (or non-ignored key) the Alt is released.

**Requires**: `zmk-tri-state` module.

```dts
ZMK_TRI_STATE(swapper,
    bindings = <&kt LALT>, <&kp TAB>, <&kt LALT>;
    ignored-key-positions = <LT2 RT2 RM1 RM2 RM3>;        // self + arrow keys (so you can navigate within task list)
)
```

Note `&kt` (key-toggle), not `&kp`. `&kt` toggles the modifier state rather than tracking press/release — this is how the mod stays held across multiple TAB presses.

---

<a name="nav"></a>
## Multi-purpose nav cluster with masked mods

**Goal**: nav-cluster keys produce arrow keys on tap, but on long-press act as Home/End/word-back/word-forward. AND Ctrl+Home (held during nav) should NOT jump to document start (it's accessible via dedicated long-press up-arrow).

```dts
#define MT_CORE                                                                \
  flavor = "tap-preferred";                                                    \
  tapping-term-ms = <220>;                                                     \
  quick-tap-ms = <220>;                                                        \
  hold-trigger-key-positions = <0>;        // placeholder; tap-preferred ignores this anyway

&mt { MT_CORE };

ZMK_HOLD_TAP(mt_home, bindings = <&masked_home>, <&kp>; MT_CORE)
ZMK_HOLD_TAP(mt_end,  bindings = <&masked_end>,  <&kp>; MT_CORE)

#define NAV_LEFT   &mt_home 0 LEFT      // tap=LEFT, long-tap=HOME (Ctrl masked)
#define NAV_RIGHT  &mt_end  0 RIGHT     // tap=RIGHT, long-tap=END (Ctrl masked)
#define NAV_UP     &mt LC(HOME) UP       // tap=UP, long-tap=Ctrl+HOME (doc start)
#define NAV_DOWN   &mt LC(END)  DOWN
#define NAV_BSPC   &mt LC(BSPC) BSPC     // tap=BSPC, long-tap=word-backspace
#define NAV_DEL    &mt LC(DEL)  DEL

// Mask CTRL so long-tap LEFT/RIGHT goes to line start/end, NOT doc start/end.
#define MASK_MODS(NAME, MODS, BINDING)                                         \
  ZMK_MOD_MORPH(NAME, bindings = <BINDING>, <BINDING>; mods = <MODS>;)

MASK_MODS(masked_home, (MOD_LCTL), &kp HOME)
MASK_MODS(masked_end,  (MOD_LCTL), &kp END)
```

**The `MASK_MODS` trick**: a mod-morph with both bindings identical. The `mods` property silently consumes a held modifier without releasing it elsewhere. So if the user is holding Ctrl+nav-left for some other reason, `&masked_home` fires plain Home (line start) instead of Ctrl+Home (doc start). The Ctrl stays held for other purposes.

This is mod-morph used for *suppression*, not for shifted alternates.

---

<a name="punct"></a>
## Smart shifted punctuation (nested mod-morph)

```dts
SIMPLE_MORPH(comma_morph,       SFT, &kp COMMA,    &comma_inner)
SIMPLE_MORPH(comma_inner,       CTL, &kp SEMI,     &kp LT)

SIMPLE_MORPH(dot_morph,         SFT, &kp DOT,      &dot_inner)
SIMPLE_MORPH(dot_inner,         CTL, &kp COLON,    &kp GT)

SIMPLE_MORPH(qexcl,             SFT, &kp QMARK,    &kp EXCL)

SIMPLE_MORPH(lpar_lt,           SFT, &kp LPAR,     &kp LT)
SIMPLE_MORPH(rpar_gt,           SFT, &kp RPAR,     &kp GT)
```

The nested pattern (`comma_morph` morphs on shift → `comma_inner`, which morphs on ctrl) gives three outputs per key: `comma`/`;`/`<` and `.`/`:`/`>` etc.

```dts
#define SIMPLE_MORPH(NAME, MOD, BINDING1, BINDING2)                            \
  ZMK_MOD_MORPH(NAME, mods = <(MOD_L##MOD | MOD_R##MOD)>;                      \
                bindings = <BINDING1>, <BINDING2>;)
```

---

<a name="space"></a>
## Space/Nav layer-tap with shift→". space + sticky shift"

```dts
ZMK_HOLD_TAP(lt_spc,
    flavor = "balanced";
    tapping-term-ms = <200>;
    quick-tap-ms = <175>;
    bindings = <&mo>, <&spc_morph>;
)

SIMPLE_MORPH(spc_morph, SFT, &kp SPACE, &dot_spc)

ZMK_MACRO(dot_spc,
    wait-ms = <0>;
    tap-ms = <5>;
    bindings = <&kp DOT &kp SPACE &sk LSHFT>;
)

// In layer: &lt_spc NAV 0
```

- Tap: SPACE.
- Tap while holding shift: types ". space + sticky shift" — perfect end-of-sentence flow with auto-capitalized next word.
- Hold: NAV layer.

`wait-ms = <0>` and `tap-ms = <5>` make the macro fire near-instantly.

---

<a name="leader"></a>
## Leader key sequences

**Goal**: a combo activates a "leader" mode; subsequent keypresses match a sequence and fire a custom behavior.

**Requires**: `zmk-leader-key` module.

```dts
ZMK_COMBO(ldr, &leader, LM2 LM1, DEF NAV NUM, COMBO_TERM_FAST, COMBO_IDLE_FAST, LS(LCTRL), KEYS_R)
//                                                                                  ^uses ZMK_COMBO_8 (with HRM fallback)

ZMK_LEADER_SEQUENCE(boot,  &bootloader,    B O O T)
ZMK_LEADER_SEQUENCE(reset, &sys_reset,     R E S E T)
ZMK_LEADER_SEQUENCE(usb,   &out OUT_USB,   U S B)
ZMK_LEADER_SEQUENCE(ble,   &out OUT_BLE,   B L E)
ZMK_LEADER_SEQUENCE(de_ae, &uc UC_DE_AE,   A)        // a → ä (requires zmk-unicode)
```

Spell out the sequence as space-separated keycodes. After tapping the leader combo, typing those keys (in order) fires the bound behavior.

---

<a name="base-layer"></a>
## Multi-board polymorphic base layer

**Goal**: one base.keymap, multiple boards (Corneish Zen, Glove80, Planck, ...). Each board's keymap file is a thin adapter that pads zone arguments around the base.

```dts
// base.keymap (the single source of truth)
#ifndef ZMK_BASE_LAYER
  #define ZMK_BASE_LAYER(name, LT, RT, LM, RM, LB, RB, LH, RH)    \
      ZMK_LAYER(name, LT RT LM RM LB RB LH RH)
#endif

ZMK_BASE_LAYER(Base,
    &kp Q  &kp W  &kp F  &kp P  &kp B     ,    &kp J  &kp L  &kp U  &kp Y  &kp SQT   ,    // LT, RT
    &hml LGUI A  &hml LALT R  ...           ,                                              // LM, RM
    &kp Z  &kp X  &kp C  &kp D  &kp V       ,                                              // LB, RB
                          &lt_spc NAV 0  &lt FN RET  ,  SMART_NUM  MAGIC_SHIFT              // LH, RH
)
```

Each board adapter:

```dts
// planck.keymap
#define ZMK_BASE_LAYER(name, LT, RT, LM, RM, LB, RB, LH, RH)    \
    ZMK_LAYER(name,                                              \
        &none LT &none      &none RT &none                       \
        &none LM &none      &none RM &none                       \
        &none LB &none      &none RB &none                       \
        &none &none LH      RH &none &none                       \
    )
#include "zmk-helpers/key-labels/planck.h"
#include "base.keymap"
```

The board-specific positions (the wide zones around the inner 34) are filled with `&none` (or whatever you want); the parametrised zones get the base bindings.

For a single-board config (like a TOTEM-only repo), you can skip this and just define the layers directly with `ZMK_LAYER(...)`.

---

## What's in zmk-helpers vs urob's repo

- **`zmk-helpers`**: the upstream module providing `ZMK_HOLD_TAP`, `ZMK_COMBO`, `ZMK_MOD_MORPH`, `ZMK_TAP_DANCE`, `ZMK_MACRO`, `ZMK_LAYER`, `ZMK_BASE_LAYER`, `ZMK_CONDITIONAL_LAYER`, `ZMK_KEY_REPEAT`, key-label headers for many boards, and the `MAKE_HRM` skeleton.
- **`urob/zmk-config`'s `base.keymap`**: project-local conventions (`SIMPLE_MORPH`, `MASK_MODS`, `ZMK_COMBO_8`, `QUICK_TAP_MS`, `MT_CORE`, `XXX`/`___` aliases) — these are NOT in the upstream library. Copy them into your own repo.

When recommending an "urob pattern," be explicit about whether it's a one-line macro (copy-paste) or a whole module dependency (modifies `west.yml`).
