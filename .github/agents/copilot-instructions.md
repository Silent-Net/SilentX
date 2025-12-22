# SilentX Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-06

## Active Technologies
- Swift 5.9+ (iOS 15+/macOS 12+ SDKs) (002-sudo-proxy-refactor)
- Swift 5.9 (macOS native, same as main app) + Foundation, Network.framework (for NWConnection Unix socket), Darwin (BSD sockets for service) (003-privileged-helper)
- File-based (config JSON, logs in /tmp/silentx/) (003-privileged-helper)
- Swift 5.9 (主 App), Swift 5.9 (服务二进制) + Foundation, Network (Unix Socket), OSLog (003-privileged-helper)
- 文件系统 - `/Library/LaunchDaemons/`, `/Library/PrivilegedHelperTools/`, Unix Socket `/tmp/silentx/` (003-privileged-helper)
- Swift 5.9+ (Xcode 15+) + Foundation, os.log, Network (BSD sockets), SwiftData (003-privileged-helper)
- SwiftData for Profile model, JSON config files on disk (003-privileged-helper)
- Swift 5.x (Xcode toolchain) + SwiftUI, Combine, SwiftData, OSLog, Foundation, (service-side) POSIX/Network (003-privileged-helper)
- Files under `~/Library/Application Support/Silent-Net.SilentX/` + SwiftData for versions/profiles (003-privileged-helper)

- Swift 5.9+, SwiftUI + SwiftUI, SwiftData, NetworkExtension, SystemExtensions, Libbox (Sing-Box Go library) (001-macos-proxy-gui)
- URLSession (async/await), Codable (JSON parsing), CryptoKit (SHA256), FileManager (GitHub Releases API integration)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 5.9+, SwiftUI

## Code Style

Swift 5.9+, SwiftUI: Follow standard conventions

## Recent Changes
- 003-privileged-helper: Added Swift 5.x (Xcode toolchain) + SwiftUI, Combine, SwiftData, OSLog, Foundation, (service-side) POSIX/Network
- 003-privileged-helper: Added Swift 5.9+ (Xcode 15+) + Foundation, os.log, Network (BSD sockets), SwiftData
- 003-privileged-helper: Added Swift 5.9 (主 App), Swift 5.9 (服务二进制) + Foundation, Network (Unix Socket), OSLog


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
