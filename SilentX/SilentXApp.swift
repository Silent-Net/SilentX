//
//  SilentXApp.swift
//  SilentX
//
//  Created by xmx on 6/12/2025.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct SilentXApp: App {
    
    /// Track first launch for onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showWelcome = false
    
    /// Appearance settings
    @AppStorage("colorScheme") private var colorScheme = AppColorScheme.system
    @AppStorage("accentColor") private var accentColor = AppAccentColor.blue
    
    init() {
        // Disable window restoration during tests to prevent crash on reopening
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        }
        
        // T059: Create App Group shared directory on first launch
        setupSharedContainers()
    }
    
    /// Setup shared containers for App Group communication with System Extension
    private func setupSharedContainers() {
        let fileManager = FileManager.default
        
        // Create App Group container directories
        if let groupContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: FilePath.groupIdentifier) {
            let directories = [
                groupContainer,
                groupContainer.appendingPathComponent("Working"),
                groupContainer.appendingPathComponent("Cache"),
                groupContainer.appendingPathComponent("Logs")
            ]
            
            for directory in directories {
                if !fileManager.fileExists(atPath: directory.path) {
                    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }
            }
        }
        
        // Also ensure standard app support directories exist
        let appSupportDirs = [
            FilePath.applicationSupport,
            FilePath.profiles,
            FilePath.cores,
            FilePath.logs
        ]
        
        for directory in appSupportDirs {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    /// Shared SwiftData model container
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Profile.self,
            ProxyNode.self,
            RoutingRule.self,
            CoreVersion.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Migrate existing profiles to add preferredEngine field
            let context = container.mainContext
            let descriptor = FetchDescriptor<Profile>()
            if let profiles = try? context.fetch(descriptor) {
                for profile in profiles {
                    // SwiftData will automatically set default value from init
                    // Just trigger a save to persist the migration
                    try? context.save()
                }
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var sharedModelContainer: ModelContainer {
        SilentXApp.sharedModelContainer
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                // Don't use preferredColorScheme - it conflicts with NSApp.appearance
                // and causes lag. NSApp.appearance is the proper macOS way.
                .tint(accentColor.color)
                .sheet(isPresented: $showWelcome) {
                    WelcomeView()
                }
                .onAppear {
                    // Show welcome view on first launch
                    if !hasCompletedOnboarding {
                        showWelcome = true
                    }
                    // Apply initial appearance immediately
                    applyColorScheme()
                }
                .onChange(of: colorScheme) { _, _ in
                    // Apply appearance change immediately when setting changes
                    applyColorScheme()
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            // Add app-specific commands
            SidebarCommands()
            
            // Help menu
            CommandGroup(replacing: .help) {
                Button("SilentX Help") {
                    // Open help documentation
                }
                .keyboardShortcut("?", modifiers: .command)
                
                Divider()
                
                Button("Show Welcome") {
                    showWelcome = true
                }
            }
        }
        
        // Settings window
        #if os(macOS)
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
        #endif
    }
    
    // MARK: - Appearance Helpers
    
    #if os(macOS)
    /// Apply color scheme using NSApp.appearance for proper macOS behavior
    private func applyColorScheme() {
        // Setting NSApp.appearance directly is the canonical macOS way
        // nil means follow system setting
        NSApp.appearance = colorScheme.nsAppearance
    }
    #else
    private func applyColorScheme() {
        // On iOS, preferredColorScheme modifier handles this
    }
    #endif
}
