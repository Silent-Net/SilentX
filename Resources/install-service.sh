#!/bin/bash
#
# install-service.sh
# SilentX Privileged Helper Service Installer
#
# Usage: install-service.sh <binary_path> <plist_template_path>
#
# This script installs the silentx-service as a LaunchDaemon.
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

echo "=== SilentX Service Installer ==="
echo "Binary: $BUNDLED_BINARY"
echo "Plist:  $BUNDLED_PLIST"

# Step 1: Stop existing service if running
echo ""
echo "[1/6] Stopping existing service if running..."
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo "  - Service is running, stopping..."
    launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
    sleep 1
else
    echo "  - Service not currently running"
fi

# Step 1.5: Kill any stale sing-box processes and wait for TUN release
echo ""
echo "[1.5/6] Cleaning up stale processes and TUN interfaces..."

# Kill ALL sing-box processes aggressively
echo "  - Killing all sing-box processes..."
killall -9 sing-box 2>/dev/null || true
pkill -9 -f sing-box 2>/dev/null || true
sleep 1

# List current utun interfaces (macOS uses utun*, not tun0)
echo "  - Current utun interfaces:"
ifconfig | grep "^utun" | awk '{print "    " $1}' || echo "    (none)"

# Wait for sing-box utun interfaces to be released (utun3+ are likely sing-box)
echo "  - Waiting for TUN interfaces to be released..."
for i in {1..20}; do
    # Count utun interfaces with index >= 3 (utun0-2 are typically system)
    SINGBOX_UTUNS=$(ifconfig | grep -E "^utun[3-9]|^utun[0-9]{2,}" | wc -l | tr -d ' ')
    if [ "$SINGBOX_UTUNS" = "0" ]; then
        echo "  - All sing-box TUN interfaces released"
        break
    fi
    echo "  - Still $SINGBOX_UTUNS utun interface(s) present, waiting... ($i/20)"
    sleep 0.5
done

# Final check
REMAINING=$(ifconfig | grep -E "^utun[3-9]|^utun[0-9]{2,}" | awk '{print $1}' | tr '\n' ' ')
if [ -n "$REMAINING" ]; then
    echo "  - Warning: Some utun interfaces still present: $REMAINING"
    echo "  - They may be released by the time sing-box starts"
fi

# Step 2: Remove old files
echo ""
echo "[2/6] Removing old installation..."
rm -rf "$BINARY_DIR"
rm -f "$PLIST_PATH"

# Step 3: Create runtime directory
echo ""
echo "[3/6] Creating runtime directory..."
mkdir -p "$RUNTIME_DIR"
chmod 0777 "$RUNTIME_DIR"
echo "  - Created $RUNTIME_DIR with mode 0777"

# Step 4: Install binary
echo ""
echo "[4/6] Installing service binary..."
mkdir -p "$BINARY_DIR"
cp "$BUNDLED_BINARY" "$BINARY_PATH"
chmod 0544 "$BINARY_PATH"
chown root:wheel "$BINARY_PATH"
chown root:wheel "$BINARY_DIR"
echo "  - Installed to $BINARY_PATH"

# Step 5: Install plist
echo ""
echo "[5/6] Installing LaunchDaemon plist..."
cp "$BUNDLED_PLIST" "$PLIST_PATH"
chmod 0644 "$PLIST_PATH"
chown root:wheel "$PLIST_PATH"
echo "  - Installed to $PLIST_PATH"

# Step 6: Start service
echo ""
echo "[6/6] Starting service..."
launchctl enable system/"$SERVICE_LABEL"
launchctl bootstrap system "$PLIST_PATH"

# Wait for service to start
sleep 2

# Verify service is running
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo "  - Service started successfully"
    echo ""
    echo "=== Installation Complete ==="
    echo "Service Label: $SERVICE_LABEL"
    echo "Socket Path:   $RUNTIME_DIR/${SERVICE_NAME}.sock"
    exit 0
else
    echo "  - Warning: Service may not have started correctly"
    echo "  - Check logs at $RUNTIME_DIR/${SERVICE_NAME}-stdout.log"
    exit 1
fi
