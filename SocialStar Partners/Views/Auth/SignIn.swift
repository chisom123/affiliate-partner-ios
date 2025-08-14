import SwiftUI
import Firebase
import FirebaseAuth

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Welcome Back")
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
                ProgressView("Signing in...")
            } else {
                Button("Sign In") {
                    signIn()
                }
                .font(.system(size: 18, weight: .bold))
                .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            // Sign in successful - trigger app state change
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }
}
