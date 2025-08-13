import SwiftUI
import Firebase
import FirebaseAuth

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}

struct NameView: View {
    let email: String
    
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
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Last Name", text: $lastName)
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
                Button("Complete Setup") {
                    createAccount()
                }
                .font(.system(size: 18, weight: .bold))
                .disabled(firstName.isEmpty || lastName.isEmpty)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = ""
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No authenticated user found"
            isLoading = false
            return
        }
        
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
            "payoutHistory": []
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
