//
//  AddNodeSheet.swift
//  SilentX
//
//  Form modal for adding a new proxy node
//

import SwiftUI
import SwiftData

/// Sheet for adding a new proxy node
struct AddNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var protocolType: ProxyProtocol = .shadowsocks
    @State private var server = ""
    @State private var port = ""
    
    // Protocol-specific fields
    @State private var password = ""
    @State private var uuid = ""
    @State private var method = "aes-256-gcm"
    @State private var alterId = ""
    @State private var security = "auto"
    @State private var username = ""
    @State private var upMbps = ""
    @State private var downMbps = ""
    
    // TLS settings
    @State private var tlsEnabled = false
    @State private var sni = ""
    @State private var skipCertVerify = false
    
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
            .navigationTitle("Add Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addNode()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
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
    
    private func addNode() {
        guard let portNum = Int(port) else {
            validationError = "Invalid port number"
            return
        }
        
        let node = ProxyNode(
            name: name,
            protocolType: protocolType,
            server: server,
            port: portNum
        )
        
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
        if tlsEnabled {
            if !sni.isEmpty {
                node.sni = sni
            }
            node.skipCertVerify = skipCertVerify
        }
        
        modelContext.insert(node)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
    }
}

#Preview {
    AddNodeSheet()
        .modelContainer(for: ProxyNode.self, inMemory: true)
}
