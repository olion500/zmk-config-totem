# ZMK Keycode Reference

Source: `#include <dt-bindings/zmk/keys.h>`.

Spelling matters — typos produce "elusive parsing errors." When in doubt, prefer the long form.

## Letters and numbers

- Letters `A` through `Z` (uppercase constants; case-insensitive in source).
- Numbers `NUMBER_1` ... `NUMBER_0`, or short forms `N1` ... `N0`.
- Tilde sorts NUMBER_0 last like the keyboard row (so `N1 N2 ... N9 N0`).

## Modifiers

| Long form | Short forms |
|---|---|
| `LEFT_SHIFT` | `LSHIFT`, `LSHFT` |
| `RIGHT_SHIFT` | `RSHIFT`, `RSHFT` |
| `LEFT_CONTROL` | `LCTRL` |
| `RIGHT_CONTROL` | `RCTRL` |
| `LEFT_ALT` | `LALT` |
| `RIGHT_ALT` | `RALT` |
| `LEFT_GUI` | `LGUI`, `LEFT_WIN`, `LWIN`, `LEFT_COMMAND`, `LCMD` |
| `RIGHT_GUI` | `RGUI`, `RIGHT_WIN`, `RWIN`, `RIGHT_COMMAND`, `RCMD` |

## Modifier-wrapper macros

Apply a modifier to a keycode. Composable.

- `LS(code)` / `RS(code)` — left/right Shift
- `LC(code)` / `RC(code)` — left/right Control
- `LA(code)` / `RA(code)` — left/right Alt
- `LG(code)` / `RG(code)` — left/right GUI

Examples:
- `LC(C)` — Ctrl+C
- `LS(LC(A))` — Ctrl+Shift+A
- `LA(F4)` — Alt+F4
- `LG(LC(LEFT))` — Win/Cmd+Ctrl+Left (Windows: previous desktop)

## Function keys

`F1` ... `F24`.

## Navigation

- `HOME`, `END`
- `PAGE_UP` / `PG_UP`
- `PAGE_DOWN` / `PG_DN`
- `UP_ARROW` / `UP`
- `DOWN_ARROW` / `DOWN`
- `LEFT_ARROW` / `LEFT`
- `RIGHT_ARROW` / `RIGHT`

## Editing / control

| Long | Short |
|---|---|
| `ESCAPE` | `ESC` |
| `RETURN` / `ENTER` | `RET` |
| `TAB` | — |
| `BACKSPACE` | `BSPC` |
| `DELETE` | `DEL` |
| `INSERT` | `INS` |
| `CAPSLOCK` | `CAPS` |
| `SCROLLLOCK` | `SLCK` |
| `PAUSE_BREAK` | `PAUSE` |
| `PRINTSCREEN` | `PSCRN` |
| `SPACE` | — |

## Symbols (US layout)

These are direct keycodes — i.e. `EXCLAMATION` is the same physical key as `N1`, but already shifted. So `&kp EXCL` sends Shift+1 in one keystroke.

| Long form | Short form | Sends |
|---|---|---|
| `GRAVE` | — | `` ` `` |
| `MINUS` | — | `-` |
| `EQUAL` | — | `=` |
| `PLUS` | — | `+` |
| `UNDERSCORE` | `UNDER` | `_` |
| `LEFT_BRACKET` | `LBKT` | `[` |
| `RIGHT_BRACKET` | `RBKT` | `]` |
| `LEFT_BRACE` | `LBRC` | `{` |
| `RIGHT_BRACE` | `RBRC` | `}` |
| `LEFT_PARENTHESIS` | `LPAR` | `(` |
| `RIGHT_PARENTHESIS` | `RPAR` | `)` |
| `BACKSLASH` | `BSLH` | `\` |
| `PIPE` | — | `|` |
| `SEMICOLON` | `SEMI` | `;` |
| `COLON` | — | `:` |
| `SINGLE_QUOTE` / `APOSTROPHE` | `SQT`, `APOS` | `'` |
| `DOUBLE_QUOTES` | `DQT` | `"` |
| `COMMA` | — | `,` |
| `PERIOD` | `DOT` | `.` |
| `SLASH` | `FSLH` | `/` |
| `QUESTION` | `QMARK` | `?` |
| `LESS_THAN` | `LT` | `<` |
| `GREATER_THAN` | `GT` | `>` |
| `EXCLAMATION` | `EXCL` | `!` |
| `AT_SIGN` | `AT` | `@` |
| `HASH` / `POUND` | — | `#` |
| `DOLLAR` | `DLLR` | `$` |
| `PERCENT` | `PRCNT` | `%` |
| `CARET` | — | `^` |
| `AMPERSAND` | `AMPS` | `&` |
| `ASTERISK` | `STAR` | `*` |
| `TILDE` | — | `~` |

