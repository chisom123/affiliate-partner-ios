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
                    .frame(maxWidth: .infinity)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                SecureField("Password", text: $password)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    createAccount()
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(email.isEmpty || password.isEmpty)
                .padding(.horizontal)
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
        .tint(.black)
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
