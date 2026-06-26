#!/bin/bash

# Ensure script fails on any error
set -e

# Check if app path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 path/to/NoShortcut.app"
    exit 1
fi

APP_PATH="$1"

# Check if the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH is not a directory or does not exist."
    exit 1
fi

# Get absolute path of the app and project root
APP_ABS_PATH=$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")
PROJECT_ROOT=$(pwd)

# Create a temporary staging folder
STAGING_DIR="/tmp/NoShortcut_dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Staging files..."
# Copy the app to the staging directory
cp -R "$APP_ABS_PATH" "$STAGING_DIR/"

# Create symlink to Applications folder for easy drag-and-drop
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating Disk Image (DMG)..."
# Create the DMG file in the project root
hdiutil create -volname "NoShortcut" -srcfolder "$STAGING_DIR" -ov -format UDZO "$PROJECT_ROOT/NoShortcut.dmg"

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo "Success! NoShortcut.dmg created at project root."
