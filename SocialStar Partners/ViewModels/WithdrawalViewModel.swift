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
        
        let db = Firestore.firestore()
        
        // Real-time listener for user's withdrawals
        withdrawalsListener = db.collection("withdrawals")
            .whereField("userId", isEqualTo: user.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Error loading withdrawals: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self?.withdrawals = documents.compactMap { doc in
                        Withdrawal(documentID: doc.documentID, data: doc.data())
                    }
                }
            }
    }
    
    // MARK: - Submit Withdrawal Request (Updated with Encryption)
    func submitWithdrawal(amount: Double, bankAccount: BankAccount) async {
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                errorMessage = "User not authenticated"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            successMessage = ""
        }
        
        let db = Firestore.firestore()
        
        do {
            // Encrypt the bank account before storing
            let encryptedBankAccount = try bankAccount.encrypt()
            print("🔐 Bank account encrypted successfully")
            
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
            print("✅ Withdrawal saved to Firestore with encrypted bank details")
            
            // Update user's balance (deduct immediately)
            try await db.collection("affiliates").document(user.uid).updateData([
                "balance": FieldValue.increment(-amount)
            ])
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Withdrawal request submitted successfully!"
                
                // Clear success message after 3 seconds
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self.successMessage = ""
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                if error is EncryptionError {
                    self.errorMessage = "Security error: \(error.localizedDescription)"
                } else {
                    self.errorMessage = "Error submitting withdrawal: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Check if user can withdraw today
    func canWithdrawToday() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if user already has a withdrawal today
        let todayWithdrawals = withdrawals.filter { withdrawal in
            let withdrawalDate = Calendar.current.startOfDay(for: withdrawal.requestedAt)
            return withdrawalDate == today
        }
        
        return todayWithdrawals.isEmpty
    }
    
    // MARK: - Get pending withdrawal amount
    func pendingWithdrawalAmount() -> Double {
        return withdrawals
            .filter { $0.status == .pending || $0.status == .approved }
            .reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Validate bank account
    func validateBankAccount(_ bankAccount: BankAccount) -> String? {
        // Account holder name validation
        if bankAccount.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Account holder name is required"
        }
        
        // Bank name validation
        if bankAccount.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Bank name is required"
        }
        
        // Account number validation (US format)
        let accountNumber = bankAccount.accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if accountNumber.isEmpty {
            return "Account number is required"
        }
        
        if accountNumber.count < 8 || accountNumber.count > 17 {
            return "Account number must be 8-17 digits"
        }
        
        if !accountNumber.allSatisfy({ $0.isNumber }) {
            return "Account number can only contain numbers"
        }
        
        // Routing number validation (US format)
        let routingNumber = bankAccount.routingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if routingNumber.isEmpty {
            return "Routing number is required"
        }
        
        if routingNumber.count != 9 {
            return "Routing number must be exactly 9 digits"
        }
        
        if !routingNumber.allSatisfy({ $0.isNumber }) {
            return "Routing number can only contain numbers"
        }
        
        return nil // No validation errors
    }
    
    // MARK: - Helper to get decrypted bank account for display
    func getDecryptedBankAccount(for withdrawal: Withdrawal) -> BankAccount? {
        do {
            return try withdrawal.getBankAccount()
        } catch {
            print("⚠️ Failed to decrypt bank account for withdrawal \(withdrawal.id): \(error)")
            return nil
        }
    }
    
    // MARK: - Test Method (for development)
    func testEncryptionInViewModel() {
        print("🧪 Testing encryption in ViewModel...")
        
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
            print("✅ ViewModel encryption test successful")
            
            let decrypted = try BankAccount.decrypt(from: encrypted)
            print("✅ ViewModel decryption test successful: \(decrypted.accountHolderName)")
        } catch {
            print("❌ ViewModel encryption test failed: \(error)")
        }
    }
}
