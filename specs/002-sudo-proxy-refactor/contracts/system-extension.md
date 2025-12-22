# SystemExtension Contract

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-12
**Version**: 1.0

## Overview

`SystemExtension` manages the lifecycle of the `SilentX.System` system extension, providing install, uninstall, and status query functionality.

---

## Class Definition

```swift
#if os(macOS)
import Foundation
import SystemExtensions

/// Manages system extension lifecycle (install, uninstall, status)
/// Adapted from sing-box-for-apple reference implementation
public class SystemExtension: NSObject, OSSystemExtensionRequestDelegate {
    
    // MARK: - Properties
    
    private let forceUpdate: Bool
    private let inBackground: Bool
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: OSSystemExtensionRequest.Result?
    private var properties: [OSSystemExtensionProperties]?
    private var error: Error?
    
    // MARK: - Initialization
    
    private init(_ forceUpdate: Bool = false, _ inBackground: Bool = false) {
        self.forceUpdate = forceUpdate
        self.inBackground = inBackground
    }
    
    // MARK: - Instance Methods
    
    public func activation() throws -> OSSystemExtensionRequest.Result?
    public func deactivation() throws -> OSSystemExtensionRequest.Result?
    public func getProperties() throws -> [OSSystemExtensionProperties]
    
    // MARK: - Static Methods
    
    public static func isInstalled() async -> Bool
    public static func isInstalledBackground() async throws -> Bool
    public static func install(forceUpdate: Bool = false, inBackground: Bool = false) async throws -> OSSystemExtensionRequest.Result?
    public static func uninstall() async throws -> OSSystemExtensionRequest.Result?
}
#endif
```

---

## Method Contracts

### `isInstalled()` (Static)

**Purpose**: Check if system extension is installed and active.

**Returns**: `Bool` - true if extension is installed and not awaiting approval.

**Implementation**:
```swift
public static func isInstalled() async -> Bool {
    await (try? Task {
        try await isInstalledBackground()
    }.result.get()) == true
}

public nonisolated static func isInstalledBackground() async throws -> Bool {
    for _ in 0..<3 {  // Retry up to 3 times
        do {
            let propList = try SystemExtension().getProperties()
            if propList.isEmpty { return false }
            
            for extensionProp in propList {
                // Extension is installed if not awaiting approval and not uninstalling
                if !extensionProp.isAwaitingUserApproval && !extensionProp.isUninstalling {
                    return true
                }
            }
        } catch {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        }
    }
    return false
}
```

---

### `install(forceUpdate:inBackground:)` (Static)

**Purpose**: Install or update the system extension.

**Parameters**:
- `forceUpdate: Bool = false` - Force replacement even if same version
- `inBackground: Bool = false` - Silent update without user interaction

**Returns**: `OSSystemExtensionRequest.Result?`
- `.completed` - Installation finished
- `.willCompleteAfterReboot` - Requires reboot to complete

**Throws**: If user cancels or system denies installation.

**Sequence**:
```
1. Create OSSystemExtensionRequest.activationRequest
2. Set delegate and queue
3. Submit to OSSystemExtensionManager
4. Wait on semaphore
5. Return result or throw error
```

**User Experience**:
```
install() called
        │
        ▼
macOS shows "System Extension Blocked" notification
        │
        ▼
User must open System Preferences > Privacy & Security
        │
        ▼
Click "Allow" next to "SilentX" extension
        │
        ▼
delegate receives requestNeedsUserApproval() or didFinishWithResult()
```

---

### `uninstall()` (Static)

**Purpose**: Remove the system extension.

**Returns**: `OSSystemExtensionRequest.Result?`

**Throws**: If uninstallation fails.

---

### `getProperties()` (Instance)

**Purpose**: Query properties of installed extension.

**Returns**: `[OSSystemExtensionProperties]`

**Properties Available**:
- `bundleIdentifier: String`
- `bundleVersion: String`
- `bundleShortVersion: String`
- `isAwaitingUserApproval: Bool`
- `isUninstalling: Bool`

---

## Delegate Methods

### `request(_:actionForReplacingExtension:withExtension:)`

**Purpose**: Decide whether to replace existing extension.

