import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PhoneVerificationView: View {
    let phoneNumber: String
    let verificationID: String

    @State private var otpCode = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    @State private var resendCooldown = 0
    @State private var cooldownTimer: Timer?

    @State private var navigateToName = false

    private var isCodeComplete: Bool { otpCode.filter(\.isNumber).count == 6 }

    var body: some View {
        VStack(spacing: 30) {
            Text("Enter Your Code")
                .font(.system(size: 24, weight: .bold))

            Text("We sent a 6-digit code to\n\(phoneNumber)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TextField("6-digit code", text: $otpCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: otpCode) { newValue in
                    let digits = newValue.filter(\.isNumber)
                    otpCode = String(digits.prefix(6))
                }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if isLoading {
                ProgressView()
            } else {
                Button(action: verify) {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(isCodeComplete ? Color.blue : Color.gray.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!isCodeComplete)
                .padding(.horizontal)
            }

            resendSection

            NavigationLink(
                destination: NameView(phoneNumber: phoneNumber),
                isActive: $navigateToName
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
            Analytics.shared.trackScreen(name: "phone_verification")
        }
        .onDisappear {
            cooldownTimer?.invalidate()
        }
    }

    private var resendSection: some View {
        Group {
            if resendCooldown > 0 {
                Text("Resend code in \(resendCooldown)s")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            } else {
                Button(action: resendCode) {
                    Text("Resend Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func verify() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true
        errorMessage = ""

        Analytics.shared.trackTap(
            elementId: "verify_button",
            screenName: "phone_verification"
        )
        Analytics.shared.track(
            event: "phone_verification_code_entered",
            properties: [AnalyticsProperty.screenName: "phone_verification"]
        )

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )

        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    let code = (error as NSError).code
                    if code == 17044 || code == 17045 {
                        errorMessage = "Your code has expired. Please go back and request a new one."
                    } else {
                        errorMessage = "Verification failed. Please try again."
                    }
                    Analytics.shared.track(
                        event: "phone_verification_failed",
                        properties: [
                            AnalyticsProperty.screenName: "phone_verification",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                }
                return
            }

            guard let user = result?.user else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Something went wrong. Please try again."
                }
                return
            }

            Firestore.firestore().collection("affiliates").document(user.uid).getDocument { document, error in
                DispatchQueue.main.async {
                    isLoading = false

                    guard let data = document?.data() else {
                        Analytics.shared.track(
                            event: "new_user_verified",
                            properties: [AnalyticsProperty.screenName: "phone_verification"]
                        )
                        navigateToName = true
                        return
                    }

                    let hasName = (data["firstName"] as? String).map { !$0.isEmpty } ?? false
                    let hasEmail = (data["email"] as? String).map { !$0.isEmpty } ?? false
                    let hasProfilePicture = (data["profilePictureUrl"] as? String).map { !$0.isEmpty } ?? false

                    if hasName && hasEmail && hasProfilePicture {
                        Analytics.shared.track(
                            event: "returning_user_verified",
                            properties: [AnalyticsProperty.screenName: "phone_verification"]
                        )
                        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                    } else {
                        Analytics.shared.track(
                            event: "incomplete_user_verified",
                            properties: [
                                AnalyticsProperty.screenName: "phone_verification",
                                "has_name": hasName,
                                "has_email": hasEmail,
                                "has_profile_picture": hasProfilePicture
                            ]
                        )
                        NotificationCenter.default.post(name: .profileIncomplete, object: nil)
                    }
                }
            }
        }
    }

    private func resendCode() {
        Analytics.shared.trackTap(
            elementId: "resend_code_button",
            screenName: "phone_verification"
        )
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Couldn't resend code. Please try again."
                    Analytics.shared.track(
                        event: "phone_verification_resend_failed",
                        properties: [
                            AnalyticsProperty.screenName: "phone_verification",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                    return
                }
                Analytics.shared.track(
                    event: "phone_verification_code_resent",
                    properties: [AnalyticsProperty.screenName: "phone_verification"]
                )
                startCooldown()
            }
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                resendCooldown -= 1
                if resendCooldown <= 0 { timer.invalidate() }
            }
        }
    }
}
