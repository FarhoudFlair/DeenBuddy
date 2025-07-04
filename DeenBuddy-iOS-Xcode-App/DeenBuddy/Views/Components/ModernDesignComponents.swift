//
//  ModernDesignComponents.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

// MARK: - Modern Card Style

struct ModernCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let borderColor: Color
    
    init(
        backgroundColor: Color = Color.black.opacity(0.3),
        borderColor: Color = Color.white.opacity(0.1),
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Modern Button Styles

struct PrimaryModernButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(backgroundColor: Color = .cyan, foregroundColor: Color = .black) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Typography

struct ModernTitle: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .white) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(color)
    }
}

struct ModernSubtitle: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .white.opacity(0.8)) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(color)
    }
}

struct ModernCaption: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .white.opacity(0.6)) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
    }
}

// MARK: - Modern Loading View

struct ModernLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.cyan)
            
            ModernTitle(message)
        }
        .padding()
    }
}

// MARK: - Modern Error View

struct ModernErrorView: View {
    let title: String
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                ModernTitle(title)
                ModernSubtitle(message)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(PrimaryModernButtonStyle())
        }
        .padding()
    }
}

// MARK: - Modern Empty State

struct ModernEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                ModernTitle(title)
                ModernSubtitle(message)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(PrimaryModernButtonStyle())
            }
        }
        .padding()
    }
}

// MARK: - Modern Gradient Background

struct ModernGradientBackground: View {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    init(
        colors: [Color] = [
            Color(red: 0.1, green: 0.15, blue: 0.25),
            Color(red: 0.05, green: 0.1, blue: 0.2)
        ],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
        .ignoresSafeArea()
    }
}

// MARK: - Modern Status Indicator

struct ModernStatusIndicator: View {
    let status: String
    let color: Color
    let isActive: Bool
    
    init(status: String, color: Color, isActive: Bool = false) {
        self.status = status
        self.color = color
        self.isActive = isActive
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Preview

#Preview("Modern Components") {
    ZStack {
        ModernGradientBackground()
        
        VStack(spacing: 20) {
            ModernCard {
                VStack(spacing: 12) {
                    ModernTitle("Sample Card")
                    ModernSubtitle("This is a sample card with modern styling")
                    
                    HStack {
                        Button("Primary") {}
                            .buttonStyle(PrimaryModernButtonStyle())
                        
                        Button("Secondary") {}
                            .buttonStyle(SecondaryModernButtonStyle())
                    }
                }
                .padding()
            }
            
            ModernStatusIndicator(status: "Active", color: .green, isActive: true)
            
            ModernEmptyState(
                title: "No Data",
                message: "There's nothing to show here",
                systemImage: "tray",
                actionTitle: "Refresh",
                action: {}
            )
        }
        .padding()
    }
}
