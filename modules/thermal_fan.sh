#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Thermal & Fan Controller]"
sync

HWMON_DIR="${DECKDOC_HWMON_DIR:-/sys/class/hwmon}"

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
                    max_file="${input%_input}_max"
                    crit_file="${input%_input}_crit"
                    max_raw=""; crit_raw=""
                    [ -r "$max_file" ] && max_raw=$(cat "$max_file")
                    [ -r "$crit_file" ] && crit_raw=$(cat "$crit_file")
                    if [ -n "$max_raw" ]; then echo "  High threshold: $(awk "BEGIN {print $max_raw/1000}") C"; fi
                    if [ -n "$crit_raw" ]; then echo "  Critical threshold: $(awk "BEGIN {print $crit_raw/1000}") C"; fi
                    # A hard-coded 90 C is not a hardware trip point. Compare to
                    # the sensor's own exported threshold when present; otherwise
                    # retain a high-temperature observation without claiming a trip.
                    if [ -n "$crit_raw" ] && [ "$temp_raw" -ge "$crit_raw" ]; then
                        echo "  CRITICAL: Sensor is at or above its exported critical threshold."
                    elif [ -n "$max_raw" ] && [ "$temp_raw" -ge "$max_raw" ]; then
                        echo "  WARNING: Sensor is at or above its exported high threshold."
                    elif [ -z "$crit_raw" ] && [ "$temp_raw" -ge 90000 ]; then
                        echo "  WARNING: Temperature is above 90 C; this sensor exposes no hardware critical threshold."
                    fi
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
