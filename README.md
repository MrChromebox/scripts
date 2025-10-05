# ChromeOS Firmware Utility Scripts

Home of the ChromeOS Firmware Utility script and Kodi E-Z Setup script.

For home info, please visit https://mrchromebox.tech

## Overview

This repository contains the ChromeOS Firmware Utility script and its helper scripts.
It also contains scripts to update the device database, sync the database with the
supported devices list (devices.json) on the website, and identify any devices which
do not have firmware available.


## Scripts

### Main Firmware Script

- **`firmware-util.sh`** - Entry point script that downloads and executes the main firmware utility. Handles:
  - Script initialization and dependency checking
  - Downloading required firmware files and utilities
  - Cross-platform compatibility (ChromeOS/ChromiumOS/Linux)

### Scripts sourced by firmware-util.sh

- **`device-db.sh`** - Comprehensive device database containing:
  - Hardware ID (HWID) mappings for hundreds of ChromeOS devices
  - Device descriptions, CPU platforms, and feature flags
  - Support for devices from SNB through modern platforms
  - Format: `[HWID]="description|CPU|override|flags|"`

- **`device-db-functions.sh`** - Helper functions for device database operations:
  - Device lookup and pattern matching
  - Flag checking (isCbox, hasLAN, etc.)
  - Device description and override retrieval

- **`firmware.sh`** - Main firmware utility script for ChromeOS devices. Provides functionality to:
  - Flash RW_LEGACY firmware for legacy boot support
  - Install custom coreboot firmware (Full ROM/UEFI)
  - Set boot options and configure firmware settings
  - Support for devices from Sandy Bridge (SNB) through current platforms

- **`functions.sh`** - Core utility functions and shared functionality including:
  - System detection and device identification
  - Firmware tool path management (flashrom, cbfstool, gbb-utility, etc.)
  - Terminal UI functions and color codes
  - Hardware write protection handling

- **`sources.sh`** - Firmware source URLs and file definitions for:
  - UEFI Full ROM firmware images
  - RW_LEGACY payloads
  - Boot stubs and CBFS components
  - Organized by device platform and type

### Analysis and Maintenance Scripts

- **`identify_missing_firmware.py`** - Python script to analyze the device database and identify devices missing firmware entries:
  - Compares device database (device-db.sh) against available firmware files (sources.sh)
  - Extracts HWID prefixes and matches them against firmware entries
  - Generates missing firmware reports grouped by platform (missing_firmware.txt)
  - **`-g/--generate`** flag: Automatically generates missing firmware entries and appends them to sources.sh
    - Entries are grouped by platform (ADL, ADN, BYT, KBL, MTL, WHL, etc.)
    - Uses current date for firmware filenames
    - Sorted alphabetically within each platform section

- **`sync_db_to_json.py`** - Python script to propagate updates to the device database:
  - Analyzes HWID prefixes from device-db.sh
  - Compares with devices.json used by website
  - Updates JSON with missing HWID/boardname entries

- **`update_db_from_recovery.py`** - Python script to update device database:
  - Downloads ChromeOS recovery configuration from Google
  - Parses recovery.conf to extract device metadata
  - Generates device database entries with hardware IDs and firmware information
  - Outputs formatted device database entries

### Legacy Scripts

- **`setup-kodi.sh`** - Legacy Kodi setup script (no longer supported)
  - Redirects users to use the main Firmware Utility Script
  - Historical reference for Kodi installation on ChromeOS devices



## Usage

For most users, the primary entry point is the `firmware-util.sh` script which will automatically bootstrap the Firmware Utility script on your ChromeOS device.

## Contributing

These scripts are maintained by MrChromebox and the community. Contributions and improvements are welcome.
