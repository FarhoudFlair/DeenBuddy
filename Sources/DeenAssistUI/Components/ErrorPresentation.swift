import SwiftUI
import DeenAssistCore

// MARK: - Error Alert

public struct ErrorAlert: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.title ?? "Error",
                isPresented: $errorHandler.isShowingError,
                presenting: errorHandler.currentError
            ) { error in
                if let actionTitle = error.actionTitle {
                    Button(actionTitle) {
                        handleErrorAction(error)
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    errorHandler.dismissError()
                }
            } message: { error in
                Text(error.message)
            }
    }
    
    private func handleErrorAction(_ error: UserPresentableError) {
        switch error.actionTitle {
        case "Retry":
            // Retry logic would be handled by the calling service
            errorHandler.dismissError()
        case "Open Settings":
            openAppSettings()
        default:
            errorHandler.dismissError()
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        errorHandler.dismissError()
    }
}

// MARK: - Error Banner

public struct ErrorBanner: View {
    let error: UserPresentableError
    let onDismiss: () -> Void
    let onAction: (() -> Void)?
    
    @State private var isVisible = false
    
    public init(
        error: UserPresentableError,
        onDismiss: @escaping () -> Void,
        onAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack(spacing: 12) {
                    // Error icon
                    Image(systemName: severityIcon)
                        .font(.title3)
                        .foregroundColor(severityColor)
                    
                    // Error content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.title)
                            .font(.headline)
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text(error.message)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if let actionTitle = error.actionTitle, let onAction = onAction {
                            Button(actionTitle) {
                                onAction()
                            }
                            .font(.caption)
                            .foregroundColor(ColorPalette.primary)
                        }
                        
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(severityBackgroundColor)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }
            
            // Auto-dismiss after 5 seconds for low severity errors
            if error.severity == .low {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    dismiss()
                }
            }
        }
    }
    
    private var severityIcon: String {
        switch error.severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var severityBackgroundColor: Color {
        switch error.severity {
        case .low:
            return Color.blue.opacity(0.1)
        case .medium:
            return Color.orange.opacity(0.1)
        case .high:
            return Color.red.opacity(0.1)
        case .critical:
            return Color.red.opacity(0.2)
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Error State View

public struct ErrorStateView: View {
    let error: UserPresentableError
    let onRetry: (() -> Void)?
    
    public init(error: UserPresentableError, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Error illustration
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(severityColor)
            
            // Error content
            VStack(spacing: 12) {
                Text(error.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(error.message)
                    .font(.body)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if error.isRetryable, let onRetry = onRetry {
                    CustomButton.primary("Try Again") {
                        onRetry()
                    }
                }
                
                if let actionTitle = error.actionTitle, actionTitle != "Retry" {
                    CustomButton.secondary(actionTitle) {
                        handleAction()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
    
    private func handleAction() {
        switch error.actionTitle {
        case "Open Settings":
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        default:
            break
        }
    }
}

// MARK: - Loading with Error State

public struct LoadingWithErrorView<Content: View>: View {
    let isLoading: Bool
    let error: UserPresentableError?
    let onRetry: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    public init(
        isLoading: Bool,
        error: UserPresentableError?,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.onRetry = onRetry
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            if isLoading {
                LoadingView.prayer(message: "Loading...")
            } else if let error = error {
                ErrorStateView(error: error, onRetry: onRetry)
            } else {
                content()
            }
        }
    }
}

// MARK: - Error Toast

public struct ErrorToast: View {
    let message: String
    let severity: ErrorSeverity
    @Binding var isShowing: Bool
    
    public init(message: String, severity: ErrorSeverity, isShowing: Binding<Bool>) {
        self.message = message
        self.severity = severity
        self._isShowing = isShowing
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if isShowing {
                HStack(spacing: 12) {
                    Image(systemName: severityIcon)
                        .foregroundColor(severityColor)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorPalette.surface)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
    
    private var severityIcon: String {
        switch severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high, .critical:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var severityColor: Color {
        switch severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Add error alert handling to any view
    func errorAlert() -> some View {
        modifier(ErrorAlert())
    }
    
    /// Add error toast to any view
    func errorToast(message: String, severity: ErrorSeverity, isShowing: Binding<Bool>) -> some View {
        overlay(
            ErrorToast(message: message, severity: severity, isShowing: isShowing),
            alignment: .bottom
        )
    }
}
