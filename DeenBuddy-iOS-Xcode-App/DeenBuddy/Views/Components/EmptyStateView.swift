//
//  EmptyStateView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    EmptyStateView(
        title: "No Prayer Guides",
        message: "No guides found for the selected tradition",
        systemImage: "book.closed"
    )
}
