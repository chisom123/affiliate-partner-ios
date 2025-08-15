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
            .navigationTitle("Withdraw Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
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
        Form {
            // Balance Information Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Withdrawal Amount")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("$\(availableBalance, specifier: "%.2f")")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Full Balance")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                    }
                }
                .padding(.vertical, 8)
                
                if !canWithdrawToday {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("You can only withdraw once per day")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if pendingAmount > 0 {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("$\(pendingAmount, specifier: "%.2f") in pending withdrawals")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text("Withdrawal Details")
            } footer: {
                Text("Your full available balance will be withdrawn")
            }
            
            // Bank Account Section
            Section {
                HStack(spacing: 12) {
                    TextField("First Name", text: $bankDetails.firstName)
                        .textInputAutocapitalization(.words)
                        .focused($isInputActive)
                    
                    TextField("Last Name", text: $bankDetails.lastName)
                        .textInputAutocapitalization(.words)
                        .focused($isInputActive)
                }
                
                Text("Name must match exactly as it appears on your bank account")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Bank Name Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bank Name")
                        .font(.caption)
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
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                TextField("Account Number", text: $bankDetails.accountNumber)
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                
                TextField("Routing Number", text: $bankDetails.routingNumber)
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
                
                // Account Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Type")
                        .font(.caption)
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
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
            } header: {
                Text("Bank Account Details")
            }
            
            // Continue Button
            Section {
                Button("Continue to Address") {
                    onNext()
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .disabled(!isBankDetailsValid || !canWithdrawToday || availableBalance < 0.25)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                }
            }
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
        Form {
            // Progress indicator
            Section {
                HStack {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(step <= 2 ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < 2 ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Step 2 of 3")
            }
            
            // Address Section
            Section {
                TextField("Address Line 1", text: $addressDetails.addressLine1)
                    .textInputAutocapitalization(.words)
                    .focused($isInputActive)
                
                TextField("City", text: $addressDetails.city)
                    .textInputAutocapitalization(.words)
                    .focused($isInputActive)
                
                // State Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("State")
                        .font(.caption)
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
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                TextField("ZIP Code", text: $addressDetails.zipCode)
                    .keyboardType(.numberPad)
                    .focused($isInputActive)
            } header: {
                Text("US Address")
            } footer: {
                Text("Your address is required for international transfers to US bank accounts")
            }
            
            // Navigation Buttons
            Section {
                HStack(spacing: 12) {
                    Button("Back") {
                        onBack()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    
                    Button("Continue to Review") {
                        onNext()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .disabled(!isAddressValid)
                }
            }
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
    
    @State private var showingFinalConfirmation = false
    
    var body: some View {
        Form {
            // Progress indicator
            Section {
                HStack {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        
                        if step < 3 {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Step 3 of 3 - Review & Confirm")
            }
            
            // Withdrawal Summary
            Section {
                HStack {
                    Text("Withdrawal Amount")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Text("$\(withdrawalAmount, specifier: "%.2f")")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Withdrawal Summary")
            }
            
            // Bank Account Review
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Account Holder:")
                        Spacer()
                        Text(bankDetails.fullName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    HStack {
                        Text("Bank:")
                        Spacer()
                        Text(bankDetails.bankName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    HStack {
                        Text("Account Type:")
                        Spacer()
                        Text(bankDetails.selectedAccountType.capitalized)
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    HStack {
                        Text("Account Number:")
                        Spacer()
                        Text("****\(String(bankDetails.accountNumber.suffix(4)))")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    HStack {
                        Text("Routing Number:")
                        Spacer()
                        Text("****\(String(bankDetails.routingNumber.suffix(4)))")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            } header: {
                Text("Bank Account Details")
            }
            
            // Address Review
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Address:")
                        Spacer()
                        Text(addressDetails.addressLine1)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("City, State ZIP:")
                        Spacer()
                        Text("\(addressDetails.city), \(addressDetails.selectedState) \(addressDetails.zipCode)")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            } header: {
                Text("Address Details")
            }
            
            // Processing Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Processing Time: 3-5 business days")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                        Text("Your bank details are encrypted and secure")
                            .font(.system(size: 14))
                    }
                }
            } header: {
                Text("Important Information")
            }
            
            // Action Buttons
            Section {
                Button(action: {
                    showingFinalConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Submit Withdrawal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(withdrawalViewModel.isLoading ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(withdrawalViewModel.isLoading)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    onBack()
                }) {
                    HStack {
                        Spacer()
                        Text("Back to Address")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if withdrawalViewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing withdrawal...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Messages
            if !withdrawalViewModel.errorMessage.isEmpty {
                Section {
                    Text(withdrawalViewModel.errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                }
            }
            
            if !withdrawalViewModel.successMessage.isEmpty {
                Section {
                    Text(withdrawalViewModel.successMessage)
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                }
            }
        }
        .alert("Confirm Withdrawal", isPresented: $showingFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                submitWithdrawal()
            }
        } message: {
            Text("Withdraw $\(withdrawalAmount, specifier: "%.2f") to your \(bankDetails.selectedAccountType) account ending in \(String(bankDetails.accountNumber.suffix(4)))?")
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
