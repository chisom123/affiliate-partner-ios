import SwiftUI
import Firebase

struct WithdrawView: View {
    @StateObject private var withdrawalViewModel = WithdrawalViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var withdrawAmount = ""
    @State private var accountHolderName = ""
    @State private var bankName = ""
    @State private var accountNumber = ""
    @State private var routingNumber = ""
    @State private var selectedAccountType = "checking" // Default to checking
    
    // Address fields
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var selectedState = ""
    @State private var zipCode = ""
    
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                // Current Balance Section
                Section {
                    HStack {
                        Text("Available Balance")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        Text("$\(dashboardViewModel.affiliateData?.balance ?? 0.0, specifier: "%.2f")")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Account Balance")
                }
                
                // Withdrawal Amount Section
                Section {
                    HStack {
                        Text("$")
                            .font(.system(size: 18, weight: .medium))
                        TextField("0.00", text: $withdrawAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18))
                    }
                    
                    if !canWithdrawToday {
                        Text("You can only withdraw once per day")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if pendingAmount > 0 {
                        Text("You have $\(pendingAmount, specifier: "%.2f") in pending withdrawals")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Withdrawal Amount")
                } footer: {
                    Text("Minimum withdrawal: $0.25")
                }
                
                // Bank Account Section
                Section {
                    TextField("Full Name (as on bank account)", text: $accountHolderName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Bank Name", text: $bankName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Account Number", text: $accountNumber)
                        .keyboardType(.numberPad)
                    
                    TextField("Routing Number", text: $routingNumber)
                        .keyboardType(.numberPad)
                    
                    // Account Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            Button(action: {
                                selectedAccountType = "checking"
                            }) {
                                HStack {
                                    Text("Checking")
                                    Spacer()
                                    if selectedAccountType == "checking" {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Button(action: {
                                selectedAccountType = "savings"
                            }) {
                                HStack {
                                    Text("Savings")
                                    Spacer()
                                    if selectedAccountType == "savings" {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedAccountType.isEmpty ? "Select Account Type" : selectedAccountType.capitalized)
                                    .foregroundColor(selectedAccountType.isEmpty ? .secondary : .primary)
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
                
                // Address Section
                Section {
                    TextField("Address Line 1", text: $addressLine1)
                        .textInputAutocapitalization(.words)
                    
                    TextField("City", text: $city)
                        .textInputAutocapitalization(.words)
                    
                    // State Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            ForEach(USState.allStates, id: \.code) { state in
                                Button(action: {
                                    selectedState = state.code
                                }) {
                                    HStack {
                                        Text(state.name)
                                        Spacer()
                                        if selectedState == state.code {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedState.isEmpty ? "Select State" :
                                     USState.allStates.first(where: { $0.code == selectedState })?.name ?? selectedState)
                                    .foregroundColor(selectedState.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                } header: {
                    Text("US Address (Required for International Transfer)")
                } footer: {
                    Text("Your address is required for transfers from the UK to US bank accounts")
                }
                
                // Submit Section
                Section {
                    Button("Submit Withdrawal") {
                        showingConfirmation = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid || withdrawalViewModel.isLoading)
                    
                    if withdrawalViewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
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
        .alert("Confirm Withdrawal", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                submitWithdrawal()
            }
        } message: {
            Text("Withdraw $\(withdrawAmount) to \(selectedAccountType.capitalized) account ****\(accountNumber.suffix(4)) in \(city), \(selectedStateName)?")
        }
    }
    
    // MARK: - Computed Properties
    
    private var withdrawalAmount: Double {
        Double(withdrawAmount) ?? 0.0
    }
    
    private var availableBalance: Double {
        dashboardViewModel.affiliateData?.balance ?? 0.0
    }
    
    private var canWithdrawToday: Bool {
        withdrawalViewModel.canWithdrawToday()
    }
    
    private var pendingAmount: Double {
        withdrawalViewModel.pendingWithdrawalAmount()
    }
    
    private var selectedStateName: String {
        USState.allStates.first(where: { $0.code == selectedState })?.name ?? selectedState
    }
    
    private var isFormValid: Bool {
        // Check withdrawal amount
        guard withdrawalAmount >= 0.25 else { return false }
        guard withdrawalAmount <= availableBalance else { return false }
        
        // Check daily limit
        guard canWithdrawToday else { return false }
        
        // Check all fields are filled (including account type)
        guard !accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !routingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !selectedAccountType.isEmpty,
              !addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !selectedState.isEmpty,
              !zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Validate bank account format
        let bankAccount = BankAccount(
            accountHolderName: accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            routingNumber: routingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountType: selectedAccountType,
            addressLine1: addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            state: selectedState,
            zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        return withdrawalViewModel.validateBankAccount(bankAccount) == nil
    }
    
    // MARK: - Actions
    
    private func submitWithdrawal() {
        let bankAccount = BankAccount(
            accountHolderName: accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            routingNumber: routingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountType: selectedAccountType,
            addressLine1: addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            state: selectedState,
            zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Task {
            await withdrawalViewModel.submitWithdrawal(
                amount: withdrawalAmount,
                bankAccount: bankAccount
            )
            
            // Close modal on success
            if !withdrawalViewModel.successMessage.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}
