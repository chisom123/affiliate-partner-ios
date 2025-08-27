import Foundation
import Firebase
import Combine
import FirebaseAuth

class WithdrawalViewModel: ObservableObject {
    @Published var withdrawals: [Withdrawal] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    private var withdrawalsListener: ListenerRegistration?
    
    deinit {
        withdrawalsListener?.remove()
    }
    
    // MARK: - Load User's Withdrawals
    func loadWithdrawals() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Analytics: Track withdrawal data loading
        Analytics.shared.track(
            event: "withdrawals_load_started",
            properties: [
                "user_id": user.uid
            ]
        )
        
        let db = Firestore.firestore()
        
        // Real-time listener for user's withdrawals
        withdrawalsListener = db.collection("withdrawals")
            .whereField("userId", isEqualTo: user.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Error loading withdrawals: \(error.localizedDescription)"
                        
                        // Analytics: Track withdrawal loading error
                        Analytics.shared.trackError(
                            message: "Withdrawals loading failed: \(error.localizedDescription)"
                        )
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self?.withdrawals = documents.compactMap { doc in
                        Withdrawal(documentID: doc.documentID, data: doc.data())
                    }
                    
                    // Analytics: Track withdrawals loaded
                    if let withdrawals = self?.withdrawals {
                        Analytics.shared.track(
                            event: "withdrawals_loaded",
                            properties: [
                                "withdrawal_count": withdrawals.count,
                                "pending_count": withdrawals.filter { $0.status == .pending }.count,
                                "completed_count": withdrawals.filter { $0.status == .completed }.count,
                                "rejected_count": withdrawals.filter { $0.status == .rejected }.count
                            ]
                        )
                    }
                }
            }
    }
    
    // MARK: - Submit Withdrawal Request (Fixed - No Auto-Clear)
    func submitWithdrawal(amount: Double, bankAccount: BankAccount) async {
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                errorMessage = "User not authenticated"
                
                // Analytics: Track authentication error
                Analytics.shared.trackError(
                    message: "Withdrawal submission failed: User not authenticated"
                )
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            successMessage = ""
        }
        
        // Analytics: Track withdrawal submission attempt
        Analytics.shared.track(
            event: "withdrawal_submission_started",
            properties: [
                "amount": amount,
                "bank_name": bankAccount.bankName,
                "account_type": bankAccount.accountType
            ]
        )
        
        let db = Firestore.firestore()
        
        do {
            // Encrypt the bank account before storing
            let encryptedBankAccount = try bankAccount.encrypt()
            print("Bank account encrypted successfully")
            
            // Create withdrawal document with encrypted bank account
            let withdrawal = Withdrawal(
                id: "", // Will be set by Firestore
                userId: user.uid,
                amount: amount,
                status: .pending,
                encryptedBankAccount: encryptedBankAccount, // Now using encrypted data
                requestedAt: Date(),
                processedAt: nil,
                rejectionReason: nil,
                batchId: nil
            )
            
            // Add to Firestore
            try await db.collection("withdrawals").addDocument(data: withdrawal.toFirestoreData())
            print("Withdrawal saved to Firestore with encrypted bank details")
            
            // Update user's balance (deduct immediately)
            try await db.collection("affiliates").document(user.uid).updateData([
                "balance": FieldValue.increment(-amount)
            ])
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Withdrawal request submitted successfully!"
                
                // Analytics: Track successful withdrawal submission
                Analytics.shared.track(
                    event: "withdrawal_submitted_successfully",
                    properties: [
                        "amount": amount,
                        "bank_name": bankAccount.bankName,
                        "account_type": bankAccount.accountType
                    ]
                )
                
                // REMOVED: Auto-clearing success message - let the UI handle navigation timing
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                if error is EncryptionError {
                    self.errorMessage = "Security error: \(error.localizedDescription)"
                } else {
                    self.errorMessage = "Error submitting withdrawal: \(error.localizedDescription)"
                }
                
                // Analytics: Track withdrawal submission failure
                Analytics.shared.track(
                    event: "withdrawal_submission_failed",
                    properties: [
                        AnalyticsProperty.errorMessage: error.localizedDescription,
                        "amount": amount,
                        "error_type": error is EncryptionError ? "encryption" : "firestore"
                    ]
                )
            }
        }
    }
    
    // MARK: - Get pending withdrawal amount
    func pendingWithdrawalAmount() -> Double {
        let pendingAmount = withdrawals
            .filter { $0.status == .pending || $0.status == .approved }
            .reduce(0) { $0 + $1.amount }
        
        return pendingAmount
    }
    
    // MARK: - Validate bank account
    func validateBankAccount(_ bankAccount: BankAccount) -> String? {
        // Account holder name validation
        if bankAccount.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Analytics: Track validation failure
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "account_holder_name",
                    "error": "empty"
                ]
            )
            return "Account holder name is required"
        }
        
        // Bank name validation
        if bankAccount.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "bank_name",
                    "error": "empty"
                ]
            )
            return "Bank name is required"
        }
        
        // Account number validation (US format)
        let accountNumber = bankAccount.accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if accountNumber.isEmpty {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "account_number",
                    "error": "empty"
                ]
            )
            return "Account number is required"
        }
        
        if accountNumber.count < 8 || accountNumber.count > 17 {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "account_number",
                    "error": "invalid_length",
                    "length": accountNumber.count
                ]
            )
            return "Account number must be 8-17 digits"
        }
        
        if !accountNumber.allSatisfy({ $0.isNumber }) {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "account_number",
                    "error": "non_numeric"
                ]
            )
            return "Account number can only contain numbers"
        }
        
        // Routing number validation (US format)
        let routingNumber = bankAccount.routingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if routingNumber.isEmpty {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "routing_number",
                    "error": "empty"
                ]
            )
            return "Routing number is required"
        }
        
        if routingNumber.count != 9 {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "routing_number",
                    "error": "invalid_length",
                    "length": routingNumber.count
                ]
            )
            return "Routing number must be exactly 9 digits"
        }
        
        if !routingNumber.allSatisfy({ $0.isNumber }) {
            Analytics.shared.track(
                event: "bank_validation_failed",
                properties: [
                    "field": "routing_number",
                    "error": "non_numeric"
                ]
            )
            return "Routing number can only contain numbers"
        }
        
        // Analytics: Track successful validation
        Analytics.shared.track(
            event: "bank_validation_passed",
            properties: [
                "bank_name": bankAccount.bankName,
                "account_type": bankAccount.accountType
            ]
        )
        
        return nil // No validation errors
    }
    
    // MARK: - Helper to get decrypted bank account for display
    func getDecryptedBankAccount(for withdrawal: Withdrawal) -> BankAccount? {
        do {
            return try withdrawal.getBankAccount()
        } catch {
            print("Failed to decrypt bank account for withdrawal \(withdrawal.id): \(error)")
            
            // Analytics: Track decryption error
            Analytics.shared.trackError(
                message: "Bank account decryption failed: \(error.localizedDescription)",
                properties: [
                    "withdrawal_id": withdrawal.id
                ]
            )
            
            return nil
        }
    }
    
    // MARK: - Test Method (for development)
    func testEncryptionInViewModel() {
        print("Testing encryption in ViewModel...")
        
        let testBank = BankAccount(
            accountHolderName: "Test User",
            bankName: "Test Bank",
            accountNumber: "1234567890",
            routingNumber: "987654321",
            accountType: "checking",
            addressLine1: "123 Test St",
            city: "Test City",
            state: "NY",
            zipCode: "12345"
        )
        
        do {
            let encrypted = try testBank.encrypt()
            print("ViewModel encryption test successful")
            
            let decrypted = try BankAccount.decrypt(from: encrypted)
            print("ViewModel decryption test successful: \(decrypted.accountHolderName)")
            
            // Analytics: Track successful encryption test
            Analytics.shared.track(
                event: "encryption_test_successful"
            )
        } catch {
            print("ViewModel encryption test failed: \(error)")
            
            // Analytics: Track encryption test failure
            Analytics.shared.trackError(
                message: "Encryption test failed: \(error.localizedDescription)"
            )
        }
    }
}
