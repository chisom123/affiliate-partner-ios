import SwiftUI
import FirebaseAuth

struct PhoneEntryView: View {
    private let countries: [(name: String, code: String, flag: String)] = [
        ("United States", "+1", "🇺🇸"),
        ("United Kingdom", "+44", "🇬🇧")
    ]
    @State private var selectedCountryIndex = 0
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var navigateToVerification = false
    @State private var verificationID = ""

    private var selectedCountry: (name: String, code: String, flag: String) {
        countries[selectedCountryIndex]
    }

    private var fullPhoneNumber: String {
        var digits = phoneNumber.trimmingCharacters(in: .whitespaces)
        if selectedCountry.code == "+44" {
            digits = digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
        }
        return "\(selectedCountry.code)\(digits)"
    }

    private var isFormValid: Bool {
        phoneNumber.filter(\.isNumber).count >= 9
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Enter Your Number")
                .font(.system(size: 24, weight: .bold))

            Text("We'll send a one-time code to verify your identity.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 0) {
                Menu {
                    ForEach(countries.indices, id: \.self) { index in
                        Button(action: {
                            selectedCountryIndex = index
                            phoneNumber = ""
                        }) {
                            Text("\(countries[index].flag)  \(countries[index].name) (\(countries[index].code))")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                            .font(.system(size: 22))
                        Text(selectedCountry.code)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer().frame(width: 10)

                TextField(
                    selectedCountry.code == "+1" ? "(555) 000-0000" : "07700 900000",
                    text: $phoneNumber
                )
                .keyboardType(.phonePad)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
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
                Button(action: sendVerificationCode) {
                    Text("Send Code")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(isFormValid ? Color.blue : Color.gray.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!isFormValid)
                .padding(.horizontal)
            }

            NavigationLink(
                destination: PhoneVerificationView(
                    phoneNumber: fullPhoneNumber,
                    verificationID: verificationID
                ),
                isActive: $navigateToVerification
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
            Analytics.shared.trackScreen(name: "phone_entry")
        }
    }

    private func sendVerificationCode() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        isLoading = true
        errorMessage = ""

        Analytics.shared.trackTap(
            elementId: "send_code_button",
            screenName: "phone_entry",
            properties: ["country_code": selectedCountry.code]
        )

        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { verificationId, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = friendlyError(error)
                    Analytics.shared.track(
                        event: "phone_verification_send_failed",
                        properties: [
                            AnalyticsProperty.screenName: "phone_entry",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                    return
                }

                guard let verificationId = verificationId else {
                    errorMessage = "Something went wrong. Please try again."
                    return
                }

                verificationID = verificationId
                navigateToVerification = true
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17010: return "Too many requests. Please wait a moment and try again."
        case 17042: return "Invalid phone number. Please check and try again."
        default: return "Couldn't send code. Please check your number and try again."
        }
    }
}
