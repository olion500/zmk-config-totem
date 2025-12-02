# Using zmk-helpers in this repo

- Install helpers via `west update` (already listed in `config/west.yml` as `zmk-helpers`).
- Include the header after `behaviors.dtsi`: `#include "zmk-helpers/helper.h"` in `.keymap` files.
- Define behaviors with macros instead of manual DT nodes, e.g. `ZMK_HOLD_TAP(name, ...)`, `ZMK_TAP_DANCE(name, ...)`, `ZMK_MACRO(...)`.
- Declare conditional/tri-layer logic with `ZMK_CONDITIONAL_LAYER(name, if_layers, then_layer)`.
- Layers can also be declared with `ZMK_LAYER(name, bindings)` if desired.
- Keep custom settings inside the macro body (flavor, tapping/quick-tap, hold-trigger keys, etc.).
