//
//  JSONEditorView.swift
//  SilentX
//
//  JSON editor with syntax highlighting and validation
//

import SwiftUI
import Combine

/// JSON Editor view with syntax highlighting and real-time validation
struct JSONEditorView: View {
    @Binding var jsonText: String
    let profileName: String
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var configService = ConfigurationService()
    
    @State private var validationResult: ConfigValidationResult?
    @State private var isValidating = false
    @State private var showSaveConfirmation = false
    @State private var hasUnsavedChanges = false
    @State private var originalText = ""
    
    // Debounced validation
    @State private var validationDebounce = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    private var isValid: Bool {
        validationResult?.isValid ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Main content
            HSplitView {
                // Editor pane
                editorPane
                    .frame(minWidth: 400)
                
                // Validation pane
                validationPane
                    .frame(minWidth: 250, maxWidth: 350)
            }
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            originalText = jsonText
            setupValidationDebounce()
            validateJSON(jsonText)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JSON Editor")
                    .font(.headline)
                
                Text("Editing: \(profileName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Validation status badge
            if isValidating {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Validating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let result = validationResult {
                HStack(spacing: 4) {
                    Image(systemName: result.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(result.isValid ? .green : .orange)
                    
                    Text(result.isValid ? "Valid JSON" : "\(result.errors.count) issue(s)")
                        .font(.caption)
                        .foregroundStyle(result.isValid ? .green : .orange)
                }
            }
            
            if hasUnsavedChanges {
                Text("Unsaved Changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
    
    private var editorPane: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Configuration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    formatJSON()
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button {
                    jsonText = originalText
                    hasUnsavedChanges = false
                } label: {
                    Label("Revert", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(!hasUnsavedChanges)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))
            
            // Text editor
            JSONTextEditor(text: $jsonText)
                .onChange(of: jsonText) { _, newValue in
                    hasUnsavedChanges = newValue != originalText
                    validationDebounce.send(newValue)
                }
        }
    }
    
    private var validationPane: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Validation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))
            
            // Validation results
            if let result = validationResult {
                ValidationErrorsView(result: result)
            } else {
                ContentUnavailableView(
                    "No Validation",
                    systemImage: "checkmark.circle",
                    description: Text("Enter JSON to validate")
                )
            }
        }
    }
    
    private var footer: some View {
        HStack {
            // Statistics
            HStack(spacing: 16) {
                Text("\(jsonText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(jsonText.components(separatedBy: "\n").count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                if hasUnsavedChanges {
                    showSaveConfirmation = true
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Save") {
                onSave(jsonText)
                originalText = jsonText
                hasUnsavedChanges = false
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    private func setupValidationDebounce() {
        validationDebounce
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { text in
                validateJSON(text)
            }
            .store(in: &cancellables)
    }
    
    private func validateJSON(_ text: String) {
        isValidating = true
        
        // Run validation asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            let result = configService.validate(json: text)
            
            DispatchQueue.main.async {
                validationResult = result
                isValidating = false
            }
        }
    }
    
    private func formatJSON() {
        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let formattedString = String(data: formatted, encoding: .utf8) else {
            return
        }
        
        jsonText = formattedString
    }
}

/// Custom JSON text editor with syntax highlighting
struct JSONTextEditor: View {
    @Binding var text: String
    @State private var lineNumbers: [Int] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(lineNumbers, id: \.self) { lineNumber in
                        Text("\(lineNumber)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(height: 18)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 40)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(.textBackgroundColor))
                .onChange(of: text) { _, newValue in
                    updateLineNumbers(newValue)
                }
                .onAppear {
                    updateLineNumbers(text)
                }
        }
    }
    
    private func updateLineNumbers(_ text: String) {
        let lines = text.components(separatedBy: "\n").count
        lineNumbers = Array(1...max(1, lines))
    }
}

/// View for displaying validation errors
struct ValidationErrorsView: View {
    let result: ConfigValidationResult
    
    var body: some View {
        List {
            if result.isValid {
                // Success section
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Valid Configuration")
                                .font(.headline)
                            
                            Text("No errors found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Warnings if any
                if !result.warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(result.warnings) { warning in
                            ValidationMessageRow(
                                icon: "exclamationmark.triangle.fill",
                                color: .yellow,
                                message: warning.message,
                                line: nil
                            )
                        }
                    }
                }
            } else {
                // Errors section
                Section("Errors") {
                    ForEach(result.errors) { error in
                        ValidationMessageRow(
                            icon: "xmark.circle.fill",
                            color: .red,
                            message: error.message,
                            line: error.line
                        )
                    }
                }
                
                // Warnings if any
                if !result.warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(result.warnings) { warning in
                            ValidationMessageRow(
                                icon: "exclamationmark.triangle.fill",
                                color: .yellow,
                                message: warning.message,
                                line: nil
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

/// Row view for a validation message
struct ValidationMessageRow: View {
    let icon: String
    let color: Color
    let message: String
    let line: Int?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.caption)
                
                if let line = line {
                    Text("Line \(line)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    JSONEditorView(
        jsonText: .constant("""
        {
            "log": {
                "level": "info"
            },
            "outbounds": [
                {
                    "type": "direct",
                    "tag": "direct"
                }
            ]
        }
        """),
        profileName: "Test Profile"
    ) { _ in }
}
