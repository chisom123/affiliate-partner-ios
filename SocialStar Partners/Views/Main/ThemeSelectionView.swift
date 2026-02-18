import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTheme: String?
    @State private var customTheme: String = ""
    @State private var showCustomInput: Bool = false
    @FocusState private var isCustomFieldFocused: Bool
    
    // Predefined theme suggestions
    private let suggestedThemes = [
        "Outfit of the Day",
        "Food",
        "Mood"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick a Theme")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Give your photo a theme")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Custom Theme
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add New Theme")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if showCustomInput {
                            VStack(spacing: 12) {
                                TextField("Enter theme name", text: $customTheme)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .focused($isCustomFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        if !customTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            selectedTheme = customTheme.trimmingCharacters(in: .whitespacesAndNewlines)
                                            
                                            Analytics.shared.trackTap(
                                                elementId: "custom_theme_saved",
                                                screenName: "theme_selection",
                                                properties: [
                                                    "theme": customTheme.trimmingCharacters(in: .whitespacesAndNewlines),
                                                    "theme_length": customTheme.trimmingCharacters(in: .whitespacesAndNewlines).count
                                                ]
                                            )
                                            
                                            // Auto-dismiss when custom theme is submitted
                                            dismiss()
                                        }
                                    }
                                    .onAppear {
                                        isCustomFieldFocused = true
                                    }
                                
                                Button(action: {
                                    let trimmed = customTheme.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        selectedTheme = trimmed
                                        
                                        Analytics.shared.trackTap(
                                            elementId: "custom_theme_saved",
                                            screenName: "theme_selection",
                                            properties: [
                                                "theme": trimmed,
                                                "theme_length": trimmed.count
                                            ]
                                        )
                                        
                                        // Auto-dismiss when custom theme is saved
                                        dismiss()
                                    }
                                }) {
                                    Text("Save")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(customTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(customTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            Button(action: {
                                showCustomInput = true
                                
                                Analytics.shared.trackTap(
                                    elementId: "create_custom_theme_button",
                                    screenName: "theme_selection",
                                    properties: [:]
                                )
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("New Theme")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Divider
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Suggested Themes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggestions")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(suggestedThemes, id: \.self) { theme in
                            ThemeOptionCard(
                                theme: theme,
                                isSelected: selectedTheme == theme,
                                onSelect: {
                                    selectedTheme = theme
                                    showCustomInput = false
                                    
                                    Analytics.shared.trackTap(
                                        elementId: "suggested_theme_selected",
                                        screenName: "theme_selection",
                                        properties: [
                                            "theme": theme
                                        ]
                                    )
                                    
                                    // Auto-dismiss when theme is selected
                                    dismiss()
                                }
                            )
                        }
                    }
                }
                .padding()
                .tint(.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Analytics.shared.trackTap(
                            elementId: "theme_selection_cancel",
                            screenName: "theme_selection",
                            properties: [:]
                        )
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(
                name: "theme_selection",
                properties: [:]
            )
        }
    }
}

struct ThemeOptionCard: View {
    let theme: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}
