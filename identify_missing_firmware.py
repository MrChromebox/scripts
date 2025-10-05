#!/usr/bin/env python3
"""
Script to identify HWID prefixes missing firmware entries in sources.sh
Compares device database against available firmware files
HWID prefix definition: contiguous alphanumeric characters after first quote

Performance improvements over bash version:
- Direct file parsing instead of sourcing shell scripts
- In-memory data structures instead of temporary files
- Efficient string operations and regex
- Reduced subprocess calls
- Better memory management
"""

import re
import os
import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path


class FirmwareAnalyzer:
    def __init__(self, script_dir=None, generate_entries=False):
        """Initialize the firmware analyzer with script directory."""
        if script_dir is None:
            script_dir = Path(__file__).parent
        
        self.script_dir = Path(script_dir)
        self.device_db_file = self.script_dir / "device-db.sh"
        self.sources_file = self.script_dir / "sources.sh"
        self.output_file = self.script_dir / "missing_firmware.txt"
        self.generate_entries = generate_entries
        
        # Data structures
        self.device_db = {}  # {hwid: (description, platform, override, flags)}
        self.firmware_entries = set()
        self.missing_by_platform = defaultdict(list)
        
        # Regex for extracting HWID prefixes - includes underscores for compound names
        self.hwid_prefix_regex = re.compile(r'^["\[]?([A-Za-z0-9_]+)')
        
        # Platform to section comment mapping
        self.platform_to_section = {
            'SNB': '#SNB/IVB',
            'IVB': '#SNB/IVB',
            'HSW': '#Haswell',
            'BDW': '#Broadwell',
            'BYT': '#Baytrail',
            'BSW': '#Braswell',
            'SKL': '#Skylake',
            'KBL': '#KabyLake',
            'WHL': '#KabyLake',  # WhiskeyLake devices go in KabyLake section
            'APL': '#ApolloLake',
            'GLK': '#GeminiLake',
            'CML': '#CometLake',
            'TGL': '#Tigerlake',
            'JSL': '#Jasperlake',
            'ADL': '#Alderlake (brya)',
            'ADN': '#Alderlake-N (nissa)',
            'MTL': '#Meteorlake (rex)',
            'STR': '#Stoneyridge',
            'PCO': '#Picasso',
            'CZN': '#Cezanne',
            'MDN': '#Mendocino',
        }
    
    def parse_device_db(self):
        """Parse the device-db.sh file and extract device information."""
        print("Parsing device database...")
        
        if not self.device_db_file.exists():
            raise FileNotFoundError(f"Device database file not found: {self.device_db_file}")
        
        with open(self.device_db_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract DEVICE_DB entries using regex
        # Format: ["HWID*"]="description|platform|override|flags|"
        device_db_pattern = re.compile(
            r'\["([^"]+)"\]="([^"]+)"',
            re.MULTILINE
        )
        
        matches = device_db_pattern.findall(content)
        for hwid, device_info in matches:
            # Split device info by pipe
            parts = device_info.split('|')
            description = parts[0] if len(parts) > 0 else ""
            platform = parts[1] if len(parts) > 1 else "UNKNOWN"
            override = parts[2] if len(parts) > 2 else ""
            flags = parts[3] if len(parts) > 3 else ""
            
            self.device_db[hwid] = (description, platform, override, flags)
        
        print(f"Loaded {len(self.device_db)} device entries")
    
    def parse_sources(self):
        """Parse the sources.sh file and extract firmware entries."""
        print("Parsing firmware sources...")
        
        if not self.sources_file.exists():
            raise FileNotFoundError(f"Sources file not found: {self.sources_file}")
        
        with open(self.sources_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract coreboot_uefi_* variables
        # Format: export coreboot_uefi_boardname="filename.rom"
        firmware_pattern = re.compile(
            r'export\s+coreboot_uefi_([a-zA-Z0-9_]+)=',
            re.MULTILINE
        )
        
        matches = firmware_pattern.findall(content)
        self.firmware_entries = set(matches)
        
        print(f"Loaded {len(self.firmware_entries)} firmware entries")
    
    def extract_hwid_prefix(self, hwid, device_info):
        """Extract HWID prefix from device entry."""
        _, _, override, _ = device_info
        
        if override:
            # Use device override as prefix
            prefix = override
        else:
            # Extract contiguous alphanumeric sequence after quotes/brackets
            match = self.hwid_prefix_regex.match(hwid)
            if match:
                prefix = match.group(1)
            else:
                return None
        
        # Only return if it contains alphanumeric characters and underscores
        if re.match(r'^[A-Za-z0-9_]+$', prefix):
            return prefix.lower()  # Convert to lowercase to match firmware naming
        
        return None
    
    def find_missing_firmware(self):
        """Find HWID prefixes that are missing firmware entries."""
        print("Analyzing device database against firmware sources...")
        
        # Extract all HWID prefixes
        hwid_prefixes = set()
        hwid_to_platform = {}  # Map prefix to platform for efficient lookup
        hwid_to_flags = {}  # Map prefix to flags for efficient lookup
        self.prefix_to_flags = {}  # Store for later use in generation
        
        for hwid, device_info in self.device_db.items():
            prefix = self.extract_hwid_prefix(hwid, device_info)
            if prefix:
                hwid_prefixes.add(prefix)
                # Store platform and flags mapping for this prefix
                _, platform, _, flags = device_info
                hwid_to_platform[prefix] = platform
                hwid_to_flags[prefix] = flags
                self.prefix_to_flags[prefix] = flags
        
        # Find missing prefixes
        missing_prefixes = hwid_prefixes - self.firmware_entries
        
        # Group by platform
        for prefix in missing_prefixes:
            platform = hwid_to_platform.get(prefix, "UNKNOWN")
            self.missing_by_platform[platform].append(prefix)
        
        # Sort entries within each platform
        for platform in self.missing_by_platform:
            self.missing_by_platform[platform].sort()
        
        print(f"Found {len(missing_prefixes)} missing firmware entries")
    
    def generate_output(self):
        """Generate the missing firmware output file."""
        print(f"Generating output file: {self.output_file}")
        
        with open(self.output_file, 'w', encoding='utf-8') as f:
            f.write("# Missing firmware entries grouped by hardware platform\n")
            f.write(f"# Generated on {datetime.now().strftime('%a %b %d %I:%M:%S %p %Z %Y')}\n")
            f.write("\n")
            
            # Sort platforms for consistent output
            for platform in sorted(self.missing_by_platform.keys()):
                f.write(f"## {platform} devices\n")
                
                # Write each missing HWID
                for hwid in self.missing_by_platform[platform]:
                    f.write(f"  {hwid}\n")
                
                f.write("\n")
        
        print(f"Results saved to {self.output_file}")
    
    def print_summary(self):
        """Print summary of missing firmware entries."""
        total_missing = 0
        print("\nSummary:")
        
        for platform in sorted(self.missing_by_platform.keys()):
            count = len(self.missing_by_platform[platform])
            print(f"  {platform}: {count} missing entries")
            total_missing += count
        
        print(f"  Total missing: {total_missing}")
    
    def generate_firmware_entry(self, board_name, date=None):
        """Generate a firmware entry line in the correct format."""
        if date is None:
            date = datetime.now().strftime('%Y%m%d')
        return f'export coreboot_uefi_{board_name}="coreboot_edk2-{board_name}-mrchromebox_{date}.rom"\n'
    
    def insert_entries_into_sources(self):
        """Append missing firmware entries to the end of sources.sh, grouped by platform."""
        if not self.missing_by_platform:
            print("No missing entries to generate.")
            return
        
        print(f"\nGenerating firmware entries into {self.sources_file}...")
        
        # Get current date
        current_date = datetime.now().strftime('%Y%m%d')
        
        # Build the new section grouped by platform
        new_section = f"\n#UEFI Full ROMs - Missing/New entries (generated {datetime.now().strftime('%Y-%m-%d')})\n"
        
        total_count = 0
        for platform in sorted(self.missing_by_platform.keys()):
            devices = self.missing_by_platform[platform]
            
            # Add platform comment
            new_section += f"\n# {platform} devices\n"
            
            # Add sorted devices for this platform
            for device in sorted(devices):
                new_section += self.generate_firmware_entry(device, current_date)
                print(f"  Added: coreboot_uefi_{device} ({platform})")
                total_count += 1
        
        # Append to file
        with open(self.sources_file, 'a', encoding='utf-8') as f:
            f.write(new_section)
        
        print(f"\nSuccessfully added {total_count} firmware entries to {self.sources_file}")
    
    def run(self):
        """Run the complete firmware analysis."""
        try:
            self.parse_device_db()
            self.parse_sources()
            self.find_missing_firmware()
            self.generate_output()
            self.print_summary()
            
            if self.generate_entries:
                self.insert_entries_into_sources()
            
        except Exception as e:
            print(f"Error: {e}")
            return 1
        
        return 0


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Identify and optionally generate missing firmware entries',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s              # Analyze and report missing firmware entries
  %(prog)s -g           # Analyze and generate missing entries into sources.sh
        """
    )
    
    parser.add_argument(
        '-g', '--generate',
        action='store_true',
        help='Generate missing firmware entries into sources.sh'
    )
    
    args = parser.parse_args()
    
    analyzer = FirmwareAnalyzer(generate_entries=args.generate)
    return analyzer.run()


if __name__ == "__main__":
    exit(main())
