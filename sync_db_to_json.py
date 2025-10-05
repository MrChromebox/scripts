#!/usr/bin/env python3
"""
HWID Analysis Script v2 - Improved duplicate detection

This script analyzes HWID prefixes from device-db.sh and compares them with devices.json.
It updates devices.json with any missing HWID/boardname entries in the correct platform section.
Version 2 improves duplicate detection by checking for similar boardnames.
"""

import json
import re
import sys
import argparse
from pathlib import Path

# Board names to skip/ignore
SKIP_BOARDNAMES = {
    'FIZZ',
    'RAMMUS', 
    'CORAL',
    'NAMI',
    'SKYRIM'
}

def parse_device_db():
    """Parse device-db.sh to extract HWID prefixes and their information."""
    device_db_file = Path("device-db.sh")
    if not device_db_file.exists():
        print("Error: device-db.sh not found")
        return {}
    
    devices = {}
    
    with open(device_db_file, 'r') as f:
        content = f.read()
    
    # Extract DEVICE_DB entries
    # Pattern to match entries like ["HWID*"]="description|cpu|override|flags|"
    pattern = r'\["([^"]+)"\]="([^|]+)\|([^|]+)\|([^|]*)\|([^|]*)\|"'
    matches = re.findall(pattern, content)
    
    for hwid, description, cpu, override, flags in matches:
        # Remove the * from HWID for comparison - use HWID as boardname, not override
        clean_hwid = hwid.rstrip('*')
        
        devices[clean_hwid] = {
            'description': description.strip(),
            'cpu': cpu.strip(),
            'override': override.strip(),
            'flags': flags.strip(),
            'boardname': clean_hwid  # Use HWID as boardname, not the override
        }
    
    return devices

def get_cpu_platform_mapping():
    """Map CPU codes to platform names used in devices.json."""
    return {
        'SNB': 'Intel Sandybridge/Ivybridge',
        'IVB': 'Intel Sandybridge/Ivybridge', 
        'HSW': 'Intel Haswell',
        'BDW': 'Intel Broadwell',
        'BYT': 'Intel Baytrail',
        'BSW': 'Intel Braswell',
        'SKL': 'Intel Skylake',
        'APL': 'Intel Apollolake',
        'KBL': 'Intel Kabylake / Amberlake',
        'GLK': 'Intel Geminilake',
        'WHL': 'Intel Whiskeylake',
        'CML': 'Intel Cometlake',
        'JSL': 'Intel JasperLake',
        'TGL': 'Intel TigerLake',
        'ADL': 'Intel Alderlake',
        'ADN': 'Intel Alderlake-N',
        'MTL': 'Intel Meteorlake',
        'STR': 'AMD Stoneyridge',
        'PCO': 'AMD Picasso',
        'CZN': 'AMD Cezanne',
        'MDN': 'AMD Mendocino'
    }

def load_devices_json(devices_json_path="devices.json"):
    """Load devices.json file."""
    devices_json_file = Path(devices_json_path)
    if not devices_json_file.exists():
        print(f"Error: {devices_json_path} not found")
        return {}
    
    with open(devices_json_file, 'r') as f:
        return json.load(f)

def normalize_boardname(boardname):
    """Normalize boardname for comparison by removing extra spaces and special chars."""
    if not boardname:
        return ""
    # Remove extra spaces, split by / and take first part, remove special chars
    normalized = re.sub(r'\s+', ' ', boardname.strip())
    # Take first part if there's a / (like "AURON_PAINE / PAINE" -> "AURON_PAINE")
    if '/' in normalized:
        normalized = normalized.split('/')[0].strip()
    # Remove special characters for comparison
    normalized = re.sub(r'[^\w]', '', normalized.upper())
    return normalized

def is_similar_description(desc1, desc2):
    """Check if two descriptions are similar by comparing first 12 characters."""
    if not desc1 or not desc2:
        return False
    
    # Normalize descriptions for comparison
    norm1 = desc1.strip().upper()
    norm2 = desc2.strip().upper()
    
    # Exact match
    if norm1 == norm2:
        return True
    
    # Check first 12 characters if both strings are long enough
    if len(norm1) >= 12 and len(norm2) >= 12:
        return norm1[:12] == norm2[:12]
    
    # If one is shorter than 12 chars, check if the shorter one matches the beginning of the longer one
    shorter = norm1 if len(norm1) < len(norm2) else norm2
    longer = norm2 if len(norm1) < len(norm2) else norm1
    
    if len(shorter) >= 8:  # Only compare if shorter is at least 8 chars
        return longer.startswith(shorter)
    
    return False

def find_similar_description(description, existing_descriptions):
    """Find if a description is similar to any existing description."""
    for existing_desc in existing_descriptions:
        if is_similar_description(description, existing_desc):
            return existing_desc
    return None

