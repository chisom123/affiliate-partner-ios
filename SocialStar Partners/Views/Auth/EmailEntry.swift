import SwiftUI
import Firebase
import FirebaseAuth

struct EmailEntryView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var navigateToName = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Create Your Account")
                .font(.system(size: 24, weight: .bold))
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if isLoading {
                ProgressView("Creating account...")
            } else {
                Button("Continue") {
                    createAccount()
                }
                .font(.system(size: 18, weight: .bold))
                .disabled(email.isEmpty || password.isEmpty)
            }
            
            NavigationLink(
                destination: NameView(email: email),
                isActive: $navigateToName
            ) {
                EmptyView()
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            // Account created successfully - go to name entry
            navigateToName = true
        }
    }
}
