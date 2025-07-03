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
    
    var body: some View {
        NavigationStack {
            Group {
                if bookmarkedGuides.isEmpty {
                    EmptyStateView(
                        title: "No Bookmarks",
                        message: "Bookmark your favorite prayer guides to access them quickly",
                        systemImage: "bookmark"
                    )
                } else {
                    List {
                        Section("Bookmarked Guides (\(bookmarkedGuides.count))") {
                            ForEach(bookmarkedGuides) { guide in
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
                        }
                        
                        // Quick stats
                        Section("Statistics") {
                            StatRowView(
                                title: "Total Bookmarks",
                                value: "\(bookmarkedGuides.count)"
                            )
                            
                            StatRowView(
                                title: "Sunni Bookmarks",
                                value: "\(bookmarkedGuides.filter { $0.madhab == .shafi }.count)"
                            )
                            
                            StatRowView(
                                title: "Shia Bookmarks",
                                value: "\(bookmarkedGuides.filter { $0.madhab == .hanafi }.count)"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                if !bookmarkedGuides.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            clearAllBookmarks()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                loadBookmarks()
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
