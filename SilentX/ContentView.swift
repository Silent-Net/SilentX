//
//  ContentView.swift
//  SilentX
//
//  Created by xmx on 6/12/2025.
//

import SwiftUI

/// Root content view - redirects to MainView
/// Kept for compatibility with default Xcode template structure
struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
