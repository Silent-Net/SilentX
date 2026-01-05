//
//  WindowManager.swift
//  SilentX
//
//  Manages window operations for menu bar integration
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Global window manager for reliable window operations from menu bar
/// Solves the problem of opening windows when app is in accessory mode
final class WindowManager {
    
    static let shared = WindowManager()
    
    /// Stored openWindow action - captured from a view that has the environment
    private var storedOpenWindowAction: OpenWindowAction?
    
    /// Track if window creation is in progress to prevent duplicate attempts
    private var isCreatingWindow = false
    
    private init() {
        #if os(macOS)
        // Listen for window open requests on main queue
        NotificationCenter.default.addObserver(
            forName: .openMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract the object on the notification queue before dispatching
            let target = notification.object as? String
            // Use sync dispatch since we're already on main queue from notification
            self?.handleOpenMainWindow(target: target)
        }
        #endif
    }
    
    /// Store the openWindow action for later use
    /// Called from a view that has access to @Environment(\.openWindow)
    func registerOpenWindowAction(_ action: OpenWindowAction) {
        storedOpenWindowAction = action
    }
    
    #if os(macOS)
    /// Handle request to open main window
    /// - Parameter target: Optional navigation target (e.g., "Settings")
    private func handleOpenMainWindow(target: String?) {
        // Prevent duplicate window creation attempts
        guard !isCreatingWindow else { return }
        isCreatingWindow = true
        
        // Set navigation target if provided (e.g., "Settings")
        if let target = target {
            UserDefaults.standard.set(target, forKey: "pendingNavigation")
        }
        
        // Step 1: Switch to regular activation policy first
        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
            // Run loop to process the policy change
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        
        // Step 2: Activate immediately (no delay for better responsiveness)
        NSApp.activate(ignoringOtherApps: true)
        
        // Step 3: Find or create window - use short delay only if was accessory
        let delay: TimeInterval = wasAccessory ? 0.1 : 0.0
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.showOrCreateWindow()
            }
        } else {
            showOrCreateWindow()
        }
    }
    
    /// Show existing window or create new one
    private func showOrCreateWindow() {
        defer { isCreatingWindow = false }
        
        // Try to find existing main window
        if let existingWindow = findMainWindow() {
            bringWindowToFront(existingWindow)
            return
        }
        
        // No window exists - create one
        createMainWindow()
    }
    
    /// Find the main application window (not menu bar or popovers)
    private func findMainWindow() -> NSWindow? {
        // Sort windows by key status to prefer the key window
        let candidateWindows = NSApp.windows.filter { window in
            // Must be able to become key
            guard window.canBecomeKey else { return false }
            
            // Must be normal level (not floating panels)
            guard window.level == .normal else { return false }
            
            // Must have reasonable size (not a small accessory)
            guard window.frame.width >= 300 || window.contentView?.frame.width ?? 0 >= 300 else { return false }
            
            // Filter out status bar and popover windows by class name
            let className = String(describing: type(of: window))
            guard !className.contains("NSStatusBarWindow"),
                  !className.contains("NSPopover"),
                  !className.contains("_NSPopoverWindow"),
                  !className.contains("MenuBarExtra") else {
                return false
            }
            
            return true
        }
        
        // Prefer key window, then visible window, then any candidate
        return candidateWindows.first { $0.isKeyWindow }
            ?? candidateWindows.first { $0.isVisible }
            ?? candidateWindows.first
    }
    
    /// Bring an existing window to front
    private func bringWindowToFront(_ window: NSWindow) {
        // Deminiaturize if minimized
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        // Make visible if hidden
        if !window.isVisible {
            window.setIsVisible(true)
        }
        
        // Bring to front - use multiple methods for reliability
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Re-activate to ensure app is in foreground
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Create a new main window
    private func createMainWindow() {
        // Method 1: Use stored openWindow action (most reliable if available)
        if let openWindow = storedOpenWindowAction {
            openWindow(id: "main")
            
            // Brief delay to let window create, then ensure it's visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let window = self?.findMainWindow() {
                    self?.bringWindowToFront(window)
                }
            }
            return
        }
        
        // Method 2: Try to trigger window creation via activation
        // For SwiftUI apps with WindowGroup, activation in regular mode often creates a window
        NSApp.activate(ignoringOtherApps: true)
        
        // Check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let window = self?.findMainWindow() {
                self?.bringWindowToFront(window)
            } else if let openWindow = self?.storedOpenWindowAction {
                // The activation might have registered the action - try again
                openWindow(id: "main")
            }
        }
    }
    #endif
}

// MARK: - View Extension for Registering OpenWindow

struct WindowManagerRegistration: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                WindowManager.shared.registerOpenWindowAction(openWindow)
            }
    }
}

extension View {
    /// Register the openWindow action with WindowManager for use from menu bar
    func registerWithWindowManager() -> some View {
        modifier(WindowManagerRegistration())
    }
}

