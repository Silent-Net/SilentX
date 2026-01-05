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
            DispatchQueue.main.async {
                self?.handleOpenMainWindow(target: target)
            }
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
        // Set navigation target if provided (e.g., "Settings")
        if let target = target {
            UserDefaults.standard.set(target, forKey: "pendingNavigation")
        }
        
        // Step 1: Switch to regular activation policy first
        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
        }
        
        // Step 2: Wait for activation policy to take effect
        let activationDelay: TimeInterval = wasAccessory ? 0.2 : 0.05
        
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) { [weak self] in
            self?.activateAndShowWindow()
        }
    }
    
    /// Activate app and show/create main window
    private func activateAndShowWindow() {
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Find existing main window
        let mainWindow = findMainWindow()
        
        if let existingWindow = mainWindow {
            // Window exists - bring it to front
            bringWindowToFront(existingWindow)
        } else {
            // No window exists - create one
            createMainWindow()
        }
    }
    
    /// Find the main application window (not menu bar or popovers)
    private func findMainWindow() -> NSWindow? {
        return NSApp.windows.first { window in
            // Main window criteria:
            // - Can become key (not a panel or popover)
            // - Normal level (not floating)
            // - Reasonable size (not a small accessory window)
            // - Not a status bar or popover window
            guard window.canBecomeKey,
                  window.level == .normal,
                  window.contentView?.frame.width ?? 0 >= 300 else {
                return false
            }
            
            let className = String(describing: type(of: window))
            let isNotStatusOrPopover = !className.contains("NSStatusBarWindow") &&
                                       !className.contains("NSPopover") &&
                                       !className.contains("_NSPopoverWindow")
            
            return isNotStatusOrPopover
        }
    }
    
    /// Bring an existing window to front
    private func bringWindowToFront(_ window: NSWindow) {
        // Deminiaturize if needed
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        // Make sure it's visible
        if !window.isVisible {
            window.setIsVisible(true)
        }
        
        // Bring to front
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    /// Create a new main window
    private func createMainWindow() {
        // Try using the stored openWindow action first
        if let openWindow = storedOpenWindowAction {
            openWindow(id: "main")
            
            // After creating, bring to front (with small delay to let it create)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let window = self?.findMainWindow() {
                    self?.bringWindowToFront(window)
                }
            }
        } else {
            // Fallback: For SwiftUI apps, activating often creates a window automatically
            // Try activating again - macOS may create a window for regular apps
            NSApp.activate(ignoringOtherApps: true)
            
            // Final fallback: use NSApp to deminiaturize all or similar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                if let window = self?.findMainWindow() {
                    self?.bringWindowToFront(window)
                } else {
                    // If still no window, the stored action might now be available
                    // (the activation might have triggered MainView creation)
                    self?.storedOpenWindowAction?(id: "main")
                }
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

