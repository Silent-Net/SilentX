//
//  EditNodeSheet.swift
//  SilentX
//
//  Form modal for editing an existing proxy node
//

import SwiftUI
import SwiftData

/// Sheet for editing an existing proxy node
struct EditNodeSheet: View {
    @Bindable var node: ProxyNode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var protocolType: ProxyProtocol = .shadowsocks
    @State private var server: String = ""
    @State private var port: String = ""
    
    // Protocol-specific fields
    @State private var password: String = ""
    @State private var uuid: String = ""
    @State private var method: String = "aes-256-gcm"
    @State private var alterId: String = ""
    @State private var security: String = "auto"
    @State private var username: String = ""
    @State private var upMbps: String = ""
    @State private var downMbps: String = ""
    
    // TLS settings
    @State private var tlsEnabled: Bool = false
    @State private var sni: String = ""
    @State private var skipCertVerify: Bool = false
    
    @State private var validationError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Basic Information") {
                    TextField("Name", text: $name, prompt: Text("e.g., Hong Kong Server"))
                    
                    Picker("Protocol", selection: $protocolType) {
                        ForEach(ProxyProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                    
                    TextField("Server Address", text: $server, prompt: Text("example.com"))
                        .autocorrectionDisabled()
                    
                    TextField("Port", text: $port, prompt: Text("443"))
                        .autocorrectionDisabled()
                }
                
                // Protocol-specific fields
                protocolFieldsSection
                
                // TLS settings
                Section("TLS Settings") {
                    Toggle("Enable TLS", isOn: $tlsEnabled)
                    
                    if tlsEnabled {
                        TextField("SNI (Server Name)", text: $sni, prompt: Text("Optional"))
                            .autocorrectionDisabled()
                        
                        Toggle("Skip Certificate Verification", isOn: $skipCertVerify)
                    }
                }
                
                // Validation error
                if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNode()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            loadNodeData()
        }
    }
    
    @ViewBuilder
    private var protocolFieldsSection: some View {
        switch protocolType {
        case .shadowsocks:
            Section("Shadowsocks Settings") {
                Picker("Encryption Method", selection: $method) {
                    ForEach(shadowsocksMethods, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                
                SecureField("Password", text: $password)
            }
            
        case .vmess, .vless:
            Section("\(protocolType.displayName) Settings") {
                TextField("UUID", text: $uuid, prompt: Text("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"))
                    .autocorrectionDisabled()
                
                if protocolType == .vmess {
                    TextField("Alter ID", text: $alterId, prompt: Text("0"))
                }
                
                Picker("Security", selection: $security) {
                    ForEach(vmessSecurity, id: \.self) { sec in
                        Text(sec).tag(sec)
                    }
                }
            }
            
        case .trojan:
            Section("Trojan Settings") {
                SecureField("Password", text: $password)
            }
            
        case .hysteria2:
            Section("Hysteria2 Settings") {
                SecureField("Password", text: $password)
                
                HStack {
                    TextField("Upload Speed (Mbps)", text: $upMbps, prompt: Text("100"))
                    TextField("Download Speed (Mbps)", text: $downMbps, prompt: Text("100"))
                }
            }
            
        case .http, .socks5:
            Section("\(protocolType.displayName) Settings") {
                TextField("Username (Optional)", text: $username)
                    .autocorrectionDisabled()
                
                SecureField("Password (Optional)", text: $password)
            }
        }
    }
    
    private var shadowsocksMethods: [String] {
        [
            "aes-256-gcm",
            "aes-128-gcm",
            "chacha20-ietf-poly1305",
            "2022-blake3-aes-256-gcm",
            "2022-blake3-aes-128-gcm",
            "2022-blake3-chacha20-poly1305"
        ]
    }
    
    private var vmessSecurity: [String] {
        ["auto", "aes-128-gcm", "chacha20-poly1305", "none", "zero"]
    }
    
    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        guard !server.isEmpty else { return false }
        guard let portNum = Int(port), portNum > 0, portNum <= 65535 else { return false }
        
        switch protocolType {
        case .shadowsocks:
            return !password.isEmpty
        case .vmess, .vless:
            return !uuid.isEmpty
        case .trojan, .hysteria2:
            return !password.isEmpty
        case .http, .socks5:
            return true // Auth is optional
        }
    }
    
    private func loadNodeData() {
        name = node.name
        protocolType = node.protocolType
        server = node.server
        port = String(node.port)
        
        password = node.password ?? ""
        uuid = node.uuid ?? ""
        method = node.method ?? "aes-256-gcm"
        alterId = node.alterId.map { String($0) } ?? ""
        security = node.security ?? "auto"
        username = node.username ?? ""
        upMbps = node.upMbps.map { String($0) } ?? ""
        downMbps = node.downMbps.map { String($0) } ?? ""
        
        tlsEnabled = node.tls
        sni = node.sni ?? ""
        skipCertVerify = node.skipCertVerify
    }
    
    private func saveNode() {
        guard let portNum = Int(port) else {
            validationError = "Invalid port number"
            return
        }
        
        node.name = name
        node.protocolType = protocolType
        node.server = server
        node.port = portNum
        
        // Clear all optional fields first
        node.password = nil
        node.uuid = nil
        node.method = nil
        node.alterId = nil
        node.security = nil
        node.username = nil
        node.upMbps = nil
        node.downMbps = nil
        
        // Set protocol-specific fields
        switch protocolType {
        case .shadowsocks:
            node.method = method
            node.password = password
            
        case .vmess, .vless:
            node.uuid = uuid
            if let alterIdNum = Int(alterId) {
                node.alterId = alterIdNum
            }
            node.security = security
            
        case .trojan:
            node.password = password
            
        case .hysteria2:
            node.password = password
            if let up = Int(upMbps) {
                node.upMbps = up
            }
            if let down = Int(downMbps) {
                node.downMbps = down
            }
            
        case .http, .socks5:
            if !username.isEmpty {
                node.username = username
            }
            if !password.isEmpty {
                node.password = password
            }
        }
        
        // Set TLS settings
        node.tls = tlsEnabled
        node.sni = nil
        node.skipCertVerify = false
        
        if tlsEnabled {
            if !sni.isEmpty {
                node.sni = sni
            }
            node.skipCertVerify = skipCertVerify
        }
        
        node.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
    }
}

#Preview {
    EditNodeSheet(node: ProxyNode(
        name: "Test Server",
        protocolType: .vmess,
        server: "test.example.com",
        port: 443
    ))
    .modelContainer(for: ProxyNode.self, inMemory: true)
}
