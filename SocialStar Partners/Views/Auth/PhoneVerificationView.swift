import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let verificationID: String

    @State private var otpCode = ""
    @State private var errorMessage = ""
    @State private var navigateToProfilePicture = false

    @State private var resendCooldown = 0
    @State private var cooldownTimer: Timer?

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

            resendSection

            NavigationLink(
                destination: ProfilePictureView(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    phoneVerificationID: verificationID,
                    phoneOTPCode: otpCode
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
                        .underline()
                }
            }
        }
    }

    private func verify() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Analytics.shared.trackTap(elementId: "verify_button", screenName: "phone_verification")
        Analytics.shared.track(
            event: "phone_verification_code_entered",
            properties: [AnalyticsProperty.screenName: "phone_verification"]
        )
        navigateToProfilePicture = true
    }

    private func resendCode() {
        Analytics.shared.trackTap(elementId: "resend_code_button", screenName: "phone_verification")
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { _, error in
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

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            resendCooldown -= 1
            if resendCooldown <= 0 { timer.invalidate() }
        }
    }
}
