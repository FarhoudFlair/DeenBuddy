import SwiftUI

/// Reusable input field component with validation and styling
public struct InputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let style: InputStyle
    let validation: InputValidation?
    let onCommit: (() -> Void)?
    
    @State private var isEditing = false
    @State private var validationError: String?
    @FocusState private var isFocused: Bool
    
    public init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        style: InputStyle = .default,
        validation: InputValidation? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.validation = validation
        self.onCommit = onCommit
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            if !title.isEmpty {
                Text(title)
                    .labelLarge()
                    .foregroundColor(ColorPalette.textPrimary)
            }
            
            // Input field
            Group {
                switch style {
                case .default:
                    defaultTextField
                case .search:
                    searchTextField
                case .secure:
                    secureTextField
                case .multiline:
                    multilineTextField
                }
            }
            .focused($isFocused)
            .onSubmit {
                validateInput()
                onCommit?()
            }
            .onChange(of: text) { _ in
                if isEditing {
                    validateInput()
                }
            }
            .onChange(of: isFocused) { focused in
                isEditing = focused
                if !focused {
                    validateInput()
                }
            }
            
            // Validation error
            if let error = validationError {
                Text(error)
                    .bodySmall()
                    .foregroundColor(ColorPalette.error)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationError)
    }
    
    @ViewBuilder
    private var defaultTextField: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(CustomTextFieldStyle(
                isValid: validationError == nil,
                isFocused: isFocused
            ))
    }
    
    @ViewBuilder
    private var searchTextField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorPalette.textTertiary)
            
            TextField(placeholder, text: $text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorPalette.surfaceSecondary)
        )
    }
    
    @ViewBuilder
    private var secureTextField: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(CustomTextFieldStyle(
                isValid: validationError == nil,
                isFocused: isFocused
            ))
    }
    
    @ViewBuilder
    private var multilineTextField: some View {
        TextEditor(text: $text)
            .frame(minHeight: 80)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        validationError != nil ? ColorPalette.error :
                        isFocused ? ColorPalette.primary : ColorPalette.textTertiary.opacity(0.3),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
    }
    
    private func validateInput() {
        guard let validation = validation else {
            validationError = nil
            return
        }
        
        validationError = validation.validate(text)
    }
}

// MARK: - Input Styles

public enum InputStyle {
    case `default`
    case search
    case secure
    case multiline
}

// MARK: - Custom Text Field Style

private struct CustomTextFieldStyle: TextFieldStyle {
    let isValid: Bool
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorPalette.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        !isValid ? ColorPalette.error :
                        isFocused ? ColorPalette.primary : ColorPalette.textTertiary.opacity(0.3),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
    }
}

// MARK: - Input Validation

public struct InputValidation {
    let rules: [ValidationRule]
    
    public init(rules: [ValidationRule]) {
        self.rules = rules
    }
    
    public func validate(_ text: String) -> String? {
        for rule in rules {
            if let error = rule.validate(text) {
                return error
            }
        }
        return nil
    }
}

public enum ValidationRule {
    case required
    case minLength(Int)
    case maxLength(Int)
    case email
    case custom((String) -> String?)
    
    func validate(_ text: String) -> String? {
        switch self {
        case .required:
            return text.isEmpty ? "This field is required" : nil
            
        case .minLength(let min):
            return text.count < min ? "Must be at least \(min) characters" : nil
            
        case .maxLength(let max):
            return text.count > max ? "Must be no more than \(max) characters" : nil
            
        case .email:
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: text) ? nil : "Please enter a valid email"
            
        case .custom(let validator):
            return validator(text)
        }
    }
}

// MARK: - Convenience Initializers

public extension InputField {
    static func text(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validation: InputValidation? = nil,
        onCommit: (() -> Void)? = nil
    ) -> InputField {
        InputField(
            title: title,
            placeholder: placeholder,
            text: text,
            style: .default,
            validation: validation,
            onCommit: onCommit
        )
    }
    
    static func search(
        placeholder: String,
        text: Binding<String>,
        onCommit: (() -> Void)? = nil
    ) -> InputField {
        InputField(
            title: "",
            placeholder: placeholder,
            text: text,
            style: .search,
            validation: nil,
            onCommit: onCommit
        )
    }
    
    static func secure(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validation: InputValidation? = nil,
        onCommit: (() -> Void)? = nil
    ) -> InputField {
        InputField(
            title: title,
            placeholder: placeholder,
            text: text,
            style: .secure,
            validation: validation,
            onCommit: onCommit
        )
    }
}

// MARK: - Form Container

public struct FormContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview("Input Fields") {
    FormContainer {
        InputField.text(
            title: "City Name",
            placeholder: "Enter your city",
            text: .constant(""),
            validation: InputValidation(rules: [.required, .minLength(2)])
        )
        
        InputField.search(
            placeholder: "Search cities...",
            text: .constant("")
        )
        
        InputField.secure(
            title: "Password",
            placeholder: "Enter password",
            text: .constant(""),
            validation: InputValidation(rules: [.required, .minLength(6)])
        )
    }
    .background(ColorPalette.backgroundPrimary)
}
