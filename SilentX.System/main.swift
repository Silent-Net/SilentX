//
//  main.swift
//  SilentX.System
//
//  Entry point for the System Extension
//  Adapted from sing-box-for-apple reference implementation
//

import Foundation
import NetworkExtension

// Start the packet tunnel provider in system extension mode
// This allows the extension to run without being embedded in the app
autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

// Keep the extension running
dispatchMain()