> Note: `LT` is BOTH a keycode (less-than `<`) AND a behavior name (`&lt` layer-tap). They live in different namespaces — `&lt 1 SPACE` works fine. But when defining `#define`s, don't shadow either.

## Keypad

`KP_NUMLOCK` / `KP_NUM`, `KP_ENTER`, `KP_NUMBER_0` / `KP_N0` ... `KP_NUMBER_9` / `KP_N9`, `KP_PLUS`, `KP_MINUS`, `KP_MULTIPLY`, `KP_DIVIDE`, `KP_DOT`, `KP_EQUAL`.

## Media (HID Consumer page)

These are different from regular keys (they live on the HID Consumer page, not Keyboard page). `&key_repeat` doesn't capture them by default — use `ZMK_KEY_REPEAT` with `usage-pages = <HID_USAGE_KEY HID_USAGE_CONSUMER>;`.

| Long | Short |
|---|---|
| `C_VOLUME_UP` | `C_VOL_UP` |
| `C_VOLUME_DOWN` | `C_VOL_DN` |
| `C_MUTE` | — |
| `C_PLAY_PAUSE` | `C_PP` |
| `C_NEXT` | — |
| `C_PREVIOUS` | `C_PREV` |
| `C_STOP` | — |
| `C_FAST_FORWARD` | `C_FF` |
| `C_REWIND` | `C_RW` |
| `C_BRIGHTNESS_INC` | — |
| `C_BRIGHTNESS_DEC` | — |
| `C_BRIGHTNESS_AUTO` | — |
| `C_MEDIA_HOME` | — |
| `C_AC_SEARCH` | — |
| `C_AC_REFRESH` | — |

## Locks / IME

- `CAPSLOCK` / `CAPS`
- `NUMLOCK` / `NUM`
- `SCROLLLOCK` / `SLCK`
- `K_LANG1`, `K_LANG2` — IME language switch (e.g. Japanese 한/한자 keys)

## Special

- `K_CANCEL` — used by urob's auto-layers as a "cancel everything" trigger
- `K_APP` / `K_MENU` — application/context-menu key
- `K_POWER`, `K_SLEEP`, `K_WAKE`, `K_HELP`

## Bluetooth (require `<dt-bindings/zmk/bt.h>`)

- `BT_CLR` — clear current profile
- `BT_CLR_ALL` — clear all profiles
- `BT_NXT` — next profile (wraps)
- `BT_PRV` — previous profile (wraps)
- `BT_SEL <n>` — select profile n (0-4)
- `BT_DISC <n>` — disconnect profile n

```dts
&bt BT_SEL 0
&bt BT_CLR
```

## Output selection (require `<dt-bindings/zmk/outputs.h>`)

- `OUT_USB`, `OUT_BLE`, `OUT_TOG`, `OUT_NONE`

```dts
&out OUT_TOG
```

## Mouse (require `<dt-bindings/zmk/pointing.h>`, ZMK with pointing support)

- `MOVE_UP` / `MOVE_DOWN` / `MOVE_LEFT` / `MOVE_RIGHT` — for `&mmv`
- `SCRL_UP` / `SCRL_DOWN` / `SCRL_LEFT` / `SCRL_RIGHT` — for `&msc`
- `LCLK`, `RCLK`, `MCLK`, `MB4`, `MB5` — for `&mkp`

```dts
&mmv MOVE_UP
&mkp LCLK
&msc SCRL_DOWN
```

## RGB underglow (require `<dt-bindings/zmk/rgb.h>`)

- `RGB_TOG` — toggle
- `RGB_HUI` / `RGB_HUD` — hue inc/dec
- `RGB_SAI` / `RGB_SAD` — saturation
- `RGB_BRI` / `RGB_BRD` — brightness
- `RGB_SPI` / `RGB_SPD` — speed
- `RGB_EFF` / `RGB_EFR` — effect forward/reverse
- `RGB_COLOR_HSB(h, s, b)` — set explicit color

```dts
&rgb_ug RGB_TOG
&rgb_ug RGB_COLOR_HSB(240, 50, 100)
```

## Common typos and gotchas

| Written | Should be |
|---|---|
| `BCKSP`, `BKSP`, `BSP` | `BSPC` |
| `ENTR`, `ENTER1` | `ENTER` or `RET` |
| `SEMICOLON_KEY`, `SCLN` (QMK) | `SEMI` |
| `LSHIFT_KEY`, `SHIFT_L` | `LSHIFT` |
| `LCTL` (QMK) | `LCTRL` |
| `LCMD_KEY` | `LCMD` or `LGUI` |
| `MINS` (QMK) | `MINUS` |
| `EQL` (QMK) | `EQUAL` |
| `flavour` (British) | `flavor` |

Coming from QMK keymaps, double-check every keycode constant against this list.
