#!/bin/bash
set -e

echo "==== Setting up Flash-AI Codespace ===="

# Make bin scripts executable
echo "Making bin scripts executable..."
chmod +x bin/*

# Make the setup_permissions script executable and run it
echo "Running permissions setup script..."
chmod +x bin/setup_permissions
./bin/setup_permissions

echo "==== Codespace setup complete! ====" 