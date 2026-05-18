default:
    @just --list --unsorted

config := justfile_directory() / 'config'
build := justfile_directory() / '.build'
out := justfile_directory() / 'firmware'
draw := justfile_directory() / 'draw'
keymap := config / 'totem.keymap'

# parse build.yaml and filter targets by expression
_parse_targets $expr:
    #!/usr/bin/env bash
    attrs="[.board, .shield, .snippet, .\"artifact-name\"]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" build.yaml | grep -v "^," | grep -i "${expr/#all/.*}")"

# build firmware for single board & shield combination
_build_single $board $shield $snippet $artifact *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board}}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# build firmware for matching targets
build expr='all' *west_args: draw
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet artifact; do
        just _build_single "$board" "$shield" "$snippet" "$artifact" {{ west_args }}
    done

# clear build cache and artifacts
clean:
    rm -rf {{ build }} {{ out }}

# clear all automatically generated files
clean-all: clean
    rm -rf .west zmk

# clear nix cache
clean-nix:
    nix-collect-garbage --delete-old

# parse & plot keymap
draw:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ -f "{{ keymap }}" ]] || { echo "Missing keymap at {{ keymap }}"; exit 1; }
    [[ -f "{{ draw }}/config.yaml" ]] || { echo "Missing draw/config.yaml"; exit 1; }
    keymap -c "{{ draw }}/config.yaml" parse -z "{{ keymap }}" --virtual-layers Combos >"{{ draw }}/totem.yaml"
    yq -Yi '.combos.[].l = ["Combos"]' "{{ draw }}/totem.yaml"
    keymap -c "{{ draw }}/config.yaml" draw "{{ draw }}/totem.yaml" -d "{{ config / 'boards/shields/totem/totem-layouts.dtsi' }}" >"{{ draw }}/totem.svg"

