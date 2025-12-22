#!/bin/bash
#
# reinstall-service.sh
# SilentX Privileged Helper Service Reinstaller
#
# Usage: reinstall-service.sh <binary_path> <plist_template_path>
#
# This script uninstalls and reinstalls the service in ONE sudo session.
# Must be run with root privileges (via osascript/sudo).
#

set -e

# Constants
SERVICE_LABEL="com.silentnet.silentx.service"
SERVICE_NAME="silentx-service"
BINARY_DIR="/Library/PrivilegedHelperTools/${SERVICE_LABEL}"
BINARY_PATH="${BINARY_DIR}/${SERVICE_NAME}"
PLIST_PATH="/Library/LaunchDaemons/${SERVICE_LABEL}.plist"
RUNTIME_DIR="/tmp/silentx"

# Arguments
BUNDLED_BINARY="$1"
BUNDLED_PLIST="$2"

# Validate arguments
if [ -z "$BUNDLED_BINARY" ] || [ -z "$BUNDLED_PLIST" ]; then
    echo "Usage: $0 <binary_path> <plist_template_path>"
    exit 1
fi

if [ ! -f "$BUNDLED_BINARY" ]; then
    echo "Error: Binary not found at $BUNDLED_BINARY"
    exit 1
fi

if [ ! -f "$BUNDLED_PLIST" ]; then
    echo "Error: Plist template not found at $BUNDLED_PLIST"
    exit 1
fi

echo "=== SilentX Service Reinstaller (Single Password) ==="
echo "Binary: $BUNDLED_BINARY"
echo "Plist:  $BUNDLED_PLIST"

# === PHASE 1: UNINSTALL ===
echo ""
echo "=== PHASE 1: UNINSTALL ==="

# Stop and unload service if running
echo "[1/8] Stopping existing service..."
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo "  - Service is running, stopping..."
    launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
    sleep 1
else
    echo "  - Service not currently running"
fi

# Kill any stale sing-box processes
echo "[2/8] Killing stale sing-box processes..."
pkill -9 sing-box 2>/dev/null || true
sleep 1

# Wait for TUN interface to be released
echo "[3/8] Waiting for TUN interface release..."
for i in {1..10}; do
    if ! ifconfig tun0 >/dev/null 2>&1 && ! ifconfig utun199 >/dev/null 2>&1; then
        echo "  - TUN interfaces released"
        break
    fi
    echo "  - Waiting... ($i/10)"
    sleep 0.5
done

# Remove old files
echo "[4/8] Removing old installation..."
rm -rf "$BINARY_DIR"
rm -f "$PLIST_PATH"

# Clean runtime files
rm -rf "$RUNTIME_DIR"

# === PHASE 2: INSTALL ===
echo ""
echo "=== PHASE 2: INSTALL ==="

# Create runtime directory
echo "[5/8] Creating runtime directory..."
mkdir -p "$RUNTIME_DIR"
chmod 0777 "$RUNTIME_DIR"

# Install binary
echo "[6/8] Installing service binary..."
mkdir -p "$BINARY_DIR"
cp "$BUNDLED_BINARY" "$BINARY_PATH"
chmod 0544 "$BINARY_PATH"
chown root:wheel "$BINARY_PATH"
chown root:wheel "$BINARY_DIR"

# Install plist
echo "[7/8] Installing LaunchDaemon plist..."
cp "$BUNDLED_PLIST" "$PLIST_PATH"
chmod 0644 "$PLIST_PATH"
chown root:wheel "$PLIST_PATH"

# Start service
echo "[8/8] Starting service..."
launchctl enable system/"$SERVICE_LABEL"
launchctl bootstrap system "$PLIST_PATH"

# Wait for service to start
sleep 2

# Verify service is running
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo ""
    echo "=== Reinstallation Complete ==="
    echo "Service Label: $SERVICE_LABEL"
    echo "Socket Path:   $RUNTIME_DIR/${SERVICE_NAME}.sock"
    exit 0
else
    echo "  - Warning: Service may not have started correctly"
    exit 1
fi
