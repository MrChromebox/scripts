#!/usr/bin/env python3
"""Identify device-db boards missing a published UEFI Full ROM on the CDN."""

import re
import argparse
import urllib.error
import urllib.request
from collections import defaultdict
from datetime import datetime
from pathlib import Path


class FirmwareAnalyzer:
    def __init__(self, script_dir=None):
        if script_dir is None:
            script_dir = Path(__file__).parent

        self.script_dir = Path(script_dir)
        self.device_db_file = self.script_dir / "device-db.sh"
        self.sources_file = self.script_dir / "sources.sh"
        self.output_file = self.script_dir / "missing_firmware.txt"

        self.device_db = {}
        self.missing_by_platform = defaultdict(list)
        self.release_current_version = ""
        self.release_current_date = ""
        self.fullrom_source = ""

        self.hwid_prefix_regex = re.compile(r'^["\[]?([A-Za-z0-9_]+)')

    def parse_device_db(self):
        print("Parsing device database...")

        if not self.device_db_file.exists():
            raise FileNotFoundError(f"Device database file not found: {self.device_db_file}")

        content = self.device_db_file.read_text(encoding="utf-8")
        device_db_pattern = re.compile(r'\["([^"]+)"\]="([^"]+)"', re.MULTILINE)

        for hwid, device_info in device_db_pattern.findall(content):
            parts = device_info.split("|")
            description = parts[0] if len(parts) > 0 else ""
            platform = parts[1] if len(parts) > 1 else "UNKNOWN"
            override = parts[2] if len(parts) > 2 else ""
            flags = parts[3] if len(parts) > 3 else ""
            self.device_db[hwid] = (description, platform, override, flags)

        print(f"Loaded {len(self.device_db)} device entries")

    def parse_sources(self):
        print("Parsing firmware sources...")

        if not self.sources_file.exists():
            raise FileNotFoundError(f"Sources file not found: {self.sources_file}")

        content = self.sources_file.read_text(encoding="utf-8")

        version_match = re.search(r'export release_current_version="([^"]+)"', content)
        if not version_match:
            raise RuntimeError("release_current_version not found in sources.sh")
        self.release_current_version = version_match.group(1)

        date_match = re.search(r'export release_current_date="(\d+)"', content)
        if not date_match:
            raise RuntimeError("release_current_date not found in sources.sh")
        self.release_current_date = date_match.group(1)

        source_match = re.search(r'export fullrom_source="([^"]+)"', content)
        if not source_match:
            raise RuntimeError("fullrom_source not found in sources.sh")
        self.fullrom_source = source_match.group(1)

        print(f"Release: MrChromebox-{self.release_current_version} ({self.release_current_date})")
        print(f"CDN: {self.fullrom_source}MrChromebox-{self.release_current_version}/")

    def extract_hwid_prefix(self, hwid, device_info):
        _, _, override, _ = device_info

        if override:
            prefix = override
        else:
            match = self.hwid_prefix_regex.match(hwid)
            if not match:
                return None
            prefix = match.group(1)

        if re.match(r'^[A-Za-z0-9_]+$', prefix):
            return prefix.lower()

        return None

    def firmware_filename(self, board):
        return f"coreboot_edk2-{board}-mrchromebox_{self.release_current_date}.rom"

    def firmware_url(self, board):
        return (
            f"{self.fullrom_source}MrChromebox-{self.release_current_version}/"
            f"{self.firmware_filename(board)}"
        )

    def firmware_on_cdn(self, board):
        request = urllib.request.Request(self.firmware_url(board), method="HEAD")
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                if response.status == 200:
                    return True
        except urllib.error.HTTPError as exc:
            if exc.code == 200:
                return True
        except urllib.error.URLError:
            pass

        # Flat root fallback if versioned path is missing
        flat_url = f"{self.fullrom_source}{self.firmware_filename(board)}"
        request = urllib.request.Request(flat_url, method="HEAD")
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                return response.status == 200
        except urllib.error.HTTPError as exc:
            return exc.code == 200
        except urllib.error.URLError:
            return False

    def find_missing_firmware(self):
        print("Checking CDN for published Full ROM images...")

        prefixes = {}
        for hwid, device_info in self.device_db.items():
            prefix = self.extract_hwid_prefix(hwid, device_info)
            if not prefix:
                continue

            _, platform, _, flags = device_info
            if "noUEFI" in flags.split(","):
                continue

            if prefix not in prefixes:
                prefixes[prefix] = platform

        missing = []
        for prefix in sorted(prefixes):
            if not self.firmware_on_cdn(prefix):
                missing.append(prefix)
                platform = prefixes[prefix]
                self.missing_by_platform[platform].append(prefix)

        for platform in self.missing_by_platform:
            self.missing_by_platform[platform].sort()

        print(f"Found {len(missing)} boards without a published Full ROM")

    def generate_output(self):
        print(f"Generating output file: {self.output_file}")

        with open(self.output_file, "w", encoding="utf-8") as f:
            f.write("# Boards missing a published UEFI Full ROM on the CDN\n")
            f.write(f"# Generated on {datetime.now().strftime('%a %b %d %I:%M:%S %p %Z %Y')}\n")
            f.write(f"# Release checked: MrChromebox-{self.release_current_version} ({self.release_current_date})\n")
            f.write("\n")

            for platform in sorted(self.missing_by_platform.keys()):
                f.write(f"## {platform} devices\n")
                for board in self.missing_by_platform[platform]:
                    f.write(f"  {board} ({self.firmware_filename(board)})\n")
                f.write("\n")

        print(f"Results saved to {self.output_file}")

    def print_summary(self):
        total_missing = 0
        print("\nSummary:")

        for platform in sorted(self.missing_by_platform.keys()):
            count = len(self.missing_by_platform[platform])
            print(f"  {platform}: {count} missing")
            total_missing += count

        print(f"  Total missing: {total_missing}")

    def run(self):
        try:
            self.parse_device_db()
            self.parse_sources()
            self.find_missing_firmware()
            self.generate_output()
            self.print_summary()
        except Exception as exc:
            print(f"Error: {exc}")
            return 1

        return 0


def main():
    parser = argparse.ArgumentParser(
        description="Identify boards missing a published UEFI Full ROM on the CDN",
    )
    return FirmwareAnalyzer().run()


if __name__ == "__main__":
    raise SystemExit(main())
