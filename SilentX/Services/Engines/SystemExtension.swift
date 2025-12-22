//
//  SystemExtension.swift
//  SilentX
//
//  Manages the lifecycle of SilentX.System system extension
//  Adapted from sing-box-for-apple reference implementation
//

#if os(macOS)
import Foundation
import SystemExtensions
import OSLog

/// Manages system extension lifecycle (install, uninstall, status)
/// T041-T042: Implements OSSystemExtensionRequestDelegate
public class SystemExtension: NSObject, OSSystemExtensionRequestDelegate {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "SystemExtension")
    private let forceUpdate: Bool
    private let inBackground: Bool
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: OSSystemExtensionRequest.Result?
    private var properties: [OSSystemExtensionProperties]?
    private var error: Error?
    
    /// Background queue for delegate callbacks to avoid deadlock with semaphore
    private static let delegateQueue = DispatchQueue(label: "com.silentnet.silentx.systemextension.delegate")
    
    /// Extension bundle identifier
    private static var extensionIdentifier: String {
        "\(FilePath.packageName).System"
    }
    
    // MARK: - Initialization
    
    private init(_ forceUpdate: Bool = false, _ inBackground: Bool = false) {
        self.forceUpdate = forceUpdate
        self.inBackground = inBackground
        super.init()
    }
    
    // MARK: - Instance Methods
    
    /// Submit an activation request for the system extension
    public func activation() throws -> OSSystemExtensionRequest.Result? {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: Self.delegateQueue
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        return result
    }
    
    /// Submit a deactivation request for the system extension
    public func deactivation() throws -> OSSystemExtensionRequest.Result? {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: Self.delegateQueue
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        return result
    }
    
    /// Query properties of the installed extension
    public func getProperties() throws -> [OSSystemExtensionProperties] {
        let request = OSSystemExtensionRequest.propertiesRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: Self.delegateQueue
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        return properties ?? []
    }
    
    // MARK: - Static Methods
    
    /// Check if system extension is installed and active
    public static func isInstalled() async -> Bool {
        await (try? Task {
            try await isInstalledBackground()
        }.result.get()) == true
    }
    
    /// Background check for extension installation status
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
                return false
            } catch {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
        }
        return false
    }
    
    /// Install or update the system extension
    /// - Parameters:
    ///   - forceUpdate: Force replacement even if same version
    ///   - inBackground: Silent update without user interaction
    /// - Returns: Installation result
    public static func install(forceUpdate: Bool = false, inBackground: Bool = false) async throws -> OSSystemExtensionRequest.Result? {
        try await Task.detached {
            try SystemExtension(forceUpdate, inBackground).activation()
        }.result.get()
    }
    
    /// Uninstall the system extension
    public static func uninstall() async throws -> OSSystemExtensionRequest.Result? {
        try await Task.detached {
            try SystemExtension().deactivation()
        }.result.get()
    }
    
    // MARK: - OSSystemExtensionRequestDelegate
    
    public func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        
        if forceUpdate {
            logger.info("Force updating system extension")
            return .replace
        }
        
        if existing.isAwaitingUserApproval && !inBackground {
            logger.info("Replacing extension awaiting approval")
            return .replace  // User trying to approve again
        }
        
        // Same version → cancel
        if existing.bundleIdentifier == ext.bundleIdentifier &&
           existing.bundleVersion == ext.bundleVersion &&
           existing.bundleShortVersion == ext.bundleShortVersion {
            logger.info("Skip update system extension (same version)")
            return .cancel
        }
        
        logger.info("Updating system extension from \(existing.bundleVersion) to \(ext.bundleVersion)")
        return .replace
    }
    
    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension needs user approval in System Preferences")
        // Signal semaphore so caller can show appropriate UI guidance
        semaphore.signal()
    }
    
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension request finished with result: \(String(describing: result))")
        self.result = result
        semaphore.signal()
    }
    
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed: \(error.localizedDescription)")
        self.error = error
        semaphore.signal()
    }
    
    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        logger.debug("Found \(properties.count) extension properties")
        self.properties = properties
        semaphore.signal()
    }
}
#endif
