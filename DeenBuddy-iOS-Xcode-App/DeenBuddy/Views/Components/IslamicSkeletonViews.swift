import SwiftUI

// MARK: - Islamic Skeleton Views for Sub-400ms Performance

/// Islamic-themed skeleton screens that match prayer content layout
/// Shows within 100ms to provide immediate visual feedback

// MARK: - Prayer Time Skeleton Card

struct PrayerTimeSkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Prayer name skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmerGradient)
                    .frame(width: 80, height: 18)
                
                Spacer()
                
                // Time skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmerGradient)
                    .frame(width: 70, height: 22)
            }
            
            // Status indicator skeleton
            HStack {
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 8, height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 60, height: 12)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.islamicGreen.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.islamicGreen.opacity(0.3),
                Color.islamicGreen.opacity(0.1),
                Color.islamicGreen.opacity(0.3)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

// MARK: - Prayer Times List Skeleton

struct PrayerTimesListSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.islamicGreen.opacity(0.2))
                    .frame(width: 200, height: 24)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.islamicGreen.opacity(0.15))
                    .frame(width: 150, height: 16)
            }
            .padding(.top)
            
            // Prayer cards skeleton
            ForEach(0..<5, id: \.self) { _ in
                PrayerTimeSkeletonCard()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Qibla Compass Skeleton

struct QiblaCompassSkeleton: View {
    @State private var isRotating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Location info skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 120, height: 18)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 14)
            }
            
            // Compass skeleton
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 280, height: 280)
                
                // Inner compass background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                
                // Compass markings skeleton
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                
                // Center dot
                Circle()
                    .fill(Color.islamicGreen.opacity(0.6))
                    .frame(width: 8, height: 8)
                
                // Animated loading indicator
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.islamicGreen, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            }
            
            // Bottom info skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 100, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 12)
            }
        }
        .onAppear {
            isRotating = true
        }
    }
}

// MARK: - Islamic Content Skeleton

struct IslamicContentSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.islamicGreen.opacity(0.3))
                .frame(width: 180, height: 24)
            
            // Content blocks
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.islamicGreen.opacity(0.2))
                                .frame(height: 16)
                            
                            Spacer()
                        }
                        
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.islamicGreen.opacity(0.15))
                                .frame(width: 200, height: 14)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Islamic Loading Animation

struct IslamicLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Geometric pattern inspired by Islamic art
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.islamicGreen)
                    .frame(width: 4, height: 20)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .opacity(isAnimating ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Color Extensions

extension Color {
    static let islamicGreen = Color.islamicPrimaryGreen // Use the main color from Colors.swift
}

// MARK: - Preview

#Preview("Islamic Skeleton Views") {
    ScrollView {
        VStack(spacing: 30) {
            Group {
                Text("Prayer Time Skeleton")
                    .font(.headline)
                PrayerTimeSkeletonCard()
                
                Text("Prayer Times List Skeleton")
                    .font(.headline)
                PrayerTimesListSkeleton()
            }
            
            Group {
                Text("Qibla Compass Skeleton")
                    .font(.headline)
                ZStack {
                    Color.black
                    QiblaCompassSkeleton()
                }
                .frame(height: 400)
                .cornerRadius(16)
            }
            
            Group {
                Text("Islamic Content Skeleton")
                    .font(.headline)
                IslamicContentSkeleton()
                
                Text("Islamic Loading Indicator")
                    .font(.headline)
                IslamicLoadingIndicator()
            }
        }
        .padding()
    }
}
