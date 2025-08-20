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
                    .onAppear {
                        // Analytics: Track signin error
                        Analytics.shared.trackError(
                            message: errorMessage,
                            properties: [
                                AnalyticsProperty.screenName: "sign_in"
                            ]
                        )
                    }
            }
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    // Analytics: Track signin attempt
                    Analytics.shared.trackTap(
                        elementId: "signin_button",
                        screenName: "sign_in",
                        properties: [
                            "form_valid": !email.isEmpty && !password.isEmpty
                        ]
                    )
                    
                    signIn()
                }) {
                    Text("Log In")
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
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onAppear {
            // Analytics: Track signin screen view
            Analytics.shared.trackScreen(name: "sign_in")
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                
                // Analytics: Track signin failure
                Analytics.shared.track(
                    event: "signin_failed",
                    properties: [
                        AnalyticsProperty.screenName: "sign_in",
                        AnalyticsProperty.errorMessage: error.localizedDescription
                    ]
                )
                return
            }
            
            // Analytics: Track successful signin
            Analytics.shared.track(
                event: "signin_successful",
                properties: [
                    AnalyticsProperty.screenName: "sign_in"
                ]
            )
            
            // Sign in successful - trigger app state change
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
            
            // After successful authentication
            if let user = Auth.auth().currentUser {
                Analytics.shared.identify(
                    userId: user.uid,
                    properties: [
                        "email": user.email ?? "",
                        "created_at": user.metadata.creationDate?.timeIntervalSince1970 ?? 0
                    ]
                )
            }
        }
    }
}
