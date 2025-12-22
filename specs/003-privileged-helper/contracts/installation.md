# Service Installation Contract

## Overview

Defines the installation and uninstallation flow for the SilentX Privileged Helper Service, including file locations, permissions, and launchd configuration.

## System Paths

| Path | Description | Owner | Permissions |
|------|-------------|-------|-------------|
| `/Library/PrivilegedHelperTools/silentx-service` | Service binary | root:wheel | 0544 |
| `/Library/LaunchDaemons/com.silentnet.silentx.service.plist` | launchd plist | root:wheel | 0644 |
| `/tmp/silentx/` | Runtime directory | root:wheel | 0755 |
| `/tmp/silentx/silentx-service.sock` | IPC socket | root:wheel | 0666 |
| `/tmp/silentx/service.log` | Service log | root:wheel | 0644 |

---

## LaunchDaemon Plist

**Path**: `/Library/LaunchDaemons/com.silentnet.silentx.service.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.silentnet.silentx.service</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/silentx-service</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/tmp/silentx/service.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/silentx/service.log</string>
    
    <key>WorkingDirectory</key>
    <string>/tmp/silentx</string>
</dict>
</plist>
```

---

## Installation Flow

### Prerequisites

1. Service binary exists at `<app_bundle>/Contents/Resources/silentx-service`
2. Plist template exists at `<app_bundle>/Contents/Resources/launchd.plist.template`
3. User has admin credentials (will be prompted once)

### Installation Script

**Location**: `<app_bundle>/Contents/Resources/install-service.sh`

```bash
#!/bin/bash
set -e

SERVICE_BINARY="/Library/PrivilegedHelperTools/silentx-service"
SERVICE_PLIST="/Library/LaunchDaemons/com.silentnet.silentx.service.plist"
SERVICE_LABEL="com.silentnet.silentx.service"
RUNTIME_DIR="/tmp/silentx"

# Source paths (passed as arguments)
SOURCE_BINARY="$1"
SOURCE_PLIST="$2"

# Create runtime directory
mkdir -p "$RUNTIME_DIR"
chmod 755 "$RUNTIME_DIR"

# Stop existing service if running
launchctl bootout system/"$SERVICE_LABEL" 2>/dev/null || true

# Install binary
mkdir -p /Library/PrivilegedHelperTools
cp "$SOURCE_BINARY" "$SERVICE_BINARY"
chmod 544 "$SERVICE_BINARY"
chown root:wheel "$SERVICE_BINARY"

# Install plist
cp "$SOURCE_PLIST" "$SERVICE_PLIST"
chmod 644 "$SERVICE_PLIST"
chown root:wheel "$SERVICE_PLIST"

# Load and start service
launchctl bootstrap system "$SERVICE_PLIST"
launchctl enable system/"$SERVICE_LABEL"

echo "Service installed successfully"
```

### Installation from Swift App

```swift
func installService() async throws {
    let sourceBinary = Bundle.main.resourceURL!
        .appendingPathComponent("silentx-service")
    let sourcePlist = Bundle.main.resourceURL!
        .appendingPathComponent("launchd.plist.template")
    let installScript = Bundle.main.resourceURL!
        .appendingPathComponent("install-service.sh")
    
    // Execute with admin privileges (single password prompt)
    let command = """
        /bin/bash '\(installScript.path)' '\(sourceBinary.path)' '\(sourcePlist.path)'
    """.replacingOccurrences(of: "'", with: "'\"'\"'")
    
    let script = "do shell script \"\(command)\" with administrator privileges"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        throw ServiceError.installFailed
    }
}
```

---

## Uninstallation Flow

### Uninstall Script

**Location**: `<app_bundle>/Contents/Resources/uninstall-service.sh`

```bash
#!/bin/bash
set -e

SERVICE_PLIST="/Library/LaunchDaemons/com.silentnet.silentx.service.plist"
SERVICE_BINARY="/Library/PrivilegedHelperTools/silentx-service"
SERVICE_LABEL="com.silentnet.silentx.service"
RUNTIME_DIR="/tmp/silentx"

# Stop and remove service
launchctl bootout system/"$SERVICE_LABEL" 2>/dev/null || true

# Remove files
rm -f "$SERVICE_PLIST"
rm -f "$SERVICE_BINARY"
rm -rf "$RUNTIME_DIR"

echo "Service uninstalled successfully"
```

### Uninstallation from Swift App

```swift
func uninstallService() async throws {
    let uninstallScript = Bundle.main.resourceURL!
        .appendingPathComponent("uninstall-service.sh")
    
    let command = "/bin/bash '\(uninstallScript.path)'"
        .replacingOccurrences(of: "'", with: "'\"'\"'")
    
    let script = "do shell script \"\(command)\" with administrator privileges"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        throw ServiceError.uninstallFailed
    }
}
```

---

## Status Checking

### Check if Service is Installed

```swift
func isServiceInstalled() -> Bool {
    let binaryExists = FileManager.default.fileExists(
        atPath: "/Library/PrivilegedHelperTools/silentx-service"
    )
    let plistExists = FileManager.default.fileExists(
        atPath: "/Library/LaunchDaemons/com.silentnet.silentx.service.plist"
    )
    return binaryExists && plistExists
}
```

### Check if Service is Running

```swift
func isServiceRunning() async -> Bool {
    // Method 1: Check if socket exists and is responsive
    let socketPath = "/tmp/silentx/silentx-service.sock"
    guard FileManager.default.fileExists(atPath: socketPath) else {
        return false
    }
    
    // Method 2: Try to connect and send version command
    do {
        let client = IPCClient()
        let response = try await client.sendCommand(.version)
        return response.success
    } catch {
        return false
    }
}
```

---

## Version Upgrade Flow

When upgrading the service:

1. Stop existing service via IPC (`stop` command)
2. Run installation script (replaces binary and plist)
3. Service restarts automatically via launchd

```swift
func upgradeService() async throws {
    // Stop sing-box if running
    if await isServiceRunning() {
        let client = IPCClient()
        _ = try? await client.sendCommand(.stop)
    }
    
    // Install new version (this stops/starts the daemon)
    try await installService()
}
```

---

## Error Handling

### Installation Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| `PERMISSION_DENIED` | User cancelled password dialog | Retry installation |
| `BINARY_NOT_FOUND` | Source binary missing from bundle | Reinstall app |
| `PLIST_NOT_FOUND` | Source plist missing from bundle | Reinstall app |
| `LAUNCHCTL_FAILED` | launchctl command failed | Check system logs |

### Runtime Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| `SOCKET_NOT_FOUND` | Service not running | Run installation |
| `CONNECTION_REFUSED` | Service crashed | Check `/tmp/silentx/service.log` |
| `TIMEOUT` | Service unresponsive | Restart service |
