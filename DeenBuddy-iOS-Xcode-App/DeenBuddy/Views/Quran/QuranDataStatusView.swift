import SwiftUI

/// View to display Quran data validation status and loading progress
struct QuranDataStatusView: View {
    @ObservedObject var searchService: QuranSearchService
    @State private var showValidationDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Loading Progress
            if searchService.isLoading {
                loadingSection
            }
            
            // Data Status Summary
            dataStatusSection
            
            // Validation Details (if available)
            if let validation = searchService.dataValidationResult {
                validationSection(validation)
            }
            
            // Action Buttons
            actionButtonsSection
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.blue)
                Text("Loading Quran data...")
                    .font(.headline)
                Spacer()
            }

            ProgressView(value: searchService.loadingProgress)
                .progressViewStyle(LinearProgressViewStyle())

            Text("\(Int(searchService.loadingProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Data Status Section
    
    private var dataStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: searchService.isCompleteDataLoaded() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(searchService.isCompleteDataLoaded() ? .green : .orange)
                
                Text("Quran Database Status")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verses Loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(searchService.getTotalVersesCount()) / \(QuranDataValidator.EXPECTED_TOTAL_VERSES)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(searchService.getTotalVersesCount() == QuranDataValidator.EXPECTED_TOTAL_VERSES ? .green : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Surahs Loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(searchService.getTotalSurahsCount()) / \(QuranDataValidator.EXPECTED_TOTAL_SURAHS)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(searchService.getTotalSurahsCount() == QuranDataValidator.EXPECTED_TOTAL_SURAHS ? .green : .orange)
                }
            }
        }
    }
    
    // MARK: - Validation Section
    
    private func validationSection(_ validation: QuranDataValidator.ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showValidationDetails.toggle()
            }) {
                HStack {
                    Image(systemName: validation.isValid ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(validation.isValid ? .green : .red)
                    
                    Text("Data Validation")
                        .font(.headline)
                    
                    Text(validation.isValid ? "PASSED" : "FAILED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(validation.isValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(validation.isValid ? .green : .red)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Image(systemName: showValidationDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showValidationDetails {
                ScrollView {
                    Text(validation.summary)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
            
            // Quick Stats
            if validation.hasErrors {
                VStack(alignment: .leading, spacing: 4) {
                    if !validation.missingVerses.isEmpty {
                        Label("\(validation.missingVerses.count) verse count issues", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if !validation.missingSurahs.isEmpty {
                        Label("\(validation.missingSurahs.count) missing surahs", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if !validation.invalidVerses.isEmpty {
                        Label("\(validation.invalidVerses.count) invalid verses", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                searchService.refreshQuranData()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Data")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .disabled(searchService.isLoading)
            
            if !searchService.isCompleteDataLoaded() {
                Button(action: {
                    searchService.forceReloadData()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Force Reload")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
                .disabled(searchService.isLoading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct QuranDataStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Loading state
            QuranDataStatusView(searchService: {
                let service = QuranSearchService()
                // Simulate loading state
                return service
            }())
            
            Spacer()
        }
        .padding()
        .previewDisplayName("Quran Data Status")
    }
}
