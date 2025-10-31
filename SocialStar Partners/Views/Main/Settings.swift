import SwiftUI
import Firebase
import FirebaseAuth
import MessageUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Account Information Section
                    CustomSection(title: "Account Information") {
                        VStack(spacing: 16) {
                            CustomInfoRow(
                                title: "Email",
                                value: viewModel.email
                            )
                            
                            CustomCaptionText("Your login email cannot be changed")
                                .padding(.bottom)
                        }
                    }
                    
                    // Personal Information Section
                    CustomSection(title: "Personal Information") {
                        VStack(spacing: 16) {
                            CustomTextField(
                                title: "First Name",
                                text: $viewModel.firstName
                            )
                            
                            CustomTextField(
                                title: "Last Name",
                                text: $viewModel.lastName
                            )
                            
                            CustomButton(
                                title: "Update Name",
                                isDisabled: viewModel.isLoading || !viewModel.hasNameChanged || !viewModel.areNamesValid,
                                isLoading: viewModel.isLoading,
                                style: .primary
                            ) {
                                // Analytics: Track name update attempt
                                Analytics.shared.trackTap(
                                    elementId: "update_name_button",
                                    screenName: "settings",
                                    properties: [
                                        "first_name_length": viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).count,
                                        "last_name_length": viewModel.lastName.trimmingCharacters(in: .whitespacesAndNewlines).count,
                                        "names_valid": viewModel.areNamesValid
                                    ]
                                )
                                
                                viewModel.updateName()
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Error/Success Messages
                    if !viewModel.errorMessage.isEmpty {
                        CustomMessageCard(
                            message: viewModel.errorMessage,
                            type: .error
                        )
                        .onAppear {
                            // Analytics: Track error message display
                            Analytics.shared.track(
                                event: "error_message_displayed",
                                properties: [
                                    AnalyticsProperty.screenName: "settings",
                                    AnalyticsProperty.errorMessage: viewModel.errorMessage
                                ]
                            )
                        }
                    }
                    
                    if !viewModel.successMessage.isEmpty {
                        CustomMessageCard(
                            message: viewModel.successMessage,
                            type: .success
                        )
                        .onAppear {
                            // Analytics: Track success message display
                            Analytics.shared.track(
                                event: "success_message_displayed",
                                properties: [
                                    AnalyticsProperty.screenName: "settings",
                                    "message": viewModel.successMessage
                                ]
                            )
                        }
                    }
                    
                    // Support Section
                    CustomSection(title: "Support") {
                        CustomActionRow(
                            title: "Email Us"
                        ) {
                            // Analytics: Track support email tap
                            Analytics.shared.trackTap(
                                elementId: "email_support_button",
                                screenName: "settings"
                            )
                            
                            viewModel.openEmailApp()
                        }
                    }
                    
                    // Account Actions Section
                    CustomSection(title: "Account") {
                        VStack(spacing: 0) {
                            CustomActionRow(
                                title: "Log Out"
                            ) {
                                // Analytics: Track logout initiation
                                Analytics.shared.trackTap(
                                    elementId: "logout_button",
                                    screenName: "settings"
                                )
                                
                                viewModel.showSignOutConfirmation = true
                            }
                            
                            // Divider between Log Out and Delete Account
                            Divider()
                            
                            CustomActionRow(
                                title: "Delete Account"
                            ) {
                                // Analytics: Track delete account initiation
                                Analytics.shared.trackTap(
                                    elementId: "delete_account_button",
                                    screenName: "settings"
                                )
                                
                                viewModel.showDeleteAccountConfirmation = true
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.white))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Analytics: Track settings screen view
                Analytics.shared.trackScreen(
                    name: "settings",
                    properties: [
                        "user_email": viewModel.email.isEmpty ? "not_loaded" : "loaded",
                        "has_user_data": !viewModel.firstName.isEmpty || !viewModel.lastName.isEmpty
                    ]
                )
                
                viewModel.loadUserData()
            }
            // Log Out Confirmation Alert
            .alert("Log Out", isPresented: $viewModel.showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Analytics: Track logout cancellation
                    Analytics.shared.track(
                        event: "logout_cancelled",
                        properties: [
                            AnalyticsProperty.screenName: "settings"
                        ]
                    )
                }
                Button("Log Out", role: .destructive) {
                    // Analytics: Track logout confirmation
                    Analytics.shared.track(
                        event: "logout_confirmed",
                        properties: [
                            AnalyticsProperty.screenName: "settings"
                        ]
                    )
                    
                    viewModel.signOut()
                    Analytics.shared.reset()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            // Delete Account Confirmation Alert
            .alert("Delete Account", isPresented: $viewModel.showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Analytics: Track delete account cancellation
                    Analytics.shared.track(
                        event: "delete_account_cancelled",
                        properties: [
                            AnalyticsProperty.screenName: "settings"
                        ]
                    )
                }
                Button("Delete", role: .destructive) {
                    // Analytics: Track delete account confirmation
                    Analytics.shared.track(
                        event: "delete_account_confirmed",
                        properties: [
                            AnalyticsProperty.screenName: "settings"
                        ]
                    )
                    
                    viewModel.deleteAccount()
                    Analytics.shared.reset()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Custom Components

struct CustomSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

struct CustomInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.body))
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.system(.body))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.subheadline))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            TextField("", text: $text)
                .font(.system(.body))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

