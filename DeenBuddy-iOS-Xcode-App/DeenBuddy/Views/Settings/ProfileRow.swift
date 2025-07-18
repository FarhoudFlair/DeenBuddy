import SwiftUI

/// Profile row component for user name editing in settings
public struct ProfileRow: View {
    let userName: String
    let isEditing: Bool
    @Binding var tempUserName: String
    let onEditTapped: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    public init(
        userName: String,
        isEditing: Bool,
        tempUserName: Binding<String>,
        onEditTapped: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.userName = userName
        self.isEditing = isEditing
        self._tempUserName = tempUserName
        self.onEditTapped = onEditTapped
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(ColorPalette.primary)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                if isEditing {
                    TextField("Enter your name", text: $tempUserName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !tempUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSave()
                            }
                        }
                } else {
                    Text(userName.isEmpty ? "Tap to set your name" : userName)
                        .bodyMedium()
                        .foregroundColor(userName.isEmpty ? ColorPalette.textSecondary : ColorPalette.textPrimary)
                }
            }
            
            Spacer()
            
            if isEditing {
                HStack(spacing: 8) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(ColorPalette.textSecondary)
                    
                    Button("Save") {
                        onSave()
                    }
                    .foregroundColor(ColorPalette.primary)
                    .disabled(tempUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button("Edit") {
                    onEditTapped()
                }
                .foregroundColor(ColorPalette.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ProfileRow(
            userName: "John Doe",
            isEditing: false,
            tempUserName: .constant(""),
            onEditTapped: {},
            onSave: {},
            onCancel: {}
        )
        
        ProfileRow(
            userName: "",
            isEditing: true,
            tempUserName: .constant("Jane Smith"),
            onEditTapped: {},
            onSave: {},
            onCancel: {}
        )
    }
}
