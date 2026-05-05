#!/usr/bin/env python3
import glob
import os
import sys


def get_content(path):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except:
        return ""


def find_best_temp_input(hwmon_path):
    """
    Finds the best temperature input file in a hwmon directory.
    Prioritizes labeled inputs (Package, Tdie, Edge).
    """
    candidates = {}  # path -> score

    # Get all temp inputs
    input_files = glob.glob(os.path.join(hwmon_path, "temp*_input"))

    if not input_files:
        return None

    for input_path in input_files:
        base = input_path.replace("_input", "")
        label_path = base + "_label"
        label = get_content(label_path).lower()

        score = 1  # Default score for existing input

        # Prioritize based on label
        if "package" in label:
            score = 20
        elif "tdie" in label:
            score = 20
        elif "tctl" in label:
            score = 15  # Tctl is often offset, but better than random
        elif "edge" in label:
            score = 15  # GPU edge is standard
        elif "junction" in label:
            score = 10
        elif "composite" in label:
            score = 10
        elif "core" in label:
            score = 5  # Specific cores are less useful than package
        elif "cpu" in label:
            score = 8  # Generic CPU label
        elif "temp" in label or label == "":
            score = 2  # Generic temp, better than nothing

        # Sanity check: ensure the file is readable and has a valid value
        try:
            val_str = get_content(input_path)
            if not val_str:
                continue
            val = int(val_str)
            if val <= 0:
                continue  # Ignore 0 or negative
        except:
            continue

        candidates[input_path] = score

    if not candidates:
        return None

    # Return the path with the highest score
    best_path = None
    best_score = -1
    for path, score in candidates.items():
        if score > best_score:
            best_score = score
            best_path = path

    return best_path


def detect():
    cpu_path = None
    gpu_path = None

    # 1. Scan HWMON (Preferred)
    # Sort to ensure consistent order, though we check all
    hwmon_dirs = sorted(glob.glob("/sys/class/hwmon/hwmon*"))

    for hwmon in hwmon_dirs:
        name = get_content(os.path.join(hwmon, "name"))
        best_input = find_best_temp_input(hwmon)

        if not best_input:
            continue

        # CPU Detection - Extended list for older/various hardware
        # Intel: coretemp
        # AMD: k10temp, zenpower, fam15h_power
        # ARM: cpu_thermal
        # Laptops: thinkpad, dell_smm, hp_wmi, asus_ec, applesmc
        # Generic/Legacy: acpitz, it87, nct6775, w83627ehf, lm75, lm78, lm85
        cpu_sensors = [
            "coretemp",      # Intel Core (most common)
            "k10temp",       # AMD K10+
            "zenpower",      # AMD Zen
            "cpu_thermal",   # ARM/RPi
            "fam15h_power",  # Old AMD
            "acpitz",        # ACPI thermal (generic fallback)
            "thinkpad",      # ThinkPad EC
            "dell_smm",      # Dell laptops
            "hp_wmi",        # HP laptops
            "asus_ec",       # ASUS EC
            "applesmc",      # Apple SMC
            "it87",          # ITE Super I/O
            "nct6775",       # Nuvoton Super I/O
            "w83627ehf",     # Winbond Super I/O
            "lm75",          # Legacy I2C sensor
            "lm78",          # Legacy I2C sensor
            "lm85",          # Legacy I2C sensor
            "via_cputemp",   # VIA CPUs
            "pch_cannonlake", # Intel PCH
            "pch_skylake",   # Intel PCH
            "iwlwifi_1",     # Sometimes reports CPU-adjacent temps
        ]

        if name in cpu_sensors:
            # If we already found a CPU path, only replace it if the new one is "better" (e.g. Package vs Core)
            # But simpler logic: first "Package" or "Tdie" wins.
            if not cpu_path:
                cpu_path = best_input
            elif (
                "package" in get_content(best_input.replace("_input", "_label")).lower()
            ):
                cpu_path = best_input  # Upgrade to package if we had something else

        # GPU Detection - Extended list
        gpu_sensors = [
            "amdgpu",        # AMD GPU
            "radeon",        # AMD legacy GPU
            "nouveau",       # NVIDIA open source
            "nvidia",        # NVIDIA proprietary
            "i915",          # Intel integrated GPU
            "xe",            # Intel Xe GPU
            "panfrost",      # ARM Mali
            "lima",          # ARM Mali (older)
            "v3d",           # Broadcom VideoCore
            "vc4",           # Broadcom VideoCore
        ]

        if name in gpu_sensors:
            if not gpu_path:
                gpu_path = best_input

    # 2. Fallback to Thermal Zones (if missing)
    if not cpu_path or not gpu_path:
        for tz in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
            tz_type = get_content(os.path.join(tz, "type")).lower()
            temp_path = os.path.join(tz, "temp")

            if not os.path.exists(temp_path):
                continue

            # Verify the temp file is readable and has valid data
            try:
                val = int(get_content(temp_path))
                if val <= 0:
                    continue
            except:
                continue

            # CPU thermal zones - extended patterns
            cpu_tz_patterns = [
                "cpu", "x86_pkg_temp", "acpitz", "soc",
                "core", "package", "processor", "int3400",
                "pch", "b0d4"  # Intel PCH patterns
            ]

            # GPU thermal zones
            gpu_tz_patterns = ["gpu", "radeon", "amdgpu", "nvidia"]

            if not cpu_path and any(x in tz_type for x in cpu_tz_patterns):
                cpu_path = temp_path

            if not gpu_path and any(x in tz_type for x in gpu_tz_patterns):
                gpu_path = temp_path

    # Output results compatible with QML SplitParser
    # Resolve symlinks for FileView compatibility
    if cpu_path:
        print(f"cpu:{os.path.realpath(cpu_path)}")
    if gpu_path:
        print(f"gpu:{os.path.realpath(gpu_path)}")


if __name__ == "__main__":
    detect()
