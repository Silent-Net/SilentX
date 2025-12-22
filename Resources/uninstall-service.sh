#!/bin/bash
#
# uninstall-service.sh
# SilentX Privileged Helper Service Uninstaller
#
# Usage: uninstall-service.sh
#
# This script uninstalls the silentx-service LaunchDaemon.
# Must be run with root privileges (via osascript/sudo).
#

set -e

# Constants
SERVICE_LABEL="com.silentnet.silentx.service"
SERVICE_NAME="silentx-service"
BINARY_DIR="/Library/PrivilegedHelperTools/${SERVICE_LABEL}"
PLIST_PATH="/Library/LaunchDaemons/${SERVICE_LABEL}.plist"
RUNTIME_DIR="/tmp/silentx"

echo "=== SilentX Service Uninstaller ==="

# Step 1: Stop service if running
echo ""
echo "[1/4] Stopping service..."
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo "  - Service is running, stopping..."
    launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
    sleep 1
    echo "  - Service stopped"
else
    echo "  - Service not currently running"
fi

# Step 2: Disable service
echo ""
echo "[2/4] Disabling service..."
launchctl disable system/"$SERVICE_LABEL" 2>/dev/null || true
echo "  - Service disabled"

# Step 3: Remove plist
echo ""
echo "[3/4] Removing LaunchDaemon plist..."
if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
    echo "  - Removed $PLIST_PATH"
else
    echo "  - Plist not found (already removed)"
fi

# Step 4: Remove binary
echo ""
echo "[4/4] Removing service binary..."
if [ -d "$BINARY_DIR" ]; then
    rm -rf "$BINARY_DIR"
    echo "  - Removed $BINARY_DIR"
else
    echo "  - Binary directory not found (already removed)"
fi

# Optional: Clean runtime directory
echo ""
echo "Cleaning runtime files..."
rm -f "${RUNTIME_DIR}/${SERVICE_NAME}.sock" 2>/dev/null || true
rm -f "${RUNTIME_DIR}/${SERVICE_NAME}.log" 2>/dev/null || true
rm -f "${RUNTIME_DIR}/${SERVICE_NAME}-stdout.log" 2>/dev/null || true
rm -f "${RUNTIME_DIR}/${SERVICE_NAME}-stderr.log" 2>/dev/null || true
rm -f "${RUNTIME_DIR}/sing-box.log" 2>/dev/null || true
echo "  - Runtime files cleaned"

echo ""
echo "=== Uninstallation Complete ==="
echo "The SilentX service has been removed."
echo "You may need to restart your computer to fully clear any cached state."
exit 0
