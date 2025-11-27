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
    @State private var navigateToProfilePicture = false
    
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
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    // Analytics: Track account creation attempt
                    Analytics.shared.trackTap(
                        elementId: "continue_to_profile_picture_button",
                        screenName: "name_entry",
                        properties: [
                            "form_valid": !firstName.isEmpty && !lastName.isEmpty
                        ]
                    )
                    
                    navigateToProfilePicture = true
                }) {
                    Text("Continue")
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
                .disabled(firstName.isEmpty || lastName.isEmpty)
                .padding(.horizontal)
            }
            
            // Navigation Link to Profile Picture
            NavigationLink(
                destination: ProfilePictureView(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                ),
                isActive: $navigateToProfilePicture
            ) {
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
}
