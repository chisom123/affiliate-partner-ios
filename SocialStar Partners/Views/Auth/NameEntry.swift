import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}

struct NameView: View {
    let email: String
    let password: String
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var navigateToDashboard = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.system(size: 24, weight: .bold))
            
            VStack(spacing: 15) {
                TextField("First Name", text: $firstName)
                    .frame(maxWidth: .infinity)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                TextField("Last Name", text: $lastName)
                    .frame(maxWidth: .infinity)
                    .textInputAutocapitalization(.words)
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
                        // Analytics: Track signup error
                        Analytics.shared.trackError(
                            message: errorMessage,
                            properties: [
                                AnalyticsProperty.screenName: "name_entry"
                            ]
                        )
                    }
            }
            
            // Fixed container width for loading state
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .frame(height: 50) // Same height as the button to maintain layout
                .padding(.horizontal)
            } else {
                Button(action: {
                    // Analytics: Track account creation attempt
                    Analytics.shared.trackTap(
                        elementId: "create_account_button",
                        screenName: "name_entry",
                        properties: [
                            "form_valid": !firstName.isEmpty && !lastName.isEmpty
                        ]
                    )
                    
                    createAccount()
                }) {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            (firstName.isEmpty || lastName.isEmpty) ?
                            Color.gray.opacity(0.5) :
                            Color.blue
                        )
                        .cornerRadius(8)
                }
                .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
                .padding(.horizontal)
            }
            
            // Hidden Navigation Link to Dashboard
            NavigationLink(destination: MainTabView(), isActive: $navigateToDashboard) {
                EmptyView()
            }
            .hidden()
        }
        .padding()
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onAppear {
            // Analytics: Track name entry screen view
            Analytics.shared.trackScreen(name: "name_entry")
        }
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = ""
        
        // Create Firebase Auth user first
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
            
            guard let user = result?.user else {
                errorMessage = "Failed to get user information"
                isLoading = false
                return
            }
            
            createFirestoreDocument(for: user)
        }
    }
    
    private func createFirestoreDocument(for user: User) {
        let db = Firestore.firestore()
        let affiliateData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "profilePictureUrl": NSNull(),
            "totalEarnings": 0,
            "totalRatings": 0,
            "createdAt": Timestamp(),
            "status": "active",
            "paymentInfo": NSNull(),
            "payoutHistory": [],
            "balance": 0.0,
            "totalWithdrawn": 0.0,
            "linkCredits": 0
        ]
        
        db.collection("affiliates").document(user.uid).setData(affiliateData) { error in
            isLoading = false
            
            if let error = error {
                errorMessage = "Failed to create account: \(error.localizedDescription)"
                return
            }
            
            // Analytics: Track successful account creation
            Analytics.shared.track(
                event: "account_created_successfully",
                properties: [
                    AnalyticsProperty.screenName: "name_entry",
                    "user_id": user.uid
                ]
            )
            
            // Account created successfully - navigate to dashboard
            navigateToDashboard = true
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }
}
