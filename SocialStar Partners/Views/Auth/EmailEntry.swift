import SwiftUI

struct EmailEntryView: View {
    let phoneNumber: String
    let firstName: String
    let lastName: String

    @State private var email = ""
    @State private var errorMessage = ""
    @State private var navigateToProfilePicture = false

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your email?")
                .font(.system(size: 24, weight: .bold))

            Text("We'll use this to send you important account updates.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TextField("Email", text: $email)
                .frame(maxWidth: .infinity)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding(.vertical, 12)
                .padding(.leading, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onAppear {
                        Analytics.shared.trackError(
                            message: errorMessage,
                            properties: [AnalyticsProperty.screenName: "email_entry"]
                        )
                    }
            }

            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "continue_button",
                    screenName: "email_entry",
                    properties: ["form_valid": isValidEmail]
                )
                guard isValidEmail else {
                    errorMessage = "Please enter a valid email address"
                    Analytics.shared.track(
                        event: "email_validation_failed",
                        properties: [
                            AnalyticsProperty.screenName: "email_entry",
                            "validation_error": "invalid_email_format"
                        ]
                    )
                    return
                }
                errorMessage = ""
                navigateToProfilePicture = true
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(email.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(email.isEmpty)
            .padding(.horizontal)

            NavigationLink(
                destination: ProfilePictureView(
                    firstName: firstName,
                    lastName: lastName,
                    email: email
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
            Analytics.shared.trackScreen(name: "email_entry")
        }
    }
}
