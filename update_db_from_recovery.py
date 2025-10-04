#!/usr/bin/env python3
"""
ChromeOS Recovery Database Updater - Python Version
Optimized version of update_db_from_recovery.sh

This script downloads ChromeOS recovery configuration and generates
device databases with hardware IDs and firmware information.
"""

import sys
import re
import json
import requests
import argparse
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple
from collections import defaultdict
from dataclasses import dataclass
from urllib.parse import urlparse


@dataclass
class DeviceEntry:
    """Represents a ChromeOS device entry"""
    name: str
    hwid: str
    file: str
    platform: str
    flags: str = ""
    device: str = ""


class ChromeOSRecoveryUpdater:
    """Main class for updating ChromeOS recovery database"""
    
    CONFIG_URL = "https://dl.google.com/dl/edgedl/chromeos/recovery/recovery.conf?source=linux_recovery.sh"
    
    # Platform mapping for ChromeOS images
    PLATFORM_MAP = {
        'asuka': 'SKL', 'atlas': 'KBL', 'auron-paine': 'BDW', 'auron-yuna': 'BDW',
        'banjo': 'BYT', 'banon': 'BSW', 'brask': 'ADL', 'brya': 'ADL', 'brox': 'ADL',
        'buddy': 'BDW', 'butterfly': 'SNB', 'candy': 'BYT', 'caroline': 'SKL',
        'cave': 'SKL', 'celes': 'BSW', 'chell': 'SKL', 'clapper': 'BYT',
        'coral': 'APL', 'cyan': 'BSW', 'dedede': 'JSL', 'drallion': 'CML',
        'edgar': 'BSW', 'enguarde': 'BYT', 'eve': 'KBL', 'expresso': 'BYT',
        'falco': 'HSW', 'falco-li': 'HSW', 'fizz': 'KBL', 'gandof': 'BDW',
        'glimmer': 'BYT', 'gnawty': 'BYT', 'grunt': 'STR', 'guado': 'BDW',
        'guybrush': 'CZN', 'hatch': 'CML', 'heli': 'BYT', 'kalista': 'KBL',
        'kefka': 'BSW', 'kip': 'BYT', 'lars': 'SKL', 'leon': 'HSW',
        'link': 'IVB', 'lulu': 'BDW', 'lumpy': 'SNB', 'mccloud': 'HSW',
        'monroe': 'HSW', 'nami': 'KBL', 'nautilus': 'KBL', 'ninja': 'BYT',
        'nissa': 'ADN', 'nocturne': 'KBL', 'octopus': 'GLK', 'orco': 'BYT',
        'panther': 'HSW', 'peppy': 'HSW', 'puff': 'CML', 'pyro': 'APL',
        'quawks': 'BYT', 'rammus': 'KBL', 'reef': 'APL', 'reks': 'BSW',
        'relm': 'BSW', 'rex': 'MTL', 'rikku': 'BDW', 'samus': 'BDW',
        'sand': 'APL', 'sarien': 'WHL', 'sentry': 'SKL', 'setzer': 'BSW',
        'skyrim': 'MDN', 'snappy': 'APL', 'soraka': 'KBL', 'squawks': 'BYT',
        'stout': 'IVB', 'stumpy': 'SNB', 'sumo': 'BYT', 'swanky': 'BYT',
        'terra': 'BYT', 'tidus': 'BDW', 'tricky': 'HSW', 'ultima': 'BSW',
        'volteer': 'TGL', 'winky': 'BYT', 'wizpig': 'BSW', 'wolf': 'HSW',
        'zako': 'HSW', 'zork': 'PCO'
    }
    
    def __init__(self, target_images: Optional[List[str]] = None):
        """Initialize the updater with optional target images filter"""
        self.target_images = set(target_images) if target_images else set(self.PLATFORM_MAP.keys())
        self.device_entries: List[DeviceEntry] = []
        self.firmware_entries: Set[str] = set()
        
    def validate_config_url(self, url: str) -> None:
        """Validate the configuration URL format"""
        if not url:
            raise ValueError("Configuration URL is required")
        
        parsed = urlparse(url)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError(f"Invalid URL format: {url}. Must start with http:// or https://")
    
    def download_config(self, url: str) -> str:
        """Download configuration file from URL"""
        try:
            print(f"Downloading config file from {url.split('?')[0]}")
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            return response.text
        except requests.RequestException as e:
            raise RuntimeError(f"Unable to download config file: {e}")
    
    def get_platform(self, image_name: str) -> str:
        """Get platform code for ChromeOS image"""
        return self.PLATFORM_MAP.get(image_name.lower(), 'UNK')
    
    def clean_device_name(self, name: str) -> str:
        """Clean and normalize device name"""
        if not name:
            return ""
        
        # Skip Development Project entries
        if 'Development Project' in name:
            return None
        
        # Skip if contains .bin
        if '.bin' in name:
            return None
        
        # Handle semicolons - truncate if length > 45
        if len(name) > 45 and ';' in name:
            name = name.split(';')[0].rstrip()
        
        # Only truncate parentheses if the name is extremely long (>80 chars) or unclosed
        if '(' in name:
            if len(name) > 80 or ')' not in name:
                name = name.split('(')[0].rstrip()
        
        # Remove double quotes
        name = name.replace('"', '')
        
        return name
    
    def extract_image_name(self, filename: str) -> str:
        """Extract image name from filename"""
        # Format: chromeos_<version>_<image_name>_recovery.bin.zip
        parts = filename.split('_')
        if len(parts) >= 3:
            return parts[2]
        return ""
    
    def parse_config(self, config_content: str) -> None:
        """Parse configuration content and extract device entries"""
        print("Parsing recovery data")
        
        # Split into entries (separated by empty lines)
        entries = []
        current_entry = {}
        
        for line in config_content.split('\n'):
            line = line.strip()
            
            if not line:
                if current_entry:
                    entries.append(current_entry)
                    current_entry = {}
                continue
            
            if '=' in line:
                key, value = line.split('=', 1)
                current_entry[key.strip()] = value.strip()
        
        # Add last entry if exists
        if current_entry:
            entries.append(current_entry)
        
        print(f"Found {len(entries)} entries in config")
        
        # Process each entry
        for entry in entries:
            self.process_entry(entry)
    
    def process_entry(self, entry: Dict[str, str]) -> None:
        """Process a single configuration entry"""
        name = entry.get('name', '').strip()
        hwid_match = entry.get('hwidmatch', '')
        filename = entry.get('file', '')
        
        if not all([name, hwid_match, filename]):
            return
        
        # Clean device name
        clean_name = self.clean_device_name(name)
        if clean_name is None:
            return
        
        # Extract HWID (remove ^ prefix and . suffix)
        hwid = hwid_match.lstrip('^').split('.')[0].strip().replace('(', '')
        
        # Extract image name
        image_name = self.extract_image_name(filename)
        if not image_name or image_name not in self.target_images:
            return
        
        # Get platform
        platform = self.get_platform(image_name)
        
        # Extract device name
        device = hwid.split('-')[0].split('.')[0].lower()
        
        # Determine flags
        flags = ""
        if 'hromebox' in clean_name or 'hromebase' in clean_name:
            flags = "isCbox,hasLAN"
        
        # Create device entry
        device_entry = DeviceEntry(
            name=clean_name,
            hwid=hwid,
            file=filename,
            platform=platform,
            flags=flags,
            device=device
        )
        
        self.device_entries.append(device_entry)
        
        # Add firmware entry
        from datetime import date
        today = date.today().strftime("%Y%m%d")
        firmware_entry = f"export coreboot_uefi_{device}=\"coreboot_edk2-{device}-mrchromebox_{today}.rom\""
        self.firmware_entries.add(firmware_entry)
    
    def optimize_hwids(self) -> None:
        """Optimize HWIDs by removing hyphenated suffixes for unique entries"""
        print("Post-processing HWID entries")
        
        # Count occurrences of base HWIDs
        base_hwid_counts = defaultdict(int)
        for entry in self.device_entries:
            base_hwid = entry.hwid.split('-')[0].rstrip()
            base_hwid_counts[base_hwid] += 1
        
        # Optimize entries
        for entry in self.device_entries:
            base_hwid = entry.hwid.split('-')[0].rstrip()
            if base_hwid_counts[base_hwid] == 1:
                entry.hwid = base_hwid
        
        # Handle long duplicate descriptions
        self.optimize_long_descriptions()
    
    def optimize_long_descriptions(self) -> None:
        """Optimize long descriptions by truncating duplicates at first forward slash"""
        # Find entries with long descriptions (>50 chars) that contain forward slashes
        long_entries = []
        for entry in self.device_entries:
            if len(entry.name) > 50 and '/' in entry.name:
                long_entries.append(entry)
        
        if not long_entries:
            return
        
        # Group by the base name (before first slash) to find duplicates
        base_name_groups = defaultdict(list)
        for entry in long_entries:
            base_name = entry.name.split('/')[0].rstrip()
            base_name_groups[base_name].append(entry)
        
        # Truncate descriptions for groups with multiple entries
        for base_name, entries in base_name_groups.items():
            if len(entries) > 1:  # Only truncate if there are duplicates
                for entry in entries:
                    if '/' in entry.name:
                        truncated = entry.name.split('/')[0].rstrip()
                        print(f"Truncating '{entry.name}' to '{truncated}' (duplicate group)")
                        entry.name = truncated
    
    def generate_output_files(self, output_dir: Path = None, group_by_platform: bool = True) -> None:
        """Generate output files with optional platform grouping"""
        if output_dir is None:
            output_dir = Path.cwd()
        
        output_dir = Path(output_dir)
        output_dir.mkdir(exist_ok=True)
        
        # Generate HWID list
        hwid_file = output_dir / "hwid_list.txt"
        with open(hwid_file, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write("#\n")
            f.write("# Generated ChromeOS Recovery Device Database\n")
            f.write("# Format: [HWID]=\"deviceDescription|CPU|device override|flags|\"\n")
            f.write(f"# Generated on: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("#\n")
            f.write("\n")
            f.write("# Declare the device database\n")
            f.write("declare -gA RECOVERY_DEVICE_DB\n")
            f.write("\n")
            f.write("# Populate the database\n")
            f.write("RECOVERY_DEVICE_DB=(\n")
            
            if group_by_platform:
                # Group entries by platform and sort within each group
                platform_groups = defaultdict(list)
                for entry in self.device_entries:
                    platform_groups[entry.platform].append(entry)
                
                # Sort platforms alphabetically
                for platform in sorted(platform_groups.keys()):
                    entries = sorted(platform_groups[platform], key=lambda x: x.hwid)
                    
                    # Add platform comment header
                    f.write(f"\n\t# {platform} Platform Devices\n")
                    for entry in entries:
                        f.write(f'\t["{entry.hwid}*"]="{entry.name}|{entry.platform}||{entry.flags}|"\n')
            else:
                # Sort entries by HWID (original behavior)
                sorted_entries = sorted(self.device_entries, key=lambda x: x.hwid)
                for entry in sorted_entries:
                    f.write(f'\t["{entry.hwid}*"]="{entry.name}|{entry.platform}||{entry.flags}|"\n')
            
            f.write(")\n")
        
        # Generate firmware list
        fw_file = output_dir / "fw_list.txt"
        with open(fw_file, 'w') as f:
            for firmware_entry in sorted(self.firmware_entries):
                f.write(f"{firmware_entry}\n")
        
        print(f"Generated {hwid_file}")
        print(f"Generated {fw_file}")
        
        # Generate platform summary
        if group_by_platform:
            self.generate_platform_summary(output_dir)
    
    def generate_platform_summary(self, output_dir: Path) -> None:
        """Generate a summary file showing device counts by platform"""
        platform_counts = defaultdict(int)
        for entry in self.device_entries:
            platform_counts[entry.platform] += 1
        
        summary_file = output_dir / "platform_summary.txt"
        with open(summary_file, 'w') as f:
            f.write("ChromeOS Recovery Device Database - Platform Summary\n")
            f.write("=" * 55 + "\n")
            f.write(f"Generated on: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total devices: {len(self.device_entries)}\n")
            f.write(f"Total platforms: {len(platform_counts)}\n")
            f.write("\nPlatform breakdown:\n")
            f.write("-" * 25 + "\n")
            
            # Sort platforms by device count (descending) then alphabetically
            sorted_platforms = sorted(platform_counts.items(), key=lambda x: (-x[1], x[0]))
            for platform, count in sorted_platforms:
                percentage = (count / len(self.device_entries)) * 100
                f.write(f"{platform:8s}: {count:3d} devices ({percentage:5.1f}%)\n")
        
        print(f"Generated {summary_file}")
    
    def run(self, config_url: str = None, group_by_platform: bool = True) -> None:
        """Main execution method"""
        config_url = config_url or self.CONFIG_URL
        
        # Validate URL
        self.validate_config_url(config_url)
        
        # Download config
        config_content = self.download_config(config_url)
        
        # Parse config
        self.parse_config(config_content)
        
        # Optimize HWIDs
        self.optimize_hwids()
        
        # Generate output files
        self.generate_output_files(group_by_platform=group_by_platform)
        
        print(f"Processed {len(self.device_entries)} device entries")
        print(f"Generated {len(self.firmware_entries)} firmware entries")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Update ChromeOS recovery database from recovery configuration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Process all images with platform grouping
  %(prog)s coral reef snappy                  # Process specific images
  %(prog)s --no-platform-grouping             # Disable platform grouping
  %(prog)s --config-url URL                   # Use custom config URL
  %(prog)s --output-dir /path/to/output       # Specify output directory
        """
    )
    
    parser.add_argument(
        'target_images',
        nargs='*',
        help='Specific ChromeOS images to process (default: all)'
    )
    
    parser.add_argument(
        '--config-url',
        help='Custom configuration URL (default: Google ChromeOS recovery config)'
    )
    
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output directory for generated files (default: current directory)'
    )
    
    parser.add_argument(
        '--no-platform-grouping',
        action='store_true',
        help='Disable platform grouping in output (default: enabled)'
    )
    
    args = parser.parse_args()
    
    try:
        # Create updater instance
        updater = ChromeOSRecoveryUpdater(args.target_images)
        
        # Run the update process
        group_by_platform = not args.no_platform_grouping
        updater.run(args.config_url, group_by_platform=group_by_platform)
        
        # Generate output files in specified directory if different from default
        if args.output_dir and args.output_dir != Path.cwd():
            updater.generate_output_files(args.output_dir, group_by_platform=group_by_platform)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
