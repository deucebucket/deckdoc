#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Thermal & Fan Controller]"
sync

HWMON_DIR="/sys/class/hwmon"

if [ -d "$HWMON_DIR" ]; then
    for hwmon in "$HWMON_DIR"/hwmon*; do
        if [ -f "${hwmon}/name" ]; then
            name=$(cat "${hwmon}/name")
            echo "Sensor: ${name} (${hwmon})"
            
            for input in "${hwmon}"/temp*_input; do
                if [ -f "$input" ]; then
                    temp_raw=$(cat "$input")
                    temp_c=$(awk "BEGIN {print $temp_raw/1000}")
                    label_file="${input%_input}_label"
                    label="Unknown"
                    [ -f "$label_file" ] && label=$(cat "$label_file")
                    echo "  Temp (${label}): ${temp_c} C"
                    awk "BEGIN {if ($temp_c > 90.0) exit 0; exit 1}" && echo "  CRITICAL: Thermal Trip Point Exceeded (>90C)."
                fi
            done
            sync
            
            for fan in "${hwmon}"/fan*_input; do
                if [ -f "$fan" ]; then
                    rpm=$(cat "$fan")
                    label_file="${fan%_input}_label"
                    label="Fan"
                    [ -f "$label_file" ] && label=$(cat "$label_file")
                    echo "  ${label} RPM: ${rpm}"
                    if [ "$rpm" -eq 0 ]; then
                        echo "  WARNING: Fan RPM is 0."
                    fi
                fi
            done
            sync
        fi
    done
else
    echo "CRITICAL: /sys/class/hwmon/ not found."
fi
sync
