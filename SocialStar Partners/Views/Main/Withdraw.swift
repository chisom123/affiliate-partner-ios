import SwiftUI
import Firebase

struct WithdrawView: View {
    @StateObject private var withdrawalViewModel = WithdrawalViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 1
    @State private var paypalEmail = ""
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case 1:
                    PayPalDetailsView(
                        paypalEmail: $paypalEmail,
                        onNext: {
                            Analytics.shared.trackTap(elementId: "continue_to_review_button", screenName: "withdraw_paypal_details")
                            currentStep = 2
                        },
                        availableBalance: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        pendingAmount: withdrawalViewModel.pendingWithdrawalAmount()
                    )
                case 2:
                    WithdrawalConfirmationView(
                        paypalEmail: paypalEmail,
                        withdrawalAmount: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        withdrawalViewModel: withdrawalViewModel,
                        onBack: { currentStep = 1 },
                        onSuccess: { dismiss() }
                    )
                default:
                    PayPalDetailsView(
                        paypalEmail: $paypalEmail,
                        onNext: { currentStep = 2 },
                        availableBalance: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        pendingAmount: withdrawalViewModel.pendingWithdrawalAmount()
                    )
                }
            }
            .navigationTitle("Withdraw Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "withdraw")
            dashboardViewModel.loadData()
            withdrawalViewModel.loadWithdrawals()
        }
    }
}

// MARK: - Step 1: PayPal Details View
struct PayPalDetailsView: View {
    @Binding var paypalEmail: String
    let onNext: () -> Void
    let availableBalance: Double
    let pendingAmount: Double
    
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress indicator
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .leading) {
                        // Background bar
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        // Progress bar
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: UIScreen.main.bounds.width * 0.85 * (1.0 / 3.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                
                // PayPal Email Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("PayPal Withdraw")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter your PayPal Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("", text: $paypalEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($isInputActive)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.top)
                }
                .padding(.horizontal)
                
                // Continue Button
                Button(action: {
                    Analytics.shared.trackTap(elementId: "continue_to_review_button", screenName: "withdraw_confirmation")
                    onNext()
                }) {
                    HStack {
                        Text("Continue to Summary")
                            .font(.system(.body))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        (!isPayPalEmailValid || availableBalance < 5) ? Color(.systemGray4) : Color.blue
                    )
                    .foregroundColor(
                        (!isPayPalEmailValid || availableBalance < 5) ? Color(.systemGray2) : .white
                    )
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }
                .disabled(!isPayPalEmailValid || availableBalance < 5)
                .padding(.vertical, 8)
                
                // PayPal signup link - MOVED BELOW CONTINUE BUTTON
                HStack {
                    Text("Don't have a PayPal account?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        openPayPalSignup()
                    }) {
                        Text("Create one here")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.top)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                }
                .bold()
            }
        }
        .tint(.black)
        .onAppear {
            Analytics.shared.trackScreen(name: "withdraw_paypal_details")
        }
    }
    
    private var isPayPalEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: paypalEmail.trimmingCharacters(in: .whitespaces))
    }
    
    private func openPayPalSignup() {
        guard let url = URL(string: "https://www.paypal.com/signup") else { return }
        
        Analytics.shared.trackTap(elementId: "create_paypal_account_link", screenName: "withdraw_paypal_details")
        
        // Open PayPal signup page in Safari
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - Step 2: Updated Confirmation View
struct WithdrawalConfirmationView: View {
    let paypalEmail: String
    let withdrawalAmount: Double
    let withdrawalViewModel: WithdrawalViewModel
    let onBack: () -> Void
    let onSuccess: () -> Void
    
    @State private var isSubmitting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress indicator
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .leading) {
                        // Background bar
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        // Progress bar
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: UIScreen.main.bounds.width * 0.85, height: 8)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                
                // Withdrawal Summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Withdrawal Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Withdrawal Amount")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        Text("$\(withdrawalAmount, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // PayPal Details Review
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        ReviewRow(label: "Payment Method", value: "PayPal")
                        ReviewRow(label: "PayPal Email", value: paypalEmail)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Processing Info
                Text("Your money will arrive in your PayPal account within 1-5 days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "submit_withdrawal_button", screenName: "withdraw_confirmation")
                        submitWithdrawal()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Submit Withdrawal")
                                    .font(.system(.body))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSubmitting ? Color(.systemGray4) : Color.blue)
                        .foregroundColor(isSubmitting ? Color(.systemGray2) : .white)
                        .cornerRadius(10)
                    }
                    .disabled(isSubmitting)
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "back_button", screenName: "withdraw_confirmation")
                        onBack()
                    }) {
                        HStack {
                            Text("Back")
                                .font(.system(.body))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    .disabled(isSubmitting) // Also disable back button during submission
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
                
                // Error Messages Only
                VStack(spacing: 8) {
                    if !withdrawalViewModel.errorMessage.isEmpty {
                        Text(withdrawalViewModel.errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .tint(.black)
        .onAppear {
            Analytics.shared.trackScreen(name: "withdraw_confirmation")
        }
    }
    
    private func submitWithdrawal() {
        // Prevent multiple submissions
        guard !isSubmitting else { return }
        
        isSubmitting = true
        
        Task {
            await withdrawalViewModel.submitPayPalWithdrawal(
                amount: withdrawalAmount,
                paypalEmail: paypalEmail.trimmingCharacters(in: .whitespaces)
            )
            
            await MainActor.run {
                isSubmitting = false
                
                // Navigate immediately on success, stay on error
                if !withdrawalViewModel.successMessage.isEmpty {
                    onSuccess() // Immediate navigation
                }
                // If there's an error, user stays on this view to see the error message
            }
        }
    }
}

// MARK: - Helper Views
struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}
