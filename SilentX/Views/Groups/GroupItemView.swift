//
//  GroupItemView.swift
//  SilentX
//
//  Single node row in a proxy group
//

import SwiftUI

struct GroupItemView: View {
    let item: OutboundGroupItem
    let isSelectable: Bool
    let onSelect: () -> Void
    let onTestLatency: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isSelectable {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isSelected ? .blue : .secondary)
                    .font(.system(size: 16))
            } else {
                Image(systemName: item.isSelected ? "smallcircle.filled.circle.fill" : "circle")
                    .foregroundStyle(item.isSelected ? .green : .secondary)
                    .font(.system(size: 14))
            }
            
            // Node icon
            Image(systemName: item.typeIcon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            // Node info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.tag)
                    .font(.system(.body, design: .default))
                    .fontWeight(item.isSelected ? .medium : .regular)
                    .lineLimit(1)
                
                Text(item.type)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Delay indicator
            if item.isTesting {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 50)
            } else if let delay = item.delay {
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.delayColor)
                        .frame(width: 6, height: 6)
                    Text(item.delayText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(item.delayColor)
                }
                .frame(width: 60, alignment: .trailing)
                .onTapGesture {
                    onTestLatency()
                }
            } else if isHovering {
                Button {
                    onTestLatency()
                } label: {
                    Image(systemName: "bolt")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if isSelectable {
                onSelect()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.15), value: item.isSelected)
    }
    
    private var backgroundColor: Color {
        if item.isSelected {
            return Color.accentColor.opacity(0.1)
        }
        if isHovering {
            return Color(nsColor: .controlBackgroundColor)
        }
        return .clear
    }
}

#Preview {
    VStack(spacing: 8) {
        GroupItemView(
            item: OutboundGroupItem(
                id: "1",
                tag: "HK-BGP-01",
                type: "Trojan",
                delay: 78,
                isSelected: true
            ),
            isSelectable: true,
            onSelect: {},
            onTestLatency: {}
        )
        
        GroupItemView(
            item: OutboundGroupItem(
                id: "2",
                tag: "JP-Tokyo-02",
                type: "Shadowsocks",
                delay: 256,
                isSelected: false
            ),
            isSelectable: true,
            onSelect: {},
            onTestLatency: {}
        )
        
        GroupItemView(
            item: OutboundGroupItem(
                id: "3",
                tag: "US-LA-03",
                type: "VMess",
                delay: 678,
                isSelected: false
            ),
            isSelectable: true,
            onSelect: {},
            onTestLatency: {}
        )
        
        GroupItemView(
            item: OutboundGroupItem(
                id: "4",
                tag: "TW-Taipei-04",
                type: "VLESS",
                delay: nil,
                isSelected: false
            ),
            isSelectable: true,
            onSelect: {},
            onTestLatency: {}
        )
        
        GroupItemView(
            item: OutboundGroupItem(
                id: "5",
                tag: "SG-Singapore-05",
                type: "Trojan",
                delay: nil,
                isSelected: false,
                isTesting: true
            ),
            isSelectable: true,
            onSelect: {},
            onTestLatency: {}
        )
    }
    .padding()
    .frame(width: 400)
}
