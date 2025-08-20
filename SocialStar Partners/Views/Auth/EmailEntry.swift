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
                    .onAppear {
                        // Analytics: Track validation error
                        Analytics.shared.trackError(
                            message: errorMessage,
                            properties: [
                                AnalyticsProperty.screenName: "email_entry"
                            ]
                        )
                    }
            }
            
            DisclaimerText()
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    // Analytics: Track continue button tap
                    Analytics.shared.trackTap(
                        elementId: "continue_button",
                        screenName: "email_entry",
                        properties: [
                            "form_valid": !email.isEmpty && !password.isEmpty
                        ]
                    )
                    
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
        .onAppear {
            // Analytics: Track email entry screen view
            Analytics.shared.trackScreen(name: "email_entry")
        }
        .onChange(of: navigateToName) { isNavigating in
            if isNavigating {
                // Analytics: Track successful validation and navigation
                Analytics.shared.track(
                    event: "email_validation_passed",
                    properties: [
                        AnalyticsProperty.screenName: "email_entry"
                    ]
                )
            }
        }
    }
    
    private func validateAndContinue() {
        isLoading = true
        errorMessage = ""
        
        // Basic email validation
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            isLoading = false
            
            // Analytics: Track email validation failure
            Analytics.shared.track(
                event: "email_validation_failed",
                properties: [
                    AnalyticsProperty.screenName: "email_entry",
                    "validation_error": "invalid_email_format"
                ]
            )
            return
        }
        
        // Basic password validation
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            
            // Analytics: Track password validation failure
            Analytics.shared.track(
                event: "password_validation_failed",
                properties: [
                    AnalyticsProperty.screenName: "email_entry",
                    "validation_error": "password_too_short",
                    "password_length": password.count
                ]
            )
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
                    // Analytics: Track disclaimer text tap
                    Analytics.shared.trackTap(
                        elementId: "disclaimer_text",
                        screenName: "email_entry"
                    )
                    
                    showingActionSheet = true
                }
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(
                        title: Text("Choose Document"),
                        message: Text("Which document would you like to view?"),
                        buttons: [
                            .default(Text("Terms of Use (EULA)")) {
                                // Analytics: Track terms of use selection
                                Analytics.shared.trackTap(
                                    elementId: "terms_of_use_link",
                                    screenName: "email_entry"
                                )
                                
                                openURL("https://chay-b6172c.webflow.io")
                            },
                            .default(Text("Privacy Policy")) {
                                // Analytics: Track privacy policy selection
                                Analytics.shared.trackTap(
                                    elementId: "privacy_policy_link",
                                    screenName: "email_entry"
                                )
                                
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
