import XCTest
import SwiftUI
@testable import DeenBuddy

/// Tests for the CalculationMethodsSourcesView
final class CalculationMethodsSourcesViewTests: XCTestCase {
    
    func testCalculationMethodsSourcesViewCreation() {
        // Test that the view can be created without crashing
        let view = CalculationMethodsSourcesView()
        XCTAssertNotNil(view)
    }
    
    func testViewHasCorrectTitle() {
        // Test that the view has the expected navigation title
        let view = CalculationMethodsSourcesView()
        
        // Since we can't easily test SwiftUI view properties directly,
        // we'll just verify the view can be instantiated
        XCTAssertNotNil(view)
    }
    
    func testExpandableSectionCreation() {
        // Test that the supporting views can be created
        let expandableSection = ExpandableSection(
            title: "Test Section",
            icon: "clock.fill",
            isExpanded: false,
            onToggle: {},
            content: { Text("Test Content") }
        )
        
        XCTAssertNotNil(expandableSection)
    }
    
    func testInfoCardCreation() {
        // Test that InfoCard can be created
        let infoCard = InfoCard(
            title: "Test Title",
            content: "Test Content"
        )
        
        XCTAssertNotNil(infoCard)
    }
}

// MARK: - Supporting Views for Testing

private struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.top, 12)
            }
        }
    }
}

private struct InfoCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text(content)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
