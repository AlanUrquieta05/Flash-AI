#!/bin/bash
set -e

# Make all scripts in bin directory executable
echo "Setting execute permissions on bin/* files"
chmod +x bin/*

# Fix line endings and shebangs if needed
echo "Fixing shebangs in bin files"
for file in bin/*; do
  if [ -f "$file" ]; then
    # Convert CRLF to LF
    sed -i 's/\r$//' "$file"
    
    # Replace ruby.exe with ruby in shebang
    sed -i '1s/ruby\.exe/ruby/' "$file"
  fi
done

echo "✓ Script permissions fixed successfully!" 