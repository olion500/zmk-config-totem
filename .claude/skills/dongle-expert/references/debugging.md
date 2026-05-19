# Debugging a Prospector dongle (live serial capture)

When a Prospector dongle pairs but misbehaves — keys missing on one half, perpetual disconnect cycles, LCD widgets stuck — you want to read the dongle's UART log in real time. The dongle exposes that log over a USB CDC ACM interface. Below is how to capture it, what the interface layout looks like, and which log keywords actually mean something.

This reference matches the **carrefinho/prospector-zmk-module on `feat/new-status-screens`** (ZMK main / Zephyr 4.1). Adapt port names as needed.

---

## Step 1 — Enable USB CDC logging in the dongle firmware

Add to the dongle's `.conf` (e.g. `config/<keyboard>_dongle.conf`):

```
CONFIG_ZMK_USB_LOGGING=y
```

That single line is enough — ZMK pulls in `CONFIG_LOG=y`, `CONFIG_LOG_BACKEND_UART=y`, `CONFIG_LOG_BACKEND_UART_AUTOSTART=y` via its own defconfig. `zephyr,console`, `zephyr,shell-uart`, `zephyr,uart-mcumgr` are all chosen to `board_cdc_acm_uart` in the generated `zephyr.dts`.

> Cost: RAM usage jumps ~4 percentage points on a XIAO nRF52840 (≈91% → ≈95%). Stay aware of headroom. Remove the line for the final shipped firmware.

Rebuild dongle only (`just build dongle` or equivalent) — peripherals don't need changes.

---

## Step 2 — Identify the dongle's USB CDC interfaces (Windows)

With `snippet: studio-rpc-usb-uart` on the dongle row, two CDC ACM interfaces are declared in the generated DTS:

```
board_cdc_acm_uart         ← zephyr,console + log backend (MI_00)
snippet_studio_rpc_usb_uart ← ZMK Studio RPC binary channel (MI_03)
```

Windows enumerates them as two separate COM ports. Identify which is which from WSL:

```bash
powershell.exe -Command "Get-WMIObject Win32_PnPEntity | Where-Object {\$_.Name -match 'COM\d+'} | Select-Object Name, DeviceID"
```

Look for `USB\VID_1D50&PID_615E&MI_xx`:

| Interface descriptor | What it is | Use it for |
|---|---|---|
| `MI_00` | `board_cdc_acm_uart` | **Logging — open this one** |
| `MI_03` | `snippet_studio_rpc_usb_uart` | Studio RPC (binary, silent unless a Studio client requests) |

> The MI numbering depends on Zephyr's USB descriptor build order; if your snippet list is different, regenerate this table by reading the `chosen` block in `.build/<dongle>/zephyr/zephyr.dts`. Look for which `cdc_acm_uart` node is bound to `zephyr,console` — that one is logging.

---

## Step 3 — Capture from WSL (no PuTTY needed)

PowerShell's `System.IO.Ports.SerialPort` is available from `powershell.exe` in WSL. No serial client install required.

### One-shot read (immediate buffer)

```bash
powershell.exe -Command "
\$port = New-Object System.IO.Ports.SerialPort 'COM13', 115200, 'None', 8, 'One'
\$port.ReadTimeout = 500
try {
  \$port.Open()
  Start-Sleep -Milliseconds 200
  \$port.ReadExisting()
} finally {
  if (\$port.IsOpen) { \$port.Close() }
}
"
```

Use this to grab whatever is already buffered (typically the boot banner if the dongle booted recently, otherwise empty).

### Streamed capture (loop, ~10s)

```bash
powershell.exe -Command "
\$port = New-Object System.IO.Ports.SerialPort 'COM13', 115200, 'None', 8, 'One'
\$port.ReadTimeout = 100
try {
  \$port.Open()
  \$sb = New-Object System.Text.StringBuilder
  for (\$i = 0; \$i -lt 100; \$i++) {
    Start-Sleep -Milliseconds 100
    \$d = \$port.ReadExisting()
    if (\$d) { [void]\$sb.Append(\$d) }
  }
  \$sb.ToString()
} finally {
  if (\$port.IsOpen) { \$port.Close() }
}
"
```

Tune the `100` loop count for longer captures. Use this when you want the user to press keys / wait for an event while you watch.

> **Speed argument (`115200`) is ignored** on USB CDC ACM — there's no real UART speed. Any value works. Use it for parity with traditional serial UX.

> **Buffer caveat**: USB CDC backs up if nothing is reading. If logs are very chatty (e.g., ALS errors at 100ms) and your client opens/closes briefly between reads, you may miss messages. Keep the capture loop running for the duration of the test, or use a continuous client (PuTTY, `tio`, Windows Terminal serial profile) for long debug sessions.

---

## Step 4 — Read the log

Severity colors are wrapped in ANSI codes (`<inf>`, `<wrn>`, `<err>`, `<dbg>`). They show up regardless of terminal — just ignore the escape sequences if your viewer is plain text.

### Boot sequence (healthy dongle, fresh boot)

