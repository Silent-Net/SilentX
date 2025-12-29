# SilentX

A modern, native macOS VPN/Proxy client built with SwiftUI.

## Overview

SilentX is a sleek and powerful proxy management application for macOS that provides a seamless experience for managing network connections through various proxy protocols. Built entirely with Swift and SwiftUI, it follows Apple's Human Interface Guidelines for a native macOS experience.

## Features

- **Native macOS App** — Built with SwiftUI for a modern, responsive interface
- **Menu Bar Integration** — Quick access to connection controls from the menu bar
- **Multiple Proxy Modes** — Support for Global, Rule-based, and Direct proxy modes
- **Profile Management** — Create, import, and manage multiple proxy configurations
- **System Proxy Control** — One-click system proxy toggle
- **Auto-Connect** — Optionally connect on app launch
- **Hide from Dock** — Run silently from the menu bar only
- **Dark/Light Mode** — Full support for macOS appearance settings

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for development)

## Architecture

```
SilentX/
├── SilentX/           # Main app target
│   ├── Views/         # SwiftUI views
│   ├── Services/      # Core services (ConnectionService, etc.)
│   ├── Models/        # Data models
│   └── Shared/        # Shared utilities
├── SilentX-Service/   # Privileged helper service
├── SilentX-Extension/ # Network extension
└── SilentXTests/      # Unit tests
```

## Tech Stack

- **UI**: SwiftUI
- **Data**: SwiftData
- **Networking**: sing-box core
- **Architecture**: MVVM with shared services

## Building

1. Clone the repository
2. Open `SilentX.xcodeproj` in Xcode
3. Select the `SilentX` scheme
4. Build and run (⌘R)

## License

Private — All rights reserved.
