import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
                        .background(
                            (email.isEmpty || password.isEmpty) ?
                            Color.gray.opacity(0.5) :
                            Color.blue
                        )
                        .cornerRadius(8)
                }
                .disabled(email.isEmpty || password.isEmpty)
                .padding(.horizontal)
            }
        }
        .padding()
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onAppear {
            Analytics.shared.trackScreen(name: "sign_in")
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    Analytics.shared.track(
                        event: "signin_failed",
                        properties: [
                            AnalyticsProperty.screenName: "sign_in",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                }
                return
            }
            
            guard let user = Auth.auth().currentUser else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            Analytics.shared.track(
                event: "signin_successful",
                properties: [AnalyticsProperty.screenName: "sign_in"]
            )
            
            Analytics.shared.identify(
                userId: user.uid,
                properties: [
                    "email": user.email ?? "",
                    "created_at": user.metadata.creationDate?.timeIntervalSince1970 ?? 0
                ]
            )
            
            // Check if profile is complete
            Firestore.firestore().collection("affiliates").document(user.uid).getDocument { document, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    guard let data = document?.data() else {
                        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                        return
                    }
                    
                    let hasPhone = user.phoneNumber != nil && !user.phoneNumber!.isEmpty
                    let hasProfilePicture = (data["profilePictureUrl"] as? String).map { !$0.isEmpty } ?? false
                    
                    if !hasPhone || !hasProfilePicture {
                        Analytics.shared.track(
                            event: "signin_profile_incomplete",
                            properties: [
                                AnalyticsProperty.screenName: "sign_in",
                                "has_phone": hasPhone,
                                "has_profile_picture": hasProfilePicture
                            ]
                        )
                        NotificationCenter.default.post(name: .profileIncomplete, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                    }
                }
            }
        }
    }
}