```
<err> qspi_nor: JEDEC id [68 40 15] expect [85 60 15]   ← XIAO BLE flash chip mismatch, harmless
<inf> bt_hci_core: HW Variant: nRF52x
<inf> bt_hci_core: No ID address. App must call settings_load()
<inf> display_st7789v: Changed orientation t...         ← LCD init
*** Booting Zephyr OS build ... ***
<wrn> zmk: Have N combos!                                ← keymap loaded
```

After this, expect quiet until peripherals advertise. The dongle scans continuously.

### Pairing / connection establishment

```
<dbg> zmk: start_scanning: Scanning successfully started
<dbg> zmk: split_central_battery_level_notify_func: Battery level: 88   ← peripheral attached, notify channel open
<dbg> zmk: peripheral_event_work_callback: Trigger key position state change of type N
```

The `type N` enum (in `zmk/app/include/zmk/split/transport/types.h`):

| N | Meaning |
|---|---|
| `0` | KEY_POSITION — actual key press/release |
| `1` | SENSOR — encoder rotation, etc. |
| `2` | INPUT — pointing/scroll events |
| `3` | BATTERY — periodic level notify |

If you only ever see `type 3` events from a slot, that peripheral's **connection is up but its keymap subscription never got set up properly**. The fix is almost always a full settings_reset cycle on all three boards.

### Disconnect & reason codes

```
<dbg> zmk: split_central_disconnected: Disconnected: D4:A1:D4:EC:18:E3 (random) (reason 8)
<dbg> zmk: release_peripheral_slot: Releasing peripheral slot at 0
<dbg> zmk: start_scanning: Scanning successfully started
```

`reason` is a Bluetooth HCI error code. Common ones:

| Code | Meaning | Likely cause |
|---|---|---|
| `0x08` | CONN_TIMEOUT (supervision timeout) | Peripheral stopped sending packets long enough that the link supervisor gave up. Either the peripheral ran out of CPU/work-queue time, OR the dongle did. ALS error storms can produce this. |
| `0x13` | REMOTE_USER_TERM | Peripheral chose to disconnect (reset, going to sleep). |
| `0x16` | LOCAL_HOST_TERM | Dongle initiated. Almost always means an internal error. |
| `0x3E` | UNACCEPTABLE_CONN_INTERVAL | Connection parameters incompatible. Check `CONFIG_ZMK_SPLIT_BLE_PREF_INT/LATENCY/TIMEOUT` if you've tuned them. |

A `reason 0x08` repeating every ~14 seconds on BOTH peripherals usually means the dongle is overloaded (look for a tight error loop above the disconnect).

### Slot index assignment

```
<dbg> zmk: reserve_peripheral_slot: ...      ← BLE-address-based slot reservation
```

ZMK assigns peripheral slots **in pairing order based on BLE address**. There is NO `CONFIG_ZMK_SPLIT_BLE_PERIPHERAL_ID` Kconfig — peripherals are not numbered or labeled at build time. Slot 0 = whichever half the dongle paired with first after settings_reset. Slot 1 = second.

This is why "flash dongle, then LEFT, then RIGHT" matters for the LCD battery widget — slots are determined by pairing order, not by hardware identity. If the battery indicators look swapped vs the keyboard's physical layout, do a settings_reset on the two halves and re-pair in the correct order.

---

## Symptom → first suspect map

Use this when you can read the log but don't want to study every line.

| Symptom in log | First suspect |
|---|---|
| `<err> APDS9960: Power on bit not set` (repeating 100ms) | ALS chip not responding. Set `CONFIG_PROSPECTOR_USE_AMBIENT_LIGHT_SENSOR=n`. |
| `<err> qspi_nor: JEDEC id mismatch` only | XIAO BLE flash chip variant — harmless, ignore. |
| Disconnect (`reason 0x08`) every ~14s, both peripherals together | Dongle work queue saturated. Check for tight error loops (ALS, sensor, I²C). |
| `Battery level: N` notify but never `Trigger key position state change of type 0` | GATT keymap subscription incomplete on that peripheral. **Full settings_reset on all three boards.** |
| `LCD shows perpetual red X for one slot` (no log activity for that peripheral) | That peripheral never advertised — likely built without `CONFIG_ZMK_BLE` (wrong board variant — must be `xiao_ble/nrf52840/zmk`). |
| Boot log stops mid-line then nothing | RAM exhaustion. Check `.build/.../zephyr/.config` for RAM headroom — drop `CONFIG_ZMK_USB_LOGGING` or unused widgets. |
| Boot log + `start_scanning` but no peripheral ever connects, even fresh pairing | Peripheral side issue. Pull the half's `.uf2`, verify `CONFIG_ZMK_SPLIT_BLE=y`. If missing, the half was built against `xiao_ble` instead of `xiao_ble/nrf52840/zmk`. |

---

## After debugging — turn logging off

When the dongle is working and shipping:

1. Remove `CONFIG_ZMK_USB_LOGGING=y` from the dongle conf.
2. Rebuild dongle.
3. Flash dongle only — peripherals untouched, no settings_reset needed (BLE bonds survive logging on/off).

The dropped RAM (~95% → ~91%) gives the LCD widgets more headroom and removes any chance of CDC backpressure under unread serial.