**Logic**:
```swift
func request(_: OSSystemExtensionRequest, 
             actionForReplacingExtension existing: OSSystemExtensionProperties, 
             withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
    
    if forceUpdate {
        return .replace
    }
    
    if existing.isAwaitingUserApproval && !inBackground {
        return .replace  // User trying to approve again
    }
    
    // Same version → cancel
    if existing.bundleIdentifier == ext.bundleIdentifier &&
       existing.bundleVersion == ext.bundleVersion &&
       existing.bundleShortVersion == ext.bundleShortVersion {
        NSLog("Skip update system extension")
        return .cancel
    }
    
    NSLog("Update system extension")
    return .replace
}
```

---

### `requestNeedsUserApproval(_:)`

**Purpose**: Called when user must approve in System Preferences.

**Action**: Signal semaphore so caller can show appropriate UI.

---

### `request(_:didFinishWithResult:)`

**Purpose**: Called when request completes successfully.

**Action**: Store result and signal semaphore.

---

### `request(_:didFailWithError:)`

**Purpose**: Called when request fails.

**Action**: Store error and signal semaphore.

---

## Extension Identifier

**Bundle Identifier**: `Silent-Net.SilentX.System`

**Usage**:
```swift
let extensionIdentifier = "\(FilePath.packageName).System"
// = "Silent-Net.SilentX.System"
```

---

## Error Handling

### Common Errors

| Error Code | Meaning | User Action |
|------------|---------|-------------|
| `OSSystemExtensionError.requestCanceled` | User cancelled | Prompt to try again |
| `OSSystemExtensionError.authorizationRequired` | Admin password needed | Prompt for password |
| `OSSystemExtensionError.extensionNotFound` | Extension not in bundle | Reinstall app |
| `OSSystemExtensionError.extensionMissingIdentifier` | Info.plist misconfigured | Developer fix needed |
| `OSSystemExtensionError.unknown` | Other system error | Check system logs |

### Error Recovery UI

```swift
do {
    try await SystemExtension.install()
} catch {
    if let sysError = error as? OSSystemExtensionError {
        switch sysError.code {
        case .requestCanceled:
            showAlert("安装已取消，请重试")
        case .authorizationRequired:
            showAlert("需要管理员权限")
        default:
            showAlert("安装失败: \(error.localizedDescription)")
        }
    }
}
```

---

## UI Integration

### Installation Button

```swift
struct InstallSystemExtensionButton: View {
    @State private var alert: AlertState?
    let callback: () async -> Void
    
    var body: some View {
        Button {
            Task { await installSystemExtension() }
        } label: {
            Label("安装系统扩展", systemImage: "lock.doc.fill")
        }
        .alert($alert)
    }
    
    private func installSystemExtension() async {
        do {
            if let result = try await SystemExtension.install() {
                if result == .willCompleteAfterReboot {
                    alert = AlertState(message: "需要重启电脑完成安装")
                }
            }
            await callback()
        } catch {
            alert = AlertState(error: error)
        }
    }
}
```

### Status Indicator

```swift
struct SystemExtensionStatusView: View {
    @State private var isInstalled = false
    
    var body: some View {
        HStack {
            Text("系统扩展")
            Spacer()
            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已安装")
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("未安装")
            }
        }
        .task {
            isInstalled = await SystemExtension.isInstalled()
        }
    }
}
```

---

## Testing Contract

### Unit Tests

```swift
class SystemExtensionTests: XCTestCase {
    
    func testIsInstalledReturnsFalseWhenNotInstalled() async {
        // Requires clean system or mock
    }
    
    func testPropertiesQueryReturnsExtensionInfo() async throws {
        // Requires extension to be installed
    }
}
```

### Manual Test Cases

1. **Fresh Install**:
   - App first launch
   - Click "Install System Extension"
   - Verify System Preferences prompt appears
   - Approve extension
   - Verify `isInstalled()` returns true

2. **Update Existing**:
   - New version of extension in app bundle
   - Call `install(forceUpdate: true)`
   - Verify replacement prompt
   - Approve update
   - Verify new version installed

3. **Uninstall**:
   - Extension is installed
   - Call `uninstall()`
   - Verify extension removed

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-12 | Initial contract definition |
