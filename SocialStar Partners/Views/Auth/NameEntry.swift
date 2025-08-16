import SwiftUI
import Firebase
import FirebaseAuth

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
            }
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    createAccount()
                }) {
                    Text("Complete Setup")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(firstName.isEmpty || lastName.isEmpty)
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
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
            
            // User created successfully, now create Firestore document
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
            "totalEarnings": 0,
            "totalRatings": 0,
            "createdAt": Timestamp(),
            "status": "active",
            "paymentInfo": NSNull(),
            "payoutHistory": [],
            "balance": 0.0,
            "totalWithdrawn": 0.0
        ]
        
        db.collection("affiliates").document(user.uid).setData(affiliateData) { error in
            isLoading = false
            
            if let error = error {
                errorMessage = "Failed to create account: \(error.localizedDescription)"
                return
            }
            
            // Account created successfully - navigate to dashboard
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }
}