def find_existing_boardname(devices_json, boardname):
    """Check if a boardname already exists in any platform section with improved matching."""
    target_normalized = normalize_boardname(boardname)
    
    for platform, data in devices_json.items():
        if 'devices' in data:
            for device_entry in data['devices']:
                existing_boardname = device_entry.get('boardname', '')
                existing_normalized = normalize_boardname(existing_boardname)
                
                # Check exact match first
                if existing_boardname == boardname:
                    return platform, device_entry
                
                # Check normalized match
                if existing_normalized and existing_normalized == target_normalized:
                    return platform, device_entry
                
                # Check if target is contained in existing with word boundary matching
                # This handles cases like "AURON_PAINE" vs "AURON_PAINE / PAINE" but not "QUANDISO" vs "QUANDISO3602"
                if existing_normalized and target_normalized in existing_normalized:
                    # Only match if it's a complete word match (not a substring within a longer word)
                    if (existing_normalized.startswith(target_normalized + '_') or 
                        existing_normalized.startswith(target_normalized + '/') or
                        existing_normalized == target_normalized or
                        existing_normalized.endswith('_' + target_normalized) or
                        existing_normalized.endswith('/' + target_normalized)):
                        return platform, device_entry
                
                # Check if existing is contained in target with word boundary matching
                if target_normalized and existing_normalized in target_normalized:
                    # Only match if it's a complete word match (not a substring within a longer word)
                    if (target_normalized.startswith(existing_normalized + '_') or 
                        target_normalized.startswith(existing_normalized + '/') or
                        target_normalized == existing_normalized or
                        target_normalized.endswith('_' + existing_normalized) or
                        target_normalized.endswith('/' + existing_normalized)):
                        return platform, device_entry
    
    return None, None

def add_missing_device(devices_json, platform, boardname, descriptions, cpu_info):
    """Add a missing device entry to the appropriate platform section in alphabetical order."""
    if platform not in devices_json:
        print(f"Warning: Platform '{platform}' not found in devices.json")
        return False
    
    if 'devices' not in devices_json[platform]:
        devices_json[platform]['devices'] = []
    
    # Ensure descriptions is a list
    if isinstance(descriptions, str):
        descriptions = [descriptions]
    
    # Check if device already exists
    for device_entry in devices_json[platform]['devices']:
        existing_boardname = device_entry.get('boardname', '')
        if existing_boardname == boardname:
            # Update description if missing or different
            if not device_entry.get('device') or device_entry['device'] == ['']:
                device_entry['device'] = descriptions
                return True
            return False
    
    # Create new device entry
    new_device = {
        'device': descriptions,
        'boardname': boardname
    }
    
    # Insert in alphabetical order by boardname
    devices = devices_json[platform]['devices']
    for i, existing_device in enumerate(devices):
        existing_boardname = existing_device.get('boardname', '')
        if boardname.lower() < existing_boardname.lower():
            devices.insert(i, new_device)
            return True
    
    # If not inserted, append to end
    devices.append(new_device)
    return True

