#!/usr/bin/env python3
"""
Fix double-encoded UTF-8 corruption in Dart source files.

This occurs when UTF-8 bytes are misinterpreted as Latin-1/Windows-1252
and then re-encoded as UTF-8, creating mojibake.
"""

import os
import sys
from pathlib import Path

# Map of corrupted patterns to correct Unicode characters
# These are the corrupted strings as they appear in the files
REPLACEMENTS = {
    # Currency symbols
    'â\x82¹': '₹',  # Indian Rupee
    'â\x82¬': '€',  # Euro
    '£': '£',       # Pound
    '¥': '¥',       # Yen
    
    # Dashes
    'â\x80\x94': '—',  # Em dash
    'â\x80\x93': '–',  # En dash
    
    # Quotes
    'â\x80\x98': ''',  # Left single quote
    'â\x80\x99': ''',  # Right single quote
    'â\x80\x9c': '"',  # Left double quote
    'â\x80\x9d': '"',  # Right double quote
    
    # Bullets and symbols
    'â\x80¢': '•',  # Bullet
    'â\x80¦': '…',  # Ellipsis
    '·': '·',       # Middle dot
    
    # Box drawing (used in comments)
    'â\x94\x80': '─',  # Horizontal
    'â\x94\x82': '│',  # Vertical
    'â\x94\x8c': '┌',  # Down-right
    'â\x94\x90': '┐',  # Down-left
    'â\x94\x94': '└',  # Up-right
    'â\x94\x98': '┘',  # Up-left
    'â\x94\x9c': '├',  # Vertical-right
    'â\x94¤': '┤',  # Vertical-left
    
    # Math symbols
    '×': '×',  # Multiplication
    '÷': '÷',  # Division
    '±': '±',  # Plus-minus
    '°': '°',  # Degree
    
    # Other
    ' ': ' ',  # Non-breaking space (when only  appears)
    '©': '©',  # Copyright
    '®': '®',  # Registered
}

def fix_file(filepath):
    """Fix Unicode corruption in a single file."""
    try:
        # Read file as UTF-8
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        replacements_made = 0
        
        # Apply all replacements
        for corrupted, correct in REPLACEMENTS.items():
            if corrupted in content:
                count = content.count(corrupted)
                content = content.replace(corrupted, correct)
                replacements_made += count
                if count > 0:
                    print(f"    - Fixed {count}x '{corrupted}' → '{correct}'")
        
        # Only write if changes were made
        if content != original:
            with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
                f.write(content)
            return replacements_made
        
        return 0
    
    except Exception as e:
        print(f"  ✗ Error processing {filepath}: {e}")
        return 0

def main():
    """Find and fix all Dart files in lib/."""
    print("=== Unicode Corruption Fix ===\n")
    
    lib_dir = Path('lib')
    if not lib_dir.exists():
        print("Error: lib/ directory not found")
        print("Please run this script from the project root")
        return 1
    
    dart_files = list(lib_dir.rglob('*.dart'))
    print(f"Found {len(dart_files)} Dart files\n")
    
    total_files_fixed = 0
    total_replacements = 0
    
    for filepath in dart_files:
        replacements = fix_file(filepath)
        if replacements > 0:
            print(f"  ✓ Fixed {filepath} ({replacements} replacements)")
            total_files_fixed += 1
            total_replacements += replacements
    
    print(f"\n=== Summary ===")
    print(f"Files fixed: {total_files_fixed}")
    print(f"Total replacements: {total_replacements}")
    print(f"\n✓ Done!")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