struct CustomButton: View {
    let title: String
    let isDisabled: Bool
    let isLoading: Bool
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(.body))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isDisabled ? Color(.systemGray4) :
                (style == .primary ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(
                isDisabled ? Color(.systemGray2) :
                (style == .primary ? .white : .primary)
            )
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
        .disabled(isDisabled)
        .padding(.vertical, 8)
    }
}

struct CustomActionRow: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(.body))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomCaptionText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(.caption))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
    }
}

struct CustomMessageCard: View {
    let message: String
    let type: MessageType
    
    enum MessageType {
        case success, error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .success: return .green.opacity(0.1)
            case .error: return .red.opacity(0.1)
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .frame(width: 20, height: 20)
            
            Text(message)
                .font(.system(.body))
                .foregroundColor(type.color)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - ViewModel

class SettingsViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    @Published var showSignOutConfirmation = false
    @Published var showDeleteAccountConfirmation = false
    
    private var originalFirstName = ""
    private var originalLastName = ""
    
    var hasNameChanged: Bool {
        firstName != originalFirstName || lastName != originalLastName
    }
    
    var areNamesValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func loadUserData() {
        guard let user = Auth.auth().currentUser else { return }
        
        email = user.email ?? "Unknown"
        
        let db = Firestore.firestore()
        db.collection("affiliates").document(user.uid).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let document = document,
                   document.exists,
                   let data = document.data() {
                    
                    self?.firstName = data["firstName"] as? String ?? ""
                    self?.lastName = data["lastName"] as? String ?? ""
                    self?.originalFirstName = self?.firstName ?? ""
                    self?.originalLastName = self?.lastName ?? ""
                    
                    // Analytics: Track user data load success
                    Analytics.shared.track(
                        event: "user_data_loaded",
                        properties: [
                            AnalyticsProperty.screenName: "settings",
                            "has_first_name": !(self?.firstName.isEmpty ?? true),
                            "has_last_name": !(self?.lastName.isEmpty ?? true),
                            "email_domain": self?.email.components(separatedBy: "@").last ?? "unknown"
                        ]
                    )
                } else if let error = error {
                    // Analytics: Track user data load error
                    Analytics.shared.trackError(
                        message: "Failed to load user data: \(error.localizedDescription)",
                        properties: [
                            AnalyticsProperty.screenName: "settings"
                        ]
                    )
                }
            }
        }
    }
    
    func updateName() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Additional validation before proceeding
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedFirstName.isEmpty || trimmedLastName.isEmpty {
            errorMessage = "First name and last name cannot be empty"
            
            // Analytics: Track validation error
            Analytics.shared.track(
                event: "name_update_validation_failed",
                properties: [
                    AnalyticsProperty.screenName: "settings",
                    "first_name_empty": trimmedFirstName.isEmpty,
                    "last_name_empty": trimmedLastName.isEmpty
                ]
            )
            return
        }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        let db = Firestore.firestore()
        db.collection("affiliates").document(user.uid).updateData([
            "firstName": trimmedFirstName,
            "lastName": trimmedLastName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error updating name - \(error.localizedDescription)"
                    
                    // Analytics: Track name update failure
                    Analytics.shared.track(
                        event: "name_update_failed",
                        properties: [
                            AnalyticsProperty.screenName: "settings",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                } else {
                    self?.successMessage = "Name updated successfully"
                    self?.firstName = trimmedFirstName
                    self?.lastName = trimmedLastName
                    self?.originalFirstName = trimmedFirstName
                    self?.originalLastName = trimmedLastName
                    
                    // Analytics: Track successful name update
                    Analytics.shared.track(
                        event: "name_updated_successfully",
                        properties: [
                            AnalyticsProperty.screenName: "settings",
                            "first_name_length": trimmedFirstName.count,
                            "last_name_length": trimmedLastName.count
                        ]
                    )
                    
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.successMessage = ""
                    }
                }
            }
        }
    }
    
    func openEmailApp() {
        if let emailURL = URL(string: "mailto:info@socialstarapp.com") {
            if UIApplication.shared.canOpenURL(emailURL) {
                UIApplication.shared.open(emailURL)
                
                // Analytics: Track successful email app open
                Analytics.shared.track(
                    event: "support_email_opened",
                    properties: [
                        AnalyticsProperty.screenName: "settings",
                        "email_address": "info@socialstarapp.com"
                    ]
                )
            } else {
                errorMessage = "Unable to open email app"
                
                // Analytics: Track email app open failure
                Analytics.shared.track(
                    event: "support_email_failed",
                    properties: [
                        AnalyticsProperty.screenName: "settings",
                        AnalyticsProperty.errorMessage: "Unable to open email app"
                    ]
                )
            }
        }
    }
    
    func deleteAccount() {
        // Analytics: Track delete account action (currently just logout)
        Analytics.shared.track(
            event: "delete_account_executed",
            properties: [
                AnalyticsProperty.screenName: "settings",
                "actual_action": "logout" // Since delete just calls signOut
            ]
        )
        
        // For now, just perform the logout action as requested
        signOut()
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            
            // Analytics: Track successful sign out
            Analytics.shared.track(
                event: "user_signed_out",
                properties: [
                    AnalyticsProperty.screenName: "settings",
                    "sign_out_method": "manual"
                ]
            )
            
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
            
            // Analytics: Track sign out error
            Analytics.shared.trackError(
                message: "Sign out failed: \(error.localizedDescription)",
                properties: [
                    AnalyticsProperty.screenName: "settings"
                ]
            )
        }
    }
}