# flash firmware to the keyboard (autodetects UF2 bootloader drive)
# usage: `just flash` (= left)  |  `just flash left`  |  `just flash right`
flash side='left':
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="totem_{{ side }}-xiao_ble"
    uf2="{{ out }}/${artifact}.uf2"
    [[ -f "$uf2" ]] || { echo "Missing $uf2 — run 'just build' first." >&2; exit 1; }

    echo "Looking for UF2 bootloader drive..."

    # 1) cheap path: maybe WSL already auto-mounted it under /mnt/*
    for d in /mnt/*; do
        [[ -d "$d" && -f "$d/INFO_UF2.TXT" ]] || continue
        echo "Found bootloader at $d"
        cp -v "$uf2" "$d/"
        echo "Keyboard should reflash and reboot automatically."
        exit 0
    done

    # 2) fallback: ask Windows directly via PowerShell (USB removables often miss /mnt)
    if command -v powershell.exe >/dev/null 2>&1; then
        win_drive=$(powershell.exe -NoProfile -Command \
            "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' | ForEach-Object { if (Test-Path (Join-Path \$_.DeviceID 'INFO_UF2.TXT')) { Write-Output \$_.DeviceID } }" \
            2>/dev/null | tr -d '\r\n ' | head -c 2 || true)
        if [[ -n "$win_drive" ]]; then
            echo "Found bootloader at $win_drive (via Windows)"
            win_uf2=$(wslpath -w "$uf2")
            powershell.exe -NoProfile -Command "Copy-Item -Force '$win_uf2' '${win_drive}\\'" >/dev/null
            echo "Copied $(basename "$uf2") -> ${win_drive}\\"
            echo "Keyboard should reflash and reboot automatically."
            exit 0
        fi
    fi

    echo "No UF2 bootloader drive found." >&2
    echo "Tip: double-press the reset button on the {{ side }} half, then re-run." >&2
    exit 1

# diagnose common issues with build/flash/connection setup
doctor:
    #!/usr/bin/env bash
    set +e  # collect all problems, don't bail on first
    ok()    { printf "  \033[32m[ OK ]\033[0m %s\n" "$1"; }
    warn()  { printf "  \033[33m[WARN]\033[0m %s\n" "$1"; }
    fail()  { printf "  \033[31m[FAIL]\033[0m %s\n" "$1"; }
    sec()   { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }

    sec "Environment"
    if [[ -n "${IN_NIX_SHELL:-}" ]]; then ok "Nix shell active (${IN_NIX_SHELL})"
    else warn "Not in a Nix shell — direnv may not be active. Run: direnv allow"; fi
    for c in just west keymap yq prek powershell.exe; do
        if command -v "$c" >/dev/null 2>&1; then ok "$c"
        else
            case "$c" in
                powershell.exe) warn "$c not found — Windows-side checks will be skipped";;
                *) fail "$c not found";;
            esac
        fi
    done

    sec "Repository state"
    for f in config/totem.keymap config/combos.dtsi config/totem_defs.dtsi config/totem.conf config/west.yml build.yaml .pre-commit-config.yaml; do
        [[ -f "$f" ]] && ok "$f" || fail "$f missing"
    done
    [[ -d zmk ]]                 && ok "zmk checkout present"        || warn "zmk missing — run 'just init'"
    [[ -d modules/zmk/helpers ]] && ok "zmk-helpers module present"  || warn "zmk-helpers missing — run 'just init'"

    sec "Config sanity"
    typos=$(grep -nE '\b(BCKSPC|BCKSP|BKSP|flavour|colour|behaviour)\b' config/*.keymap config/*.dtsi 2>/dev/null)
    if [[ -n "$typos" ]]; then fail "Common ZMK typos:"; printf '%s\n' "$typos" | sed 's/^/        /'
    else ok "No common ZMK typos in keymap/dtsi files"; fi

    if grep -rq "zmk,battery" config/boards/shields/totem/ 2>/dev/null; then ok "Battery sensor defined in shield"
    else warn "No zmk,battery node in shield — battery level won't be reported via BLE"; fi

    if grep -q "^CONFIG_ZMK_STUDIO=y" config/totem.conf 2>/dev/null; then ok "ZMK Studio enabled"
    else warn "ZMK Studio not enabled (CONFIG_ZMK_STUDIO=y missing)"; fi

    sec "Build artifacts"
    for art in totem_left-xiao_ble totem_right-xiao_ble; do
        f="firmware/${art}.uf2"
        if [[ -f "$f" ]]; then
            age=$(( $(date +%s) - $(stat -c %Y "$f") ))
            if [[ $age -lt 86400 ]]; then ok "$f ($((age/60)) min old)"
            else warn "$f is $((age/86400)) day(s) old — consider 'just build'"; fi
        else warn "$f missing — run 'just build'"; fi
    done

    sec "Pre-commit (prek)"
    if [[ -f .git/hooks/pre-commit ]] && grep -q "prek\|pre-commit" .git/hooks/pre-commit 2>/dev/null; then ok "git hook installed"
    else warn "pre-commit git hook not installed — run 'prek install'"; fi

    sec "Hardware (Windows side, via WSL)"
    if ! command -v powershell.exe >/dev/null 2>&1; then
        warn "powershell.exe not available — skipping Windows checks"
    else
        bt=$(powershell.exe -NoProfile -Command "Get-PnpDevice -Class Bluetooth -PresentOnly | Where-Object { \$_.FriendlyName -like '*Adapter*' -and \$_.Status -eq 'OK' } | Select-Object -First 1 -ExpandProperty FriendlyName" 2>/dev/null | tr -d '\r\n')
        [[ -n "$bt" ]] && ok "BT adapter active: $bt" || fail "No active BT adapter"

        boot=$(powershell.exe -NoProfile -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' | Where-Object { Test-Path (Join-Path \$_.DeviceID 'INFO_UF2.TXT') } | Select-Object -First 1 -ExpandProperty DeviceID" 2>/dev/null | tr -d '\r\n')
        if [[ -n "$boot" ]]; then ok "UF2 bootloader mounted at $boot — ready to 'just flash'"
        else warn "No UF2 bootloader drive (normal unless flashing right now)"; fi

        totem_bt=$(powershell.exe -NoProfile -Command "Get-PnpDevice -Class Bluetooth -PresentOnly | Where-Object { \$_.FriendlyName -like '*TOTEM*' } | Select-Object -First 1 -ExpandProperty Status" 2>/dev/null | tr -d '\r\n')
        if [[ -n "$totem_bt" ]]; then ok "TOTEM paired via Bluetooth (Status: $totem_bt)"
        else warn "TOTEM not currently paired via Bluetooth on this PC"; fi
    fi

    sec "Done"
    echo "  Anything marked [FAIL] needs fixing. [WARN] is informational — fix if relevant."

# open current repo in Windows Explorer (WSL)
open:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v explorer.exe >/dev/null 2>&1; then
        echo "explorer.exe not found (WSL-only helper)"; exit 1
    fi
    explorer.exe "$(wslpath -w "{{ justfile_directory() }}")"

# initialize west
init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -d ".west" ]]; then
        echo ".west already present, running west update/zephyr-export instead."
        west update --fetch-opt=--filter=blob:none
        west zephyr-export
    else
        west init -l config
        west update --fetch-opt=--filter=blob:none
        west zephyr-export
    fi

# list build targets
list:
    @just _parse_targets all | sed 's/,*$//' | sort | column

# show key position diagram and aliases
keys:
	#!/usr/bin/env bash
	set -euo pipefail
	cat <<-'EOF'
		Key position layout (38-key):

		    ╭─────────────────────┬─────────────────────╮
		    │ LT4 LT3 LT2 LT1 LT0 │ RT0 RT1 RT2 RT3 RT4 │
		 ╭──╯ LM4 LM3 LM2 LM1 LM0 │ RM0 RM1 RM2 RM3 RM4 ╰───╮
		 │LB5 LB4 LB3 LB2 LB1 LB0 │ RB0 RB1 RB2 RB3 RB4 RB5 │
		 ╰──────────╮ LH2 LH1 LH0 │ RH0 RH1 RH2 ╭───────────╯

	EOF

# update west
update:
    west update --fetch-opt=--filter=blob:none

# upgrade zephyr-sdk and python dependencies
upgrade-sdk:
    nix flake update --flake .

[no-cd]
test $testpath *FLAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    testcase=$(basename "$testpath")
    build_dir="{{ build / "tests" / '$testcase' }}"
    config_dir="{{ '$(pwd)' / '$testpath' }}"
    cd {{ justfile_directory() }}

    if [[ "{{ FLAGS }}" != *"--no-build"* ]]; then
        echo "Running $testcase..."
        rm -rf "$build_dir"
        west build -s zmk/app -d "$build_dir" -b native_posix_64 -- \
            -DCONFIG_ASSERT=y -DZMK_CONFIG="$config_dir"
    fi

    ${build_dir}/zephyr/zmk.exe | sed -e "s/.*> //" |
        tee ${build_dir}/keycode_events.full.log |
        sed -n -f ${config_dir}/events.patterns > ${build_dir}/keycode_events.log
    if [[ "{{ FLAGS }}" == *"--verbose"* ]]; then
        cat ${build_dir}/keycode_events.log
    fi

    if [[ "{{ FLAGS }}" == *"--auto-accept"* ]]; then
        cp ${build_dir}/keycode_events.log ${config_dir}/keycode_events.snapshot
    fi
    diff -auZ ${config_dir}/keycode_events.snapshot ${build_dir}/keycode_events.log
