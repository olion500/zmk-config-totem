# Hold-Tap Deep Dive

Hold-tap is ZMK's single most important behavior abstraction. It lets one physical key produce different actions based on press duration and surrounding context. Mod-tap (`&mt`) and layer-tap (`&lt`) are preconfigured instances; everything else (homerow mods, smart space, nav clusters with long-press) is a custom hold-tap.

This reference covers the full configuration surface, the four flavors with worked examples, and the most-asked-about tuning patterns.

## Table of contents

- [Anatomy of a hold-tap](#anatomy)
- [The four flavors](#flavors)
- [Properties reference](#properties)
- [Timing tuning guide](#tuning)
- [Worked examples](#examples)
- [Gotchas](#gotchas)

---

<a name="anatomy"></a>
## Anatomy of a hold-tap

```dts
/ {
    behaviors {
        my_ht: my_hold_tap {
            compatible = "zmk,behavior-hold-tap";
            #binding-cells = <2>;                  // caller supplies 2 params
            flavor = "balanced";
            tapping-term-ms = <200>;
            quick-tap-ms = <0>;
            require-prior-idle-ms = <0>;
            hold-trigger-key-positions = < >;
            hold-trigger-on-release;
            bindings = <&kp>, <&kp>;               // <hold-action>, <tap-action>
        };
    };
};
```

Usage in a layer:

```dts
&my_ht LSHIFT A    // hold: LSHIFT (routed to bindings[0]),  tap: A (routed to bindings[1])
```

The caller's first param feeds the first binding (hold-action); the second feeds the second binding (tap-action). Both target bindings must take exactly one parameter — you can't put a multi-param behavior like `&bt BT_SEL` here directly. If you need a multi-param hold action, wrap it in a zero-param macro and use the macro's name.

`#binding-cells = <2>` is the cell count the *caller* supplies. If both target bindings are zero-param (e.g. `<&caps_word>`), the caller still supplies dummy zeros: `&my_ht 0 0`.

With zmk-helpers:

```dts
ZMK_HOLD_TAP(my_ht,
    flavor = "balanced";
    tapping-term-ms = <200>;
    bindings = <&kp>, <&kp>;
)
```

The macro sets `compatible` and `#binding-cells = <2>` automatically.

---

<a name="flavors"></a>
## The four flavors

The flavor controls **how the hold-vs-tap decision is made**.

### `hold-preferred` — aggressive hold

Hold fires when ANY other key is pressed within the term, OR when the term expires.

```
press &ht --- press X --- ...
       └──> commits to HOLD immediately on X press
```

- QMK analog: `HOLD_ON_OTHER_KEY_PRESS`.
- Default for `&mt` (mod-tap).
- **Wrong choice for homerow mods.** Fast typing rolls `&hml LSHIFT F` into `g` → produces Shift+g instead of "fg".
- Good for: thumb modifiers you never roll, dedicated hot-corner keys.

### `tap-preferred` — conservative hold

Hold only fires when the term EXPIRES while held. Other key presses do nothing to the decision.

```
press &ht --- press X --- release X --- ... wait for term --- term expires
                                                              └──> commits to HOLD
```

- Default for `&lt` (layer-tap).
- Good for: layer-tap on thumbs (you can roll into a layer key without accidentally toggling the layer). Long-press alternates like nav clusters (`&mt LC(HOME) UP` — tap=UP, hold=Ctrl+Home).
- Bad for: anything where you want fast modifier access (you have to wait the full term to chord shift).

### `balanced` — interrupt-on-release

Hold fires when another key is BOTH pressed AND released while `&ht` is still held, OR when term expires.

```
press &ht --- press X --- release X
                          └──> commits to HOLD here
```

- QMK analog: `PERMISSIVE_HOLD`.
- **The homerow mod choice.** Plays nicely with rolling typing: if you press `&hml LSHIFT F` and then press `g` and release `&hml` BEFORE releasing `g`, the rollover counts as a tap → produces "fg". Only if you release `g` while still holding `&hml` does Shift fire.
- Combined with positional gating (next section) and `require-prior-idle-ms`, this is the recipe for misfire-free HRMs.

### `tap-unless-interrupted` — almost always tap

Inverted: only fires HOLD if interrupted before the term. Otherwise tap.

- Niche use cases — for shift on a thumb where you almost never want hold semantics but occasionally need them.

---

<a name="properties"></a>
## Properties reference

### `tapping-term-ms` (default 200)

Milliseconds until the timer commits the decision.

- 150–200ms: classic. The keypress feels "snappy" — short hold needs less commitment.
- 220–250ms: nav-cluster long-press. Gives time to deliberately reach for the alt-action.
- 280ms: urob's HRM choice. Long enough that the flavor logic (not the timer) decides most cases. The timer exists only for `tap-preferred` interactions that you actually want to hold (e.g. holding GUI to open Start menu).

> Setting `tapping-term-ms = 0` does NOT mean "always tap"; it means "decide immediately on next event."

### `quick-tap-ms` (default 0 = disabled)

If THIS hold-tap was tapped within the last N ms, force the next press to resolve as tap.

```
tap &ht --- (within quick-tap-ms) press &ht
                                  └──> always tap, no chance of hold
```

Use case: tap-tap-and-hold for auto-repeat. If `&hml LSHIFT F` has `quick-tap-ms = 175`, doing `f-pause-fff` will type `f` then hold-repeat `f` — without the modifier ever firing.

**ZMK semantics differ from QMK**: ZMK measures press-to-press, QMK measures release-to-press. When porting from QMK, set ZMK's value LARGER (you need to cover the prior tap's hold time too).

### `require-prior-idle-ms` (default 0 = disabled)

If any non-modifier key was pressed within N ms before this hold-tap pressed, force tap.

```
type X --- (within require-prior-idle-ms) press &ht
                                          └──> always tap, no chance of hold
```

The killer feature for "timeless" HRMs. Rule of thumb: **`require-prior-idle-ms ≈ 10500 / WPM`**.
- 60 WPM → 175ms
- 70 WPM → 150ms  (urob's default)
- 80 WPM → 130ms
- 100 WPM → 105ms

Higher = fewer false-positives during rapid typing but more delay when you DO want a mod after typing. Tune to taste.

> Modifier presses don't reset the idle timer. So pressing LSHIFT, then `&ht`, still allows the hold path (you can chord HRMs with already-held mods).

### `hold-trigger-key-positions = <pos1 pos2 ...>`

Whitelist of physical positions that can trigger the HOLD. Pressing any other position before the term forces tap.

For bilateral HRMs:
- Left-hand HRM: list right-hand positions + thumbs.
- Right-hand HRM: list left-hand positions + thumbs.

This prevents same-hand rollovers from triggering the mod. If you're typing "type" with `&hml LSHIFT t` then `y`, you DON'T want shift — you want lowercase y. Positional gating enforces that.

If you DO want a placeholder that disables the positional check (i.e. "trigger from anywhere"), set it to a single arbitrary position like `<0>` with a `tap-preferred` flavor that ignores other key presses anyway. (See nav-cluster pattern below.)

### `hold-trigger-on-release`

Boolean flag (no `=` value). Delays positional check from the interrupting key's **press** to its **release**.

Without this, you can't combine two same-hand HRMs: pressing `&hml LSHIFT F` then `&hml LCTRL D` would be blocked by the positional rule (D is same-hand).

With this, the positional check happens when D *releases*. If D is released before `&hml LSHIFT F` releases, it's a roll → tap. If D is still held when `&hml LSHIFT F` releases (chord), HRM resolution wins → Shift+Ctrl held. Enables `Ctrl+Shift+Tab` and similar.

### `retro-tap`

If the term expired with no other key press, fire tap on release anyway. Without `retro-tap`, you'd hold the key, the timer expires, you release — nothing visible happened. With `retro-tap`, you get the tap retroactively.

```dts
&mt { retro-tap; };
```

> Incompatible with mouse behaviors. Don't combine.

### `hold-while-undecided` / `hold-while-undecided-linger`

Send the hold action IMMEDIATELY on press, retract if the resolution turns out tap. Default behavior queues actions until resolution is known.

Used for Shift-Click: the host needs to see Shift down before the mouse click event. Without `hold-while-undecided`, the click would arrive while Shift is still in the queue.

`-linger` keeps the hold pressed even after the tap action releases. Prevents double-tap glitches when hold and tap target the same modifier (e.g. `&kp LGUI` hold + `&sk LGUI` tap).

---

<a name="tuning"></a>
## Timing tuning guide

If HRMs feel wrong, the symptom usually points to which knob to turn:

| Symptom | Probable cause | Fix |
|---|---|---|
| Noticeable delay when tapping an HRM | `require-prior-idle-ms` too high | Reduce; or use `quick-tap-ms` to handle rapid re-taps |
| Wrong mod fires when typing fast same-hand (e.g. "th" produces Shift+h) | `hold-trigger-key-positions` not set or includes same-hand positions | Add bilateral positional gating |
| Wrong mod fires when typing fast cross-hand (e.g. "ja" produces Shift+a) | `require-prior-idle-ms` too low | Increase; rule of thumb `10500/WPM` |
| Mod fails to fire when chord is intended (intentional roll) | `tapping-term-ms` too low | Increase to 280ms |
| Two same-hand mods don't chord | Missing `hold-trigger-on-release` | Add the flag |
| Repeat backspace doesn't work | `quick-tap-ms` too low or 0 | Set to 150–200ms |

If you change `require-prior-idle-ms`, re-check feel for at least a week — your typing adapts to the timer.

---

<a name="examples"></a>
## Worked examples

### Mod-tap (built-in, override-friendly)

```dts
&mt LSHIFT A       // shift on hold, A on tap (200ms term)

// Override defaults:
&mt {
    tapping-term-ms = <140>;
    quick-tap-ms = <150>;
};
```

### Layer-tap (built-in)

```dts
&lt 1 SPACE        // layer 1 on hold, SPACE on tap

&lt {
    flavor = "balanced";
    tapping-term-ms = <200>;
    quick-tap-ms = <175>;
};
```

### Timeless homerow mod (urob recipe)

```dts
ZMK_HOLD_TAP(hml,
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-on-release;
    hold-trigger-key-positions = <KEYS_R THUMBS>;
    bindings = <&kp>, <&kp>;
)

ZMK_HOLD_TAP(hmr,
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    hold-trigger-on-release;
    hold-trigger-key-positions = <KEYS_L THUMBS>;
    bindings = <&kp>, <&kp>;
)
```

In the base layer:

```dts
&hml LGUI A   &hml LALT S   &hml LCTRL D   &hml LSHIFT F   &kp G
&kp H         &hmr RSHIFT J &hmr LCTRL K   &hmr LALT L     &hmr LGUI SEMI
```

GACS order: GUI on pinky, ALT on ring, Ctrl on middle, Shift on index. (Mirrored on the right; RSHIFT used instead of LSHIFT on the right index to avoid conflicting with OS shortcuts that expect specifically LSHIFT.)

### Auto-shift (case by hold duration)

```dts
ZMK_HOLD_TAP(as,
    flavor = "tap-preferred";
    tapping-term-ms = <135>;
    bindings = <&kp>, <&kp>;
)
#define AS(KEY) &as LS(KEY) KEY
```

Then `AS(Q)` → tap=q, hold=Q. The hold action `LS(KEY)` is shift+key; you supply the keycode once and the macro routes it to both paths.

### Mo-on-hold, tog-on-tap

```dts
ZMK_HOLD_TAP(mo_tog,
    flavor = "hold-preferred";
    tapping-term-ms = <200>;
    bindings = <&mo>, <&tog>;       // different one-param behaviors!
)
#define MO_TOG(L) &mo_tog L L
```

Hold = momentary layer, tap = toggle layer. Note `bindings` uses TWO different behaviors (`&mo` and `&tog`), not the same one — this is legal because both take one parameter.

### Nav cluster with long-press alternates

```dts
#define MT_CORE                                                                \
  flavor = "tap-preferred";                                                    \
  tapping-term-ms = <220>;                                                     \
  quick-tap-ms = <220>;                                                        \
  hold-trigger-key-positions = <0>;                  // placeholder; tap-preferred ignores other keys

&mt { MT_CORE };

ZMK_HOLD_TAP(mt_home, bindings = <&masked_home>, <&kp>; MT_CORE)
ZMK_HOLD_TAP(mt_end,  bindings = <&masked_end>,  <&kp>; MT_CORE)

#define NAV_LEFT   &mt_home 0 LEFT       // tap=LEFT, hold=HOME (masked)
#define NAV_RIGHT  &mt_end  0 RIGHT      // tap=RIGHT, hold=END (masked)
#define NAV_UP     &mt LC(HOME) UP        // tap=UP, hold=Ctrl+HOME (doc start)
#define NAV_DOWN   &mt LC(END)  DOWN
#define NAV_BSPC   &mt LC(BSPC) BSPC      // word-backspace on hold
#define NAV_DEL    &mt LC(DEL)  DEL
```

This is `tap-preferred` because we want hold to mean "deliberately held past 220ms" — rolls produce taps. `hold-trigger-key-positions = <0>` is a placeholder so the property is set (its value doesn't matter when flavor is `tap-preferred`).

---

<a name="gotchas"></a>
## Gotchas

1. **Multi-param behaviors can't be hold-tap bindings.** `bindings = <&bt>, <&kp>;` won't work because `&bt BT_SEL 0` is two-arg. Wrap in a zero-param macro:
   ```dts
   ZMK_MACRO(bt_sel_0, bindings = <&bt BT_SEL 0>;)
   ```
   then use `&bt_sel_0` in the hold-tap's `bindings`.

2. **`quick-tap-ms` semantics.** ZMK: press-to-press of the SAME hold-tap key. QMK: release-to-press. Ported value should be larger in ZMK.

3. **`require-prior-idle-ms` ignores modifiers.** Pressing a modifier doesn't reset the idle timer. This is intentional — you can still chord a mod after typing.

4. **Positional indices follow the matrix transform.** Position N in `hold-trigger-key-positions` corresponds to position N in your layer's `bindings`. If you're not sure, check the shield's `*-layouts.dtsi` or use the named labels from `zmk-helpers/key-labels/<board>.h`.

5. **`retro-tap` is incompatible with mouse behaviors.** Don't combine.

6. **`hold-while-undecided` interaction with combos.** Per docs: "With combo key positions, waits for combo timeouts before immediate hold."

7. **Overriding `&mt`/`&lt` is project-wide.** A bare `&mt { tapping-term-ms = <140>; };` in your keymap changes the value for EVERY `&mt` invocation. If you want different behavior for one specific case, define a separate behavior with a different label.

8. **The flavor name string is American spelling.** `flavor`, not `flavour`. ZMK is strict; British spelling causes "value not in enumeration" parse errors.

9. **`#binding-cells` must match what callers supply.** If you define a hold-tap with `#binding-cells = <2>` but call it as `&my_ht A` (one param), the build will reject it.

10. **`hold-trigger-on-release` with `hold-preferred` flavor doesn't behave as you'd expect.** The interrupt-on-press still happens — `hold-trigger-on-release` only delays the *positional* check. Pair `hold-trigger-on-release` with `balanced` for the intended HRM semantics.
