//
//  PrayerStepView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct PrayerStepView: View {
    let step: PrayerStep
    let stepNumber: Int
    var onPlayVideo: ((URL) -> Void)?
    var onPlayAudio: ((URL) -> Void)?
    
    init(step: PrayerStep, stepNumber: Int = 1, onPlayVideo: ((URL) -> Void)? = nil, onPlayAudio: ((URL) -> Void)? = nil) {
        self.step = step
        self.stepNumber = stepNumber
        self.onPlayVideo = onPlayVideo
        self.onPlayAudio = onPlayAudio
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step header
            HStack {
                // Step number badge
                Text("\(stepNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.blue))
                
                // Step title
                Text(step.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Duration
                if let duration = step.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            // Step description
            Text(step.description)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Media buttons if available
            if step.videoUrl != nil || step.audioUrl != nil {
                HStack(spacing: 12) {
                    if let videoURLString = step.videoUrl, let videoURL = URL(string: videoURLString) {
                        Button(action: {
                            onPlayVideo?(videoURL)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle")
                                Text("Watch Video")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if let audioURLString = step.audioUrl, let audioURL = URL(string: audioURLString) {
                        Button(action: {
                            onPlayAudio?(audioURL)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                Text("Listen")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    PrayerStepView(
        step: PrayerStep(
            id: "step1",
            title: "Preparation",
            description: "Perform Wudu (ablution) and face the Qibla. Make sure you are in a clean place and wearing clean clothes.",
            stepNumber: 1,
            audioUrl: "https://example.com/audio",
            videoUrl: "https://example.com/video",
            duration: 60
        ),
        stepNumber: 1,
        onPlayVideo: { url in
            print("▶️ Playing video: \(url)")
        },
        onPlayAudio: { url in
            print("🔊 Playing audio: \(url)")
        }
    )
    .padding()
}
