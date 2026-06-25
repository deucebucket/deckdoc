#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Battery IC & PMIC]"
sync

BAT_DIR="/sys/class/power_supply/BAT1"

if [ ! -d "$BAT_DIR" ]; then
    BAT_DIR="/sys/class/power_supply/BAT0"
fi

if [ -d "$BAT_DIR" ]; then
    for node in status capacity voltage_now current_now charge_now charge_full charge_full_design energy_now energy_full; do
        if [ -f "${BAT_DIR}/${node}" ]; then
            val=$(cat "${BAT_DIR}/${node}")
            echo "${node}: ${val}"
            
            if [ "$node" == "voltage_now" ]; then
                volts=$(awk "BEGIN {print $val/1000000}")
                echo "Calculated Voltage: ${volts} V"
                awk "BEGIN {if ($volts < 6.6) exit 0; exit 1}" && echo "CRITICAL: Voltage below 6.6V threshold."
            fi
            sync
        fi
    done
else
    echo "CRITICAL: No battery interface found in /sys/class/power_supply/"
fi
sync
