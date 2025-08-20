import SwiftUI
import Firebase

struct WithdrawView: View {
    @StateObject private var withdrawalViewModel = WithdrawalViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 1
    @State private var bankDetails = BankDetailsData()
    @State private var addressDetails = AddressDetailsData()
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case 1:
                    BankDetailsView(
                        bankDetails: $bankDetails,
                        onNext: { currentStep = 2 },
                        availableBalance: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        canWithdrawToday: withdrawalViewModel.canWithdrawToday(),
                        pendingAmount: withdrawalViewModel.pendingWithdrawalAmount()
                    )
                case 2:
                    AddressDetailsView(
                        addressDetails: $addressDetails,
                        onNext: { currentStep = 3 },
                        onBack: { currentStep = 1 }
                    )
                case 3:
                    WithdrawalConfirmationView(
                        bankDetails: bankDetails,
                        addressDetails: addressDetails,
                        withdrawalAmount: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        withdrawalViewModel: withdrawalViewModel,
                        onBack: { currentStep = 2 },
                        onSuccess: { dismiss() }
                    )
                default:
                    BankDetailsView(
                        bankDetails: $bankDetails,
                        onNext: { currentStep = 2 },
                        availableBalance: dashboardViewModel.affiliateData?.balance ?? 0.0,
                        canWithdrawToday: withdrawalViewModel.canWithdrawToday(),
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

// MARK: - Data Models
struct BankDetailsData {
    var firstName = ""
    var lastName = ""
    var bankName = ""
    var accountNumber = ""
    var routingNumber = ""
    var selectedAccountType = "checking"
    
    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AddressDetailsData {
    var addressLine1 = ""
    var city = ""
    var selectedState = ""
    var zipCode = ""
}

// MARK: - Step 1: Bank Details View
struct BankDetailsView: View {
    @Binding var bankDetails: BankDetailsData
    let onNext: () -> Void
    let availableBalance: Double
    let canWithdrawToday: Bool
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
                
                // Bank Account Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bank Account Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 16) {
                        // Name Fields
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                TextField("First Name", text: $bankDetails.firstName)
                                    .textInputAutocapitalization(.words)
                                    .focused($isInputActive)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                TextField("Last Name", text: $bankDetails.lastName)
                                    .textInputAutocapitalization(.words)
                                    .focused($isInputActive)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text("Name must match exactly as it appears on your bank account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Bank Name Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bank Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Menu {
                                ForEach(USBank.majorBanks, id: \.name) { bank in
                                    Button(bank.name) {
                                        bankDetails.bankName = bank.name
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(bankDetails.bankName.isEmpty ? "Select Your Bank" : bankDetails.bankName)
                                        .foregroundColor(bankDetails.bankName.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption.weight(.bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Account Number
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account Number")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("Account Number", text: $bankDetails.accountNumber)
                                .keyboardType(.numberPad)
                                .focused($isInputActive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Routing Number
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Routing Number")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("Routing Number", text: $bankDetails.routingNumber)
                                .keyboardType(.numberPad)
                                .focused($isInputActive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Account Type Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account Type")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Menu {
                                Button("Checking") {
                                    bankDetails.selectedAccountType = "checking"
                                }
                                
                                Button("Savings") {
                                    bankDetails.selectedAccountType = "savings"
                                }
                            } label: {
                                HStack {
                                    Text(bankDetails.selectedAccountType.capitalized)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption.weight(.bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Continue Button
                Button(action: {
                    Analytics.shared.trackTap(elementId: "continue_to_address_button", screenName: "withdraw_bank_details")
                    onNext()
                }) {
                    HStack {
                        Text("Continue to Address")
                            .font(.system(.body))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        (!isBankDetailsValid || !canWithdrawToday || availableBalance < 0.25) ? Color(.systemGray4) : Color.blue
                    )
                    .foregroundColor(
                        (!isBankDetailsValid || !canWithdrawToday || availableBalance < 0.25) ? Color(.systemGray2) : .white
                    )
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }
                .disabled(!isBankDetailsValid || !canWithdrawToday || availableBalance < 0.25)
                .padding(.vertical, 8)
            }
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
            Analytics.shared.trackScreen(name: "withdraw_bank_details")
        }
    }
    
    private var isBankDetailsValid: Bool {
        !bankDetails.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bankDetails.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bankDetails.bankName.isEmpty &&
        !bankDetails.accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bankDetails.routingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bankDetails.accountNumber.count >= 8 && bankDetails.accountNumber.count <= 17 &&
        bankDetails.routingNumber.count == 9 &&
        bankDetails.accountNumber.allSatisfy({ $0.isNumber }) &&
        bankDetails.routingNumber.allSatisfy({ $0.isNumber })
    }
}

// MARK: - Step 2: Address Details View
struct AddressDetailsView: View {
    @Binding var addressDetails: AddressDetailsData
    let onNext: () -> Void
    let onBack: () -> Void
    
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
                            .frame(width: UIScreen.main.bounds.width * 0.85 * (2.0 / 3.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                
                // Address Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Address")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 16) {
                        // Address Line 1
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Address Line 1")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("Address Line 1", text: $addressDetails.addressLine1)
                                .textInputAutocapitalization(.words)
                                .focused($isInputActive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // City
                        VStack(alignment: .leading, spacing: 6) {
                            Text("City")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("City", text: $addressDetails.city)
                                .textInputAutocapitalization(.words)
                                .focused($isInputActive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // State Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("State")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Menu {
                                ForEach(USState.allStates, id: \.code) { state in
                                    Button(state.name) {
                                        addressDetails.selectedState = state.code
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(addressDetails.selectedState.isEmpty ? "Select State" :
                                         USState.allStates.first(where: { $0.code == addressDetails.selectedState })?.name ?? addressDetails.selectedState)
                                        .foregroundColor(addressDetails.selectedState.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption.weight(.bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // ZIP Code
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ZIP Code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("ZIP Code", text: $addressDetails.zipCode)
                                .keyboardType(.numberPad)
                                .focused($isInputActive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Navigation Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "continue_to_review_button", screenName: "withdraw_address_details")
                        onNext()
                    }) {
                        HStack {
                            Text("Continue to Review")
                                .font(.system(.body))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(!isAddressValid ? Color(.systemGray4) : Color.blue)
                        .foregroundColor(!isAddressValid ? Color(.systemGray2) : .white)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    .disabled(!isAddressValid)
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "back_button", screenName: "withdraw_address_details")
                        onBack()
                    }) {
                        HStack {
                            Text("Back")
                                .font(.system(.body))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 20)
            }
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
            Analytics.shared.trackScreen(name: "withdraw_address_details")
        }
    }
    
    private var isAddressValid: Bool {
        !addressDetails.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addressDetails.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addressDetails.selectedState.isEmpty &&
        !addressDetails.zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Step 3: Confirmation View
struct WithdrawalConfirmationView: View {
    let bankDetails: BankDetailsData
    let addressDetails: AddressDetailsData
    let withdrawalAmount: Double
    let withdrawalViewModel: WithdrawalViewModel
    let onBack: () -> Void
    let onSuccess: () -> Void
    
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
                
                // Bank Account Review
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bank Account Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        ReviewRow(label: "Account Holder", value: bankDetails.fullName)
                        ReviewRow(label: "Bank", value: bankDetails.bankName)
                        ReviewRow(label: "Account Type", value: bankDetails.selectedAccountType.capitalized)
                        ReviewRow(label: "Account Number", value: "****\(String(bankDetails.accountNumber.suffix(4)))")
                        ReviewRow(label: "Routing Number", value: "****\(String(bankDetails.routingNumber.suffix(4)))")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Address Review
                VStack(alignment: .leading, spacing: 16) {
                    Text("Address Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        ReviewRow(label: "Address", value: addressDetails.addressLine1)
                        ReviewRow(label: "City, State ZIP", value: "\(addressDetails.city), \(addressDetails.selectedState) \(addressDetails.zipCode)")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Processing Info
                Text("Your money will arrive in your account within 2-5 business days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "submit_withdrawal_button", screenName: "withdraw_confirmation")
                        submitWithdrawal()
                    }) {
                        HStack {
                            if withdrawalViewModel.isLoading {
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
                        .background(withdrawalViewModel.isLoading ? Color(.systemGray4) : Color.blue)
                        .foregroundColor(withdrawalViewModel.isLoading ? Color(.systemGray2) : .white)
                        .cornerRadius(10)
                    }
                    .disabled(withdrawalViewModel.isLoading)
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
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
                
                // Messages
                VStack(spacing: 8) {
                    if !withdrawalViewModel.errorMessage.isEmpty {
                        Text(withdrawalViewModel.errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                    }
                    
                    if !withdrawalViewModel.successMessage.isEmpty {
                        Text(withdrawalViewModel.successMessage)
                            .foregroundColor(.green)
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
        let bankAccount = BankAccount(
            accountHolderName: bankDetails.fullName,
            bankName: bankDetails.bankName,
            accountNumber: bankDetails.accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            routingNumber: bankDetails.routingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountType: bankDetails.selectedAccountType,
            addressLine1: addressDetails.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            city: addressDetails.city.trimmingCharacters(in: .whitespacesAndNewlines),
            state: addressDetails.selectedState,
            zipCode: addressDetails.zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Task {
            await withdrawalViewModel.submitWithdrawal(
                amount: withdrawalAmount,
                bankAccount: bankAccount
            )
            
            // Close modal on success
            if !withdrawalViewModel.successMessage.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onSuccess()
                }
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

// MARK: - US Banks Helper
struct USBank {
    let name: String
    
    static let majorBanks = [
        USBank(name: "Ally Bank"),
        USBank(name: "American Express Bank"),
        USBank(name: "Bank of America"),
        USBank(name: "BB&T (Truist)"),
        USBank(name: "Capital One Bank"),
        USBank(name: "Charles Schwab Bank"),
        USBank(name: "Chase Bank"),
        USBank(name: "Chime Bank"),
        USBank(name: "Citibank"),
        USBank(name: "Citizens Bank"),
        USBank(name: "Credit Union (Local)"),
        USBank(name: "Discover Bank"),
        USBank(name: "Fifth Third Bank"),
        USBank(name: "First National Bank"),
        USBank(name: "HSBC Bank USA"),
        USBank(name: "Huntington Bank"),
        USBank(name: "KeyBank"),
        USBank(name: "M&T Bank"),
        USBank(name: "Navy Federal Credit Union"),
        USBank(name: "PNC Bank"),
        USBank(name: "Regions Bank"),
        USBank(name: "SunTrust (Truist)"),
        USBank(name: "TD Bank"),
        USBank(name: "U.S. Bank"),
        USBank(name: "USAA Bank"),
        USBank(name: "Wells Fargo")
    ]
}
