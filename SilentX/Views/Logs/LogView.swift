//
//  LogView.swift
//  SilentX
//
//  Log viewer with filtering capabilities
//

import SwiftUI

/// Main log viewer view
struct LogView: View {
    @StateObject private var logService = LogService()
    @State private var filter = LogFilter()
    @State private var autoScroll = true
    @State private var showExportPanel = false
    @State private var selectedEntry: LogEntry?
    
    private var filteredEntries: [LogEntry] {
        filter.apply(to: logService.entries)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter toolbar
            filterToolbar
            
            Divider()
            
            // Log list
            logList
            
            Divider()
            
            // Status bar
            statusBar
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $autoScroll) {
                    Label("Auto Scroll", systemImage: "arrow.down.to.line")
                }
                .toggleStyle(.button)
                
                Button {
                    showExportPanel = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    logService.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
        .onAppear {
            logService.start()
        }
        .onDisappear {
            logService.stop()
        }
        .fileExporter(
            isPresented: $showExportPanel,
            document: LogDocument(entries: filteredEntries),
            contentType: .plainText,
            defaultFilename: "silentx-logs-\(Date().formatted(date: .numeric, time: .omitted))"
        ) { result in
            // Handle export result
        }
    }
    
    private var filterToolbar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs...", text: $filter.searchText)
                    .textFieldStyle(.plain)
                
                if !filter.searchText.isEmpty {
                    Button {
                        filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Divider()
                .frame(height: 20)
            
            // Level filter
            Picker("Level", selection: $filter.minLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.displayName, systemImage: level.iconName)
                        .tag(level)
                }
            }
            .frame(width: 120)
            
            // Category filter
            Menu {
                Button("All Categories") {
                    filter.categories.removeAll()
                }
                
                Divider()
                
                ForEach(LogCategory.allCategories, id: \.self) { category in
                    Toggle(category, isOn: Binding(
                        get: { filter.categories.contains(category) || filter.categories.isEmpty },
                        set: { isOn in
                            if isOn {
                                if filter.categories.isEmpty {
                                    filter.categories = Set(LogCategory.allCategories)
                                }
                                filter.categories.insert(category)
                            } else {
                                if filter.categories.isEmpty {
                                    filter.categories = Set(LogCategory.allCategories)
                                }
                                filter.categories.remove(category)
                            }
                        }
                    ))
                }
            } label: {
                Label(
                    filter.categories.isEmpty ? "All Categories" : "\(filter.categories.count) Selected",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredEntries, selection: $selectedEntry) { entry in
                LogEntryRowView(entry: entry)
                    .id(entry.id)
                    .tag(entry)
            }
            .listStyle(.plain)
            .onChange(of: filteredEntries.count) { _, _ in
                if autoScroll, let lastEntry = filteredEntries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var statusBar: some View {
        HStack {
            Text("\(filteredEntries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if filteredEntries.count != logService.entries.count {
                Text("(\(logService.entries.count) total)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Level counts
            HStack(spacing: 8) {
                ForEach([LogLevel.error, .warning, .info], id: \.self) { level in
                    let count = filteredEntries.filter { $0.level == level }.count
                    if count > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(level.color)
                                .frame(width: 6, height: 6)
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }
}

/// Row view for a single log entry
struct LogEntryRowView: View {
    let entry: LogEntry
    
    // Appearance settings
    @AppStorage("logFontSize") private var logFontSize = 12.0
    @AppStorage("logColorCoding") private var logColorCoding = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.formattedTime)
                .font(.system(size: logFontSize, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Level indicator
            Image(systemName: entry.level.iconName)
                .font(.system(size: logFontSize))
                .foregroundStyle(logColorCoding ? entry.level.color : .secondary)
                .frame(width: 16)
            
            // Category
            Text(entry.category)
                .font(.system(size: logFontSize))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Message
            Text(entry.message)
                .font(.system(size: logFontSize, design: .monospaced))
                .foregroundStyle(logColorCoding ? entry.level.textColor : .primary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}

/// Document type for log export
struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    let entries: [LogEntry]
    
    init(entries: [LogEntry]) {
        self.entries = entries
    }
    
    init(configuration: ReadConfiguration) throws {
        entries = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var content = "SilentX Log Export\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Entries: \(entries.count)\n"
        content += String(repeating: "=", count: 60) + "\n\n"
        
        for entry in entries {
            let line = "[\(entry.formattedDateTime)] [\(entry.level.displayName.uppercased())] [\(entry.category)] \(entry.message)"
            content += line + "\n"
        }
        
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

import UniformTypeIdentifiers

#Preview {
    NavigationStack {
        LogView()
    }
}
