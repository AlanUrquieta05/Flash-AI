#!/bin/bash
set -e

# Make bin scripts executable
chmod +x bin/*

# Make cucumber executable if it exists
if [ -d vendor/bundle ]; then
  find vendor/bundle -name cucumber -type f -exec chmod +x {} \;
fi