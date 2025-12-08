//
//  WelcomeView.swift
//  SilentX
//
//  First-launch onboarding view
//

import SwiftUI

/// Welcome view shown on first launch to guide new users
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to SilentX",
            subtitle: "Your friendly macOS proxy companion",
            iconName: "network",
            description: "SilentX makes it easy to manage your proxy connections with a beautiful, intuitive interface powered by the Sing-Box core.",
            features: [
                "Simple one-click connection",
                "Multiple proxy protocols supported",
                "Visual configuration management"
            ]
        ),
        OnboardingPage(
            title: "Import Your Profiles",
            subtitle: "Get started quickly",
            iconName: "doc.badge.arrow.up",
            description: "Import existing configurations from URLs, subscription links, or local files. SilentX supports the full Sing-Box JSON format.",
            features: [
                "URL and file import",
                "Subscription link support",
                "Automatic profile updates"
            ]
        ),
        OnboardingPage(
            title: "Manage Nodes & Rules",
            subtitle: "Full control, no code required",
            iconName: "slider.horizontal.3",
            description: "Add, edit, and organize proxy nodes and routing rules through an easy-to-use graphical interface. No manual JSON editing needed.",
            features: [
                "Visual node management",
                "Drag-and-drop rule ordering",
                "Pre-built rule templates"
            ]
        ),
        OnboardingPage(
            title: "Stay Up to Date",
            subtitle: "Always the latest features",
            iconName: "arrow.triangle.2.circlepath",
            description: "Manage Sing-Box core versions directly within the app. Download, switch between versions, and enable automatic updates.",
            features: [
                "Core version management",
                "One-click updates",
                "Custom URL downloads"
            ]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(for: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            
            Divider()
            
            // Navigation footer
            HStack {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                withAnimation {
                                    currentPage = index
                                }
                            }
                    }
                }
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            
            // Title
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text(page.description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(page.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(feature)
                    }
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
        }
        .padding()
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

/// Model for onboarding page content
struct OnboardingPage {
    let title: String
    let subtitle: String
    let iconName: String
    let description: String
    let features: [String]
}

#Preview {
    WelcomeView()
}
