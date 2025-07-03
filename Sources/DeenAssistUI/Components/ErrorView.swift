import SwiftUI

/// Comprehensive error view component for different error states
public struct ErrorView: View {
    let error: ErrorType
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    public init(
        error: ErrorType,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: error.iconName)
                .font(.system(size: 64))
                .foregroundColor(error.iconColor)
            
            // Error content
            VStack(spacing: 12) {
                Text(error.title)
                    .headlineSmall()
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(error.message)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                
                if let suggestion = error.suggestion {
                    Text(suggestion)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    CustomButton.primary(error.retryButtonTitle) {
                        onRetry()
                    }
                }
                
                if let onDismiss = onDismiss {
                    CustomButton.tertiary("Dismiss") {
                        onDismiss()
                    }
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(error.accessibilityLabel)
        .accessibilityHint(error.accessibilityHint)
    }
}

// MARK: - Error Types

public enum ErrorType {
    case networkError
    case locationError
    case permissionDenied
    case dataCorruption
    case calculationError
    case notificationError
    case unknownError(String)
    
    var iconName: String {
        switch self {
        case .networkError:
            return "wifi.exclamationmark"
        case .locationError:
            return "location.slash"
        case .permissionDenied:
            return "hand.raised.fill"
        case .dataCorruption:
            return "exclamationmark.triangle.fill"
        case .calculationError:
            return "clock.badge.exclamationmark"
        case .notificationError:
            return "bell.slash.fill"
        case .unknownError:
            return "questionmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .networkError, .locationError:
            return ColorPalette.warning
        case .permissionDenied, .dataCorruption, .calculationError, .notificationError:
            return ColorPalette.error
        case .unknownError:
            return ColorPalette.textTertiary
        }
    }
    
    var title: String {
        switch self {
        case .networkError:
            return "Connection Error"
        case .locationError:
            return "Location Unavailable"
        case .permissionDenied:
            return "Permission Required"
        case .dataCorruption:
            return "Data Error"
        case .calculationError:
            return "Calculation Error"
        case .notificationError:
            return "Notification Error"
        case .unknownError:
            return "Something Went Wrong"
        }
    }
    
    var message: String {
        switch self {
        case .networkError:
            return "Unable to connect to the internet. Please check your connection and try again."
        case .locationError:
            return "We couldn't determine your location. Prayer times may not be accurate."
        case .permissionDenied:
            return "This feature requires permission to work properly."
        case .dataCorruption:
            return "There was an issue with your data. You may need to reset your settings."
        case .calculationError:
            return "Unable to calculate prayer times. Please check your location and settings."
        case .notificationError:
            return "Unable to schedule prayer notifications. Please check your notification settings."
        case .unknownError(let message):
            return message
        }
    }
    
    var suggestion: String? {
        switch self {
        case .networkError:
            return "Try connecting to Wi-Fi or check your cellular data."
        case .locationError:
            return "You can manually enter your city in settings."
        case .permissionDenied:
            return "Go to Settings > Privacy to grant permission."
        case .dataCorruption:
            return "Contact support if this problem persists."
        case .calculationError:
            return "Try refreshing or changing your calculation method."
        case .notificationError:
            return "Check Settings > Notifications > Deen Assist."
        case .unknownError:
            return "Please try again or contact support."
        }
    }
    
    var retryButtonTitle: String {
        switch self {
        case .networkError:
            return "Try Again"
        case .locationError:
            return "Retry Location"
        case .permissionDenied:
            return "Open Settings"
        case .dataCorruption:
            return "Reset Data"
        case .calculationError:
            return "Recalculate"
        case .notificationError:
            return "Check Settings"
        case .unknownError:
            return "Retry"
        }
    }
    
    var accessibilityLabel: String {
        return "\(title). \(message)"
    }
    
    var accessibilityHint: String {
        return suggestion ?? "Double tap to retry or dismiss this error."
    }
}

// MARK: - Specialized Error Views

public struct NetworkErrorView: View {
    let onRetry: () -> Void
    
    public init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
    }
    
    public var body: some View {
        ErrorView(error: .networkError, onRetry: onRetry)
    }
}

public struct LocationErrorView: View {
    let onRetry: () -> Void
    let onManualEntry: () -> Void
    
    public init(onRetry: @escaping () -> Void, onManualEntry: @escaping () -> Void) {
        self.onRetry = onRetry
        self.onManualEntry = onManualEntry
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ErrorView(error: .locationError, onRetry: onRetry)
            
            CustomButton.secondary("Enter City Manually") {
                onManualEntry()
            }
        }
    }
}

// MARK: - Error Alert Modifier

public struct ErrorAlert: ViewModifier {
    @Binding var error: ErrorType?
    let onRetry: (() -> Void)?
    
    public func body(content: Content) -> some View {
        content
            .alert(
                error?.title ?? "Error",
                isPresented: .constant(error != nil),
                presenting: error
            ) { errorType in
                if let onRetry = onRetry {
                    Button(errorType.retryButtonTitle) {
                        onRetry()
                        error = nil
                    }
                }
                
                Button("OK") {
                    error = nil
                }
            } message: { errorType in
                Text(errorType.message)
            }
    }
}

public extension View {
    func errorAlert(
        error: Binding<ErrorType?>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlert(error: error, onRetry: onRetry))
    }
}

// MARK: - Preview

#Preview("Error Views") {
    VStack(spacing: 20) {
        ErrorView(error: .networkError, onRetry: {})
        ErrorView(error: .locationError, onRetry: {})
        ErrorView(error: .permissionDenied, onRetry: {})
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
