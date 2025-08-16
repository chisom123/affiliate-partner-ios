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
            
            DisclaimerText()
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    validateAndContinue()
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
                destination: NameView(email: email.replacingOccurrences(of: " ", with: ""), password: password),
                isActive: $navigateToName
            ) {
                EmptyView()
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
    }
    
    private func validateAndContinue() {
        isLoading = true
        errorMessage = ""
        
        // Basic email validation
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            isLoading = false
            return
        }
        
        // Basic password validation
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }
        
        // If validation passes, navigate to name view
        isLoading = false
        navigateToName = true
    }
}

struct DisclaimerText: View {
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack {
            let readOurText = Text("Read our ")
            let privacyText = Text("Privacy Policy").underline()
            let andText = Text(" and Tap \"Continue\" to accept the ")
            let termsText = Text("Terms of Use (EULA)").underline()
            
            (readOurText + privacyText + andText + termsText)
                .padding(.horizontal)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .onTapGesture {
                    showingActionSheet = true
                }
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(
                        title: Text("Choose Document"),
                        message: Text("Which document would you like to view?"),
                        buttons: [
                            .default(Text("Terms of Use (EULA)")) {
                                openURL("https://chay-b6172c.webflow.io")
                            },
                            .default(Text("Privacy Policy")) {
                                openURL("https://chay-b6172c.webflow.io/privacy-policy")
                            },
                            .cancel()
                        ]
                    )
                }
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
