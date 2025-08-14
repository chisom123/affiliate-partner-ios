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
                    TextField("Full Name", text: $accountHolderName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Bank Name", text: $bankName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Account Number", text: $accountNumber)
                        .keyboardType(.numberPad)
                    
                    TextField("Routing Number", text: $routingNumber)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Bank Account Details")
                } footer: {
                    Text("Your bank details are encrypted and stored securely")
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
            Text("Withdraw $\(withdrawAmount) to ****\(accountNumber.suffix(4))?")
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
    
    private var isFormValid: Bool {
        // Check withdrawal amount
        guard withdrawalAmount >= 0.25 else { return false }
        guard withdrawalAmount <= availableBalance else { return false }
        
        // Check daily limit
        guard canWithdrawToday else { return false }
        
        // Check all fields are filled
        guard !accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !routingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Validate bank account format
        let bankAccount = BankAccount(
            accountHolderName: accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            routingNumber: routingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        return withdrawalViewModel.validateBankAccount(bankAccount) == nil
    }
    
    // MARK: - Actions
    
    private func submitWithdrawal() {
        let bankAccount = BankAccount(
            accountHolderName: accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            routingNumber: routingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
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