def analyze_and_update(devices_json_path="devices.json"):
    """Main analysis function."""
    print(f"Analyzing HWID prefixes from device-db.sh...")
    print(f"Using devices.json path: {devices_json_path}")
    
    # Parse device database
    device_db = parse_device_db()
    if not device_db:
        print("No devices found in device-db.sh")
        return
    
    print(f"Found {len(device_db)} HWID entries in device-db.sh")
    
    # Load devices.json
    devices_json = load_devices_json(devices_json_path)
    if not devices_json:
        print(f"No data found in {devices_json_path}")
        return
    
    # Get CPU to platform mapping
    cpu_mapping = get_cpu_platform_mapping()
    
    # Analyze each HWID from device-db.sh
    missing_entries = []
    updated_entries = []
    skipped_duplicates = []
    skipped_purism = []
    
    # First pass: Group hyphenated variants by base HWID
    grouped_devices = {}
    
    for hwid, info in device_db.items():
        # Skip Purism boards
        if hwid.startswith('LIBREM'):
            skipped_purism.append((hwid, info['description']))
            continue
            
        platform = cpu_mapping.get(info['cpu'])
        if not platform:
            print(f"Warning: Unknown CPU platform '{info['cpu']}' for HWID '{hwid}'")
            continue
        
        # Extract base HWID (part before hyphen or space, remove * suffix)
        clean_hwid = hwid.rstrip('*')
        # Handle spaces: LARS [DE] -> LARS
        if ' ' in clean_hwid:
            base_hwid = clean_hwid.split(' ')[0]
        else:
            # Handle hyphens: BUJIA-FWVA -> BUJIA
            base_hwid = clean_hwid.split('-')[0]
        
        # Group by base HWID and platform
        key = (base_hwid, platform)
        if key not in grouped_devices:
            grouped_devices[key] = {
                'base_hwid': base_hwid,
                'platform': platform,
                'descriptions': [],
                'all_hwids': [],
                'cpu': info['cpu'],
                'flags': info['flags']
            }
        
        grouped_devices[key]['descriptions'].append(info['description'])
        grouped_devices[key]['all_hwids'].append(hwid)
    
    # Second pass: Process grouped devices
    for (base_hwid, platform), group_info in grouped_devices.items():
        # Skip board names in the skip list
        if base_hwid in SKIP_BOARDNAMES:
            print(f"Skipping boardname: {base_hwid}")
            continue
            
        # Combine descriptions, removing duplicates
        unique_descriptions = list(dict.fromkeys(group_info['descriptions']))  # Preserve order, remove duplicates
        
        # Check if base HWID exists in devices.json
        existing_platform, existing_device = find_existing_boardname(devices_json, base_hwid)
        
        if existing_device:
            # Device already exists - merge any missing descriptions from database
            existing_descriptions = existing_device.get('device', [])
            if not existing_descriptions or existing_descriptions == ['']:
                # No existing descriptions, use all from database
                existing_device['device'] = unique_descriptions
                updated_entries.append((base_hwid, f"{len(unique_descriptions)} variants", existing_device.get('boardname', base_hwid)))
                print(f"Updated descriptions for {existing_device.get('boardname', base_hwid)}: {len(unique_descriptions)} variants")
            else:
                # Merge missing descriptions from database into existing ones, avoiding similar duplicates
                truly_new_descriptions = []
                
                for desc in unique_descriptions:
                    # Check if this description is similar to any existing one
                    similar_existing = find_similar_description(desc, existing_descriptions)
                    if not similar_existing:
                        # Not similar to any existing description, add it
                        truly_new_descriptions.append(desc)
                    else:
                        # Similar to existing description, skip it
                        print(f"  Skipping similar description: '{desc}' (similar to existing: '{similar_existing}')")
                
                if truly_new_descriptions:
                    # Combine existing descriptions with truly new ones
                    combined_descriptions = existing_descriptions + truly_new_descriptions
                    existing_device['device'] = combined_descriptions
                    updated_entries.append((base_hwid, f"added {len(truly_new_descriptions)} new descriptions", existing_device.get('boardname', base_hwid)))
                    print(f"Updated {existing_device.get('boardname', base_hwid)}: added {len(truly_new_descriptions)} new descriptions")
                    print(f"  New descriptions: {', '.join(truly_new_descriptions[:2])}{'...' if len(truly_new_descriptions) > 2 else ''}")
                else:
                    skipped_duplicates.append((base_hwid, f"{len(unique_descriptions)} variants", existing_device.get('boardname', base_hwid)))
                    print(f"Skipped duplicate: {base_hwid} (exists as {existing_device.get('boardname', base_hwid)})")
        else:
            # Add new device with combined descriptions
            if add_missing_device(devices_json, platform, base_hwid, unique_descriptions, group_info):
                missing_entries.append((base_hwid, f"{len(unique_descriptions)} variants", platform))
                print(f"Added: {base_hwid} -> {len(unique_descriptions)} variants to {platform}")
                print(f"  Variants: {', '.join(group_info['all_hwids'])}")
                print(f"  Descriptions: {'; '.join(unique_descriptions[:2])}{'...' if len(unique_descriptions) > 2 else ''}")
    
    # Save updated devices.json
    if missing_entries or updated_entries:
        with open(devices_json_path, 'w') as f:
            json.dump(devices_json, f, indent=4)
        
        print(f"\nSummary:")
        print(f"Added {len(missing_entries)} missing entries")
        print(f"Updated {len(updated_entries)} existing entries")
        print(f"Skipped {len(skipped_duplicates)} duplicates")
        print(f"Skipped {len(skipped_purism)} Purism boards")
        
        if missing_entries:
            print("\nMissing entries added:")
            for hwid, desc, platform in missing_entries:
                print(f"  {hwid}: {desc} -> {platform}")
        
        if updated_entries:
            print("\nUpdated entries:")
            for hwid, desc, existing in updated_entries:
                print(f"  {hwid} (as {existing}): {desc}")
        
        if skipped_duplicates:
            print("\nSkipped duplicates:")
            for hwid, desc, existing in skipped_duplicates:
                print(f"  {hwid} (exists as {existing}): {desc}")
        
        if skipped_purism:
            print("\nSkipped Purism boards:")
            for hwid, desc in skipped_purism:
                print(f"  {hwid}: {desc}")
    else:
        print("No updates needed - all HWID entries are already present in devices.json")

def main():
    """Main function with command line argument parsing."""
    parser = argparse.ArgumentParser(
        description="Analyze HWID prefixes from device-db.sh and update devices.json",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 analyze_hwid_json_v2.py                    # Use default devices.json
  python3 analyze_hwid_json_v2.py my_devices.json    # Use custom path
  python3 analyze_hwid_json_v2.py /path/to/devices.json  # Use absolute path
        """
    )
    
    parser.add_argument(
        'devices_json_path',
        nargs='?',
        default='devices.json',
        help='Path to devices.json file (default: devices.json)'
    )
    
    args = parser.parse_args()
    analyze_and_update(args.devices_json_path)

if __name__ == "__main__":
    main()
