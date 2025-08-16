import SwiftUI
import Firebase
import FirebaseAuth
import MessageUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Account Information Section
                Section("Account Information") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(viewModel.email)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Your login email cannot be changed")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Name Section
                Section("Personal Information") {
                    TextField("First Name", text: $viewModel.firstName)
                    
                    TextField("Last Name", text: $viewModel.lastName)
                    
                    Button("Update Name") {
                        viewModel.updateName()
                    }
                    .disabled(viewModel.isLoading || !viewModel.hasNameChanged)
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if !viewModel.successMessage.isEmpty {
                    Section {
                        Text(viewModel.successMessage)
                            .foregroundColor(.green)
                    }
                }
                
                // Support Section
                Section("Support") {
                    Button("Email Us") {
                        viewModel.openEmailApp()
                    }
                    .foregroundColor(.blue)
                }
                
                // Account Actions Section
                Section("Account") {
                    Button("Sign Out") {
                        viewModel.signOut()
                    }
                    .foregroundColor(.red)
                    
                    Button("Delete Account") {
                        viewModel.deleteAccount()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadUserData()
            }
        }
    }
}

class SettingsViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    private var originalFirstName = ""
    private var originalLastName = ""
    
    var hasNameChanged: Bool {
        firstName != originalFirstName || lastName != originalLastName
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
                }
            }
        }
    }
    
    func updateName() {
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        let db = Firestore.firestore()
        db.collection("affiliates").document(user.uid).updateData([
            "firstName": firstName,
            "lastName": lastName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error updating name: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Name updated successfully!"
                    self?.originalFirstName = self?.firstName ?? ""
                    self?.originalLastName = self?.lastName ?? ""
                    
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
            } else {
                errorMessage = "Unable to open email app"
            }
        }
    }
    
    func deleteAccount() {
        // For now, just perform the logout action as requested
        signOut()
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }
}
