//
//  VideoPlayerView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

struct VideoPlayerView: View {
    let videoURL: URL
    let title: String
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isLoading = true
    @State private var showingControls = true
    @State private var error: Error?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var timeObserverToken: Any?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let error = error {
                    errorView
                } else if isLoading {
                    loadingView
                } else {
                    videoPlayerContent
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        cleanupPlayer()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                cleanupPlayer()
            }
        }
    }
    
    private var videoPlayerContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video player
                ZStack {
                    if let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipped()
                    }
                    
                    // Custom controls overlay
                    if showingControls {
                        VStack {
                            Spacer()
                            
                            videoControls
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingControls.toggle()
                    }
                }
                
                Spacer()
                
                // Video information
                videoInfo
                    .padding()
            }
        }
    }
    
    private var videoControls: some View {
        VStack(spacing: 16) {
            // Progress bar
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                
                Slider(value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        seekToTime(newValue)
                    }
                ), in: 0...max(duration, 1))
                .tint(.cyan)
                
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // Control buttons
            HStack(spacing: 40) {
                Button(action: seekBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                Button(action: seekForward) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "play.circle")
                    .foregroundColor(.cyan)
                
                Text("Duration: \(formatTime(duration))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: shareVideo) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.cyan)
                }
            }
            
            Text("Prayer Guide Video")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.5)
            
            Text("Loading video...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to load video")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let error = error {
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Retry") {
                setupPlayer()
            }
            .buttonStyle(PrimaryModernButtonStyle())
        }
    }
    
    private func setupPlayer() {
        // Clean up any existing player and observers to prevent memory leaks
        cleanupPlayer()
        
        isLoading = true
        error = nil
        
        let player = AVPlayer(url: videoURL)
        self.player = player
        
        // Add observers
        addPlayerObservers()
        
        // Check if video is ready
        player.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak player] in
            DispatchQueue.main.async {
                guard let player = player else { return }

                if let assetDuration = player.currentItem?.asset.duration,
                   assetDuration.isValid && !assetDuration.isIndefinite {
                    self.duration = CMTimeGetSeconds(assetDuration)
                }

                self.isLoading = false
            }
        }
    }
    
    private func addPlayerObservers() {
        guard let player = player else { return }
        
        // Time observer
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
        }
        
        // Playback state observer
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                self.isPlaying = status == .playing
            }
            .store(in: &cancellables)
        
        // Error observer
        player.publisher(for: \.error)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playerError in
                guard let self = self else { return }
                if playerError != nil {
                    self.error = playerError
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanupPlayer() {
        guard let player = player else { return }
        
        // Remove time observer
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        // Cancel all publishers
        cancellables.removeAll()
        
        // Pause player
        player.pause()
        
        // Clear player reference
        self.player = nil
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func seekToTime(_ time: TimeInterval) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
    }
    
    private func seekBackward() {
        let newTime = max(0, currentTime - 15)
        seekToTime(newTime)
    }
    
    private func seekForward() {
        let newTime = min(duration, currentTime + 15)
        seekToTime(newTime)
    }
    
    private func shareVideo() {
        let activityVC = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}

// MARK: - Enhanced Prayer Guide Detail View with Video Support

struct EnhancedPrayerGuideDetailView: View {
    let guide: PrayerGuide
    @State private var showingVideoPlayer = false
    @State private var selectedVideoURL: URL?
    @State private var expandedSteps: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with video thumbnail
                        headerWithVideo
                        
                        // Guide information
                        guideInfoCard
                        
                        // Video section
                        if hasVideo {
                            videoSection
                        }
                        
                        // Steps section
                        stepsSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(guide.title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingVideoPlayer) {
                if let videoURL = selectedVideoURL {
                    VideoPlayerView(videoURL: videoURL, title: guide.title)
                }
            }
        }
    }
    
    private var headerWithVideo: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: guide.prayer.systemImageName)
                        .font(.system(size: 30))
                        .foregroundColor(guide.prayer.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guide.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(guide.prayer.displayName)
                            .font(.subheadline)
                            .foregroundColor(guide.prayer.color)
                    }
                    
                    Spacer()
                }
                
                if hasVideo {
                    Button(action: playVideo) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            
                            Text("Watch Video Guide")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.3))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private var guideInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Guide Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    InfoItem(title: "Prayer", value: guide.prayer.displayName, color: guide.prayer.color)
                    InfoItem(title: "Tradition", value: guide.madhab.sectDisplayName, color: guide.madhab.color)
                    InfoItem(title: "Difficulty", value: guide.difficulty.displayName, color: difficultyColor)
                }
                
                if !guide.description.isEmpty {
                    Text(guide.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
        }
    }
    
    private var videoSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundColor(.cyan)
                    
                    Text("Video Guide")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Play") {
                        playVideo()
                    }
                    .buttonStyle(CompactModernButtonStyle())
                }
                
                Text("Watch step-by-step video instructions for this prayer")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
    
    private var stepsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prayer Steps")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                ForEach(Array((guide.textContent?.steps ?? []).enumerated()), id: \.element.id) { index, step in
                    PrayerStepCard(
                        step: step,
                        stepNumber: index + 1,
                        isExpanded: expandedSteps.contains(step.id)
                    ) {
                        if expandedSteps.contains(step.id) {
                            expandedSteps.remove(step.id)
                        } else {
                            expandedSteps.insert(step.id)
                        }
                    }
                    
                    if index < (guide.textContent?.steps.count ?? 0) - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding()
        }
    }
    
    private var actionsSection: some View {
        ModernCard {
            VStack(spacing: 12) {
                if hasVideo {
                    Button(action: playVideo) {
                        Label("Watch Video", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryModernButtonStyle())
                }
                
                HStack(spacing: 12) {
                    Button("Share Guide") {
                        shareGuide()
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                    
                    Button("Add to Bookmarks") {
                        // TODO: Implement bookmark functionality
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var hasVideo: Bool {
        // Check if any step has a video URL
        return (guide.textContent?.steps ?? []).contains { $0.videoUrl != nil }
    }
    
    private var difficultyColor: Color {
        switch guide.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    private func playVideo() {
        // Find the first step with a video URL
        if let step = (guide.textContent?.steps ?? []).first(where: { $0.videoUrl != nil }),
           let videoURLString = step.videoUrl,
           let videoURL = URL(string: videoURLString) {
            selectedVideoURL = videoURL
            showingVideoPlayer = true
        }
    }
    
    private func shareGuide() {
        let shareText = """
        \(guide.title)
        
        \(guide.description)
        
        Prayer: \(guide.prayer.displayName)
        Tradition: \(guide.madhab.sectDisplayName)
        Steps: \(guide.textContent?.steps.count ?? 0)
        
        Shared from DeenBuddy - Islamic Prayer Companion
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct InfoItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrayerStepCard: View {
    let step: PrayerStep
    let stepNumber: Int
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack {
                    // Step number
                    Text("\(stepNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                        .background(Color.cyan)
                        .cornerRadius(15)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        if let duration = step.duration {
                            Text("Duration: \(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    if step.videoUrl != nil {
                        Image(systemName: "play.circle")
                            .foregroundColor(.cyan)
                            .font(.title3)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                    
                    if let videoURLString = step.videoUrl,
                       let videoURL = URL(string: videoURLString) {
                        Button(action: { playStepVideo(videoURL) }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Watch Step Video")
                            }
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(.leading, 42)
            }
        }
    }
    
    private func playStepVideo(_ url: URL) {
        // This would trigger the video player
        print("Playing step video: \(url)")
    }
}

#Preview {
    VideoPlayerView(
        videoURL: URL(string: "https://example.com/prayer-video.mp4")!,
        title: "Fajr Prayer Guide"
    )
}