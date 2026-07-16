# ChromeOS Firmware Utility Scripts

Home of the ChromeOS Firmware Utility script and Kodi E-Z Setup script.

For more info, please visit https://mrchromebox.tech

## Overview

This repository contains the ChromeOS Firmware Utility script and its helper scripts.
It also contains scripts to update the device database, sync the database with the
supported devices list (devices.json) on the website, identify devices missing a
published Full ROM, and download Full ROM images offline from the CDN.

## Scripts

### Main Firmware Script

- **`firmware-util.sh`** - Entry point script that downloads and executes the main firmware utility. Handles:
  - Script initialization and dependency checking
  - Downloading required firmware files and utilities
  - Cross-platform compatibility (ChromeOS/ChromiumOS/Linux)
  - Optional private deploys by overriding `script_url` (other helpers still sync from prod)

### Scripts sourced by firmware-util.sh

- **`device-db.sh`** - Comprehensive device database containing:
  - Hardware ID (HWID) mappings for hundreds of ChromeOS devices
  - Device descriptions, CPU platforms, and feature flags
  - Support for devices from SNB through modern platforms
  - Format: `[HWID]="description|CPU|override|flags|"`

- **`device-db-functions.sh`** - Helper functions for device database operations:
  - Device lookup and pattern matching
  - Flag checking (isCbox, kbl_rwl18, etc.)
  - Device description and override retrieval

- **`firmware.sh`** - Main firmware utility script for ChromeOS devices. Provides functionality to:
  - Flash RW_LEGACY firmware for legacy boot support
  - Install custom coreboot firmware (Full ROM/UEFI), including:
    - Install/update to the current Full ROM release (or per-board hotfix)
    - Roll back to the previous Full ROM release (n-1) when eligible
  - Harden Full ROM flashing: retry once on failure, then restore `/tmp/bios.bin` while preserving `/tmp/flashrom.log`
  - Set boot options and configure firmware settings
  - Support for devices from Sandy Bridge (SNB) through current platforms

- **`functions.sh`** - Core utility functions and shared functionality including:
  - System detection and device identification
  - Firmware tool path management (flashrom, cbfstool, gbb-utility, etc.)
  - Full ROM URL resolution (versioned CDN paths, flat fallback, hotfixes)
  - Terminal UI functions and color codes
  - Hardware write protection handling

- **`sources.sh`** - Release metadata and firmware source URLs:
  - Global Full ROM release train (`release_current_*` / `release_previous_*`)
  - Optional per-board hotfix overlay (`FW_HOTFIX`)
  - `fullrom_layout`: `versioned` (default/prod) or `flat` (private/test trees)
  - CDN bases for Full ROM, RW_LEGACY, boot stubs, CBFS, and utilities
  - RW_LEGACY and miscellaneous payload filenames

### Full ROM CDN layout

Prod Full ROMs are published under versioned directories:

```text
full_rom/MrChromebox-<version>/coreboot_edk2-<board>-mrchromebox_<YYYYMMDD>.rom
```

Example:

```text
https://www.mrchromebox.tech/files/firmware/full_rom/MrChromebox-2606.1/coreboot_edk2-drobit-mrchromebox_20260714.rom
```

- The utility tracks **current** and **previous** (n / n-1) releases only.
- Per-board **hotfixes** live at the flat `full_rom/` root (same filename pattern, hotfix build date) and skip the defective current train image for that board.
- With `fullrom_layout=versioned`, a missing versioned object may fall back to the flat CDN root.

### Offline Full ROM downloads

- **`download-fullrom.sh`** - Standalone helper to download Full ROM images from the CDN without running the firmware utility.

  **Latest** (no version argument) — uses `FW_HOTFIX[board]` when set, otherwise the current release train:

  ```bash
  ./download-fullrom.sh drobit
  ./download-fullrom.sh DROBIT                 # HWID / board prefix
  ./download-fullrom.sh "DROBIT C4B-..."        # full HWID string
  ./download-fullrom.sh drobit eve
  ./download-fullrom.sh --all -o /tmp/roms
  ```

  **Pinned release** — always pulls from `MrChromebox-<version>/` (ignores hotfixes):

  ```bash
  ./download-fullrom.sh 2606.1 drobit
  ./download-fullrom.sh 2603.2 --all
  ```

  **Other options:**

  ```bash
  ./download-fullrom.sh --list-versions   # current / previous / hotfixes from sources.sh
  ./download-fullrom.sh -n drobit         # dry-run (print URLs only)
  ./download-fullrom.sh -o /tmp/roms drobit
  ./download-fullrom.sh -j 8 --all        # parallel downloads (default: 4)
  ./download-fullrom.sh 2501.0 -d 20250115 drobit   # unknown train: pass build date
  ./download-fullrom.sh -h
  ```

  Default output directory is `./MrChromebox-<version>` (for unpinned latest, that is the current train version from `sources.sh`). `--all` keeps going after individual failures; use `-k` for the same with an explicit board list. With no version, `--all` / per-board latest still honor `FW_HOTFIX` when set.

  Board arguments may be a ROM slug (`drobit`) or a ChromeOS HWID (`DROBIT`). Quote full HWID strings (`"DROBIT C4B-..."`) so the shell does not split on spaces or expand glob characters (`*`, `?`, `[`). HWIDs are resolved through `device-db.sh` (longest pattern match, including ROM slug overrides such as Librem).

  Metadata (`sources.sh`, `device-db.sh`): if the script is run from a git checkout, local copies next to the script are used; otherwise they are fetched from GitHub into `/tmp/mrchromebox-fullrom-meta-<uid>/` and reused until reboot/cleanup. CDN base and release slots always come from `sources.sh` (`fullrom_source`, release version/date, `FW_HOTFIX`).

### Analysis and Maintenance Scripts

- **`identify_missing_firmware.py`** - Identify device-db boards missing a published UEFI Full ROM on the CDN:
  - Parses `device-db.sh` for ROM slugs (honors overrides, skips `noUEFI`)
  - Checks the current versioned release path from `sources.sh` (with flat-root fallback)
  - Writes `missing_firmware.txt` grouped by platform

- **`sync_db_to_json.py`** - Propagate updates to the website device list:
  - Analyzes HWID prefixes from device-db.sh
  - Compares with devices.json used by the website
  - Updates JSON with missing HWID/boardname entries

- **`update_db_from_recovery.py`** - Update the device database from ChromeOS recovery metadata:
  - Downloads ChromeOS recovery configuration from Google
  - Parses recovery.conf to extract device metadata
  - Generates/updates device database entries with hardware IDs and firmware information

### Legacy Scripts

- **`setup-kodi.sh`** - Legacy Kodi setup script (no longer supported)
  - Redirects users to use the main Firmware Utility Script
  - Historical reference for Kodi installation on ChromeOS devices

## Usage

For most users, the primary entry point is the `firmware-util.sh` script which will automatically bootstrap the Firmware Utility script on your ChromeOS device.

To download Full ROM images offline (mirrors, air-gapped installs, archival), use `download-fullrom.sh` as described above.

## Contributing

These scripts are maintained by MrChromebox and the community. Contributions and improvements are welcome.
