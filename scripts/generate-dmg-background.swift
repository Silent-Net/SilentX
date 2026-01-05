#!/usr/bin/env swift
//
// Generate DMG Background Image
// 
// Since symlinks don't reliably show their target's icon in Finder,
// we draw the Applications folder icon directly on the background.
// The actual symlink is still there for drag-and-drop functionality.
//

import AppKit
import Foundation

// Standard DMG window size
let width: CGFloat = 660
let height: CGFloat = 400

// Icon positions (matching Finder coordinates)
let appIconX: CGFloat = 180
let appFolderX: CGFloat = 480
let iconCenterY: CGFloat = 200  // From top, in Finder coordinates

// Convert to image coordinates (0,0 at bottom-left)
let imgIconY = height - iconCenterY

// Icon size (should match --icon-size in create-dmg)
let iconSize: CGFloat = 100

// Create image
let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()

// Solid dark background
let bgColor = NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
bgColor.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Subtle radial gradient in center
let gradient = NSGradient(colors: [
    NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1.0),
    NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 0.0)
])!
let centerX = width / 2
let centerY = height / 2
gradient.draw(in: NSBezierPath(ovalIn: NSRect(x: centerX - 250, y: centerY - 80, width: 500, height: 180)), 
              relativeCenterPosition: NSPoint(x: 0, y: 0))

// Title
let titleY: CGFloat = height - 55
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 32, weight: .bold),
    .foregroundColor: NSColor.white
]
let title = "SilentX"
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: titleY), withAttributes: titleAttributes)

// Subtitle
let subtitleY: CGFloat = height - 85
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(white: 0.7, alpha: 1.0)
]
let subtitle = "Elegant Proxy Manager for macOS"
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
subtitle.draw(at: NSPoint(x: (width - subtitleSize.width) / 2, y: subtitleY), withAttributes: subtitleAttributes)

// ============================================
// Draw Applications folder icon on background
// ============================================
let appsFolderIconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"
if let appsIcon = NSImage(contentsOfFile: appsFolderIconPath) {
    // Match exact Finder icon position within selection box
    // Finder's item position is center of (icon + label), icon is slightly above center
    let iconDrawSize: CGFloat = iconSize
    // Offset to align with Finder's selection box (negative = move down in visual)
    let verticalOffset: CGFloat = -8
    let appsIconRect = NSRect(
        x: appFolderX - iconDrawSize / 2,
        y: imgIconY - iconDrawSize / 2 + verticalOffset,
        width: iconDrawSize,
        height: iconDrawSize
    )
    appsIcon.draw(in: appsIconRect)
}

// Arrow between icons
let arrowY: CGFloat = imgIconY + 15  // Slightly above center to align with icons
let arrowStartX: CGFloat = appIconX + 65
let arrowEndX: CGFloat = appFolderX - 65

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 10, y: arrowY))
arrowPath.move(to: NSPoint(x: arrowEndX - 18, y: arrowY + 8))
arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 18, y: arrowY - 8))

NSColor(white: 0.5, alpha: 1.0).setStroke()
arrowPath.lineWidth = 2.5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

// Instruction text
let instructionY: CGFloat = 35
let instructionAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(white: 0.55, alpha: 1.0)
]
let instruction = "Drag SilentX to Applications to install"
let instructionSize = instruction.size(withAttributes: instructionAttributes)
instruction.draw(at: NSPoint(x: (width - instructionSize.width) / 2, y: instructionY), withAttributes: instructionAttributes)

image.unlockFocus()

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmapRep = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
    let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✅ Generated DMG background with Applications icon: \(outputPath)")
} else {
    print("❌ Failed to generate background")
    exit(1)
}
