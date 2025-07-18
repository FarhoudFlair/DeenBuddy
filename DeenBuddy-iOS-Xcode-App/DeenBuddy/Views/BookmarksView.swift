//
//  BookmarksView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct BookmarksView: View {
    @ObservedObject var viewModel: PrayerGuideViewModel
    @State private var bookmarkedGuideIds: Set<String> = []
    
    private var bookmarkedGuides: [PrayerGuide] {
        viewModel.prayerGuides.filter { bookmarkedGuideIds.contains($0.id) }
            .sorted { $0.prayer.rawValue < $1.prayer.rawValue }
    }

    private var sunniBookmarksCount: String {
        "\(bookmarkedGuides.filter { $0.madhab == .shafi }.count)"
    }

    private var shiaBookmarksCount: String {
        "\(bookmarkedGuides.filter { $0.madhab == .hanafi }.count)"
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Bookmarks")
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    loadBookmarks()
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            if bookmarkedGuides.isEmpty {
                EmptyStateView(state: .noSearchResults)
            } else {
                bookmarksList
            }
        }
    }

    @ViewBuilder
    private var bookmarksList: some View {
        List {
            bookmarksSection
            statisticsSection
        }
    }

    @ViewBuilder
    private var bookmarksSection: some View {
        Section("Bookmarked Guides (\(bookmarkedGuides.count))") {
            ForEach(bookmarkedGuides) { guide in
                bookmarkRow(for: guide)
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(for guide: PrayerGuide) -> some View {
        NavigationLink(destination: PrayerGuideDetailView(guide: guide)) {
            PrayerGuideRowView(guide: guide)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove") {
                removeBookmark(guide.id)
            }
            .tint(.red)
        }
    }

    @ViewBuilder
    private var statisticsSection: some View {
        Section("Statistics") {
            HStack {
                Text("Total Bookmarks")
                    .foregroundColor(.primary)
                Spacer()
                Text("\(bookmarkedGuides.count)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Sunni Bookmarks")
                    .foregroundColor(.primary)
                Spacer()
                Text(sunniBookmarksCount)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Shia Bookmarks")
                    .foregroundColor(.primary)
                Spacer()
                Text(shiaBookmarksCount)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !bookmarkedGuides.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                    clearAllBookmarks()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private func loadBookmarks() {
        // Load bookmarked guide IDs from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "bookmarked_guides"),
           let bookmarks = try? JSONDecoder().decode(Set<String>.self, from: data) {
            bookmarkedGuideIds = bookmarks
        }
    }
    
    private func saveBookmarks() {
        // Save bookmarked guide IDs to UserDefaults
        if let data = try? JSONEncoder().encode(bookmarkedGuideIds) {
            UserDefaults.standard.set(data, forKey: "bookmarked_guides")
        }
    }
    
    private func removeBookmark(_ guideId: String) {
        bookmarkedGuideIds.remove(guideId)
        saveBookmarks()
        
        // Also remove individual bookmark flag
        UserDefaults.standard.removeObject(forKey: "bookmark_\(guideId)")
    }
    
    private func clearAllBookmarks() {
        // Remove all bookmarks
        for guideId in bookmarkedGuideIds {
            UserDefaults.standard.removeObject(forKey: "bookmark_\(guideId)")
        }
        
        bookmarkedGuideIds.removeAll()
        saveBookmarks()
    }
}

// Extension to handle bookmark management
extension BookmarksView {
    func addBookmark(_ guideId: String) {
        bookmarkedGuideIds.insert(guideId)
        saveBookmarks()
        UserDefaults.standard.set(true, forKey: "bookmark_\(guideId)")
    }
    
    func isBookmarked(_ guideId: String) -> Bool {
        return bookmarkedGuideIds.contains(guideId)
    }
}

#Preview {
    BookmarksView(viewModel: PrayerGuideViewModel())
}
