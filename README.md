# TOTEM Wireless Manual

## Power & Modes

The TOTEM Wireless keyboard can be powered either by **USB-C cable** or **internal battery**.

### 🔋 Battery Power

* Slide the power switch **to the right** to turn on battery power.
* The two halves automatically pair when both are powered.

### 🔌 Wired Mode (USB)

* Connect the **left half** to your device via USB-C to use the keyboard in wired mode.

### 📡 Wireless Mode (Bluetooth)

* Turn on the power switch on the **left half**.
* No cable connection is needed.

### 🔋 Charging the Battery

* Connect a USB-C cable and keep the power switch **ON** while charging.
* ⚠️ The power switch controls **battery power only**.
  → The keyboard still works over USB even if the switch is OFF.

---

## Bluetooth

### 📱 Connecting

* In wireless mode, search for **“TOTEM”** in your device’s Bluetooth settings and pair it.

### 🔄 Bluetooth Profile Controls

* **BT 0–4** — Switch between Bluetooth profiles
* **BT CLR** — Clear/reset the current profile
  (See the Keymap section for key locations.)

---

## Keymap

### 🧩 Default Keymap

The default layout looks like the following:

<img width="956" height="1515" alt="image" src="https://github.com/user-attachments/assets/e35df960-6e23-47d8-93d8-0d4563873e23" />


### 🔁 Restore Default Keymap

If your TOTEM did not ship with this firmware, or you want to restore the original layout:

👉 Download the firmware here:
[https://github.com/Keycoon/zmk-config-totem](https://github.com/Keycoon/zmk-config-totem)
(GitHub sign-in required)

Then follow **Step 7 (Flash)** below to install it.

---

## Customization

You can customize your TOTEM keyboard in two ways.

---

## 1) ZMK Studio — Easy Live Keymap Editing

ZMK Studio offers a visual editor for adjusting your keymap.

🔗 [https://zmk.studio](https://zmk.studio)

> ⚠️ ZMK Studio is still under development and does not support all ZMK features.
> For advanced customizations, use the method below.

---

## 2) Full Customization — Build & Flash Your Own Firmware

Use this method if you want full access to ZMK behaviors, advanced features, or deeper customization.

---

## Step-by-Step Guide

### **1. Create a GitHub Account (if you don’t have one)**

[https://github.com](https://github.com)

* GitHub is required to store your configuration and build firmware using GitHub Actions.

---

### **2. Fork the TOTEM Firmware Config Repository**

[https://github.com/Keycoon/zmk-config-totem](https://github.com/Keycoon/zmk-config-totem)

* Click **“Fork”** in the top-right corner
* This creates your own editable copy of the configuration repository

---

### **3. Open the Keymap Editor**

[https://nickcoutsos.github.io/keymap-editor/](https://nickcoutsos.github.io/keymap-editor/)

* Connect your GitHub account
* Select your forked repository

---

### **4. Edit Your Keymap**

* Modify layers, key bindings, and advanced ZMK behaviors
* Reference official ZMK documentation:
  [https://zmk.dev/docs/keymaps/behaviors](https://zmk.dev/docs/keymaps/behaviors)

---

### **5. Save Your Changes**

* Click **“Save”** at the top of the editor
* This will automatically trigger a firmware build through GitHub Actions

---

### **6. Download the Compiled Firmware**

* Go to your GitHub repository → **Actions** tab
* Open the latest workflow run
* Download the `.uf2` firmware files

(You can also use the download button in the editor.)

---

### **7. Flash the Firmware**

1. Connect the keyboard via USB-C
2. Double-press the reset button on the top side
3. A USB drive will appear on your device
4. Drag the appropriate `.uf2` file onto the drive
5. The keyboard will flash and reboot automatically

> Flashing the **left half** is usually enough.
> Flash both halves if certain changes don’t take effect.
