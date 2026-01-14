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
    
    // MARK: - Submit PayPal Withdrawal Request
    func submitPayPalWithdrawal(amount: Double, paypalEmail: String) async {
        guard let user = Auth.auth().currentUser else {
            await MainActor.run {
                errorMessage = "User not authenticated"
                
                // Analytics: Track authentication error
                Analytics.shared.trackError(
                    message: "PayPal withdrawal submission failed: User not authenticated"
                )
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            successMessage = ""
        }
        
        // Validate PayPal email
        if !isValidEmail(paypalEmail) {
            await MainActor.run {
                isLoading = false
                errorMessage = "Please enter a valid PayPal email address"
                
                Analytics.shared.track(
                    event: "paypal_withdrawal_validation_failed",
                    properties: [
                        "error": "invalid_email"
                    ]
                )
            }
            return
        }
        
        // Validate minimum amount
        if amount < 5.0 {
            await MainActor.run {
                isLoading = false
                errorMessage = "Minimum withdrawal amount is $5.00"
                
                Analytics.shared.track(
                    event: "paypal_withdrawal_validation_failed",
                    properties: [
                        "error": "minimum_amount",
                        "amount": amount
                    ]
                )
            }
            return
        }
        
        // Analytics: Track PayPal withdrawal submission attempt
        Analytics.shared.track(
            event: "paypal_withdrawal_submission_started",
            properties: [
                "amount": amount,
                "has_email": !paypalEmail.isEmpty
            ]
        )
        
        let db = Firestore.firestore()
        
        do {
            // Create withdrawal document with PayPal details
            // Only include required fields - don't include nil optional fields
            var withdrawalData: [String: Any] = [
                "userId": user.uid,
                "amount": amount,
                "status": "pending",
                "paymentMethod": "paypal",
                "paypalEmail": paypalEmail,
                "requestedAt": Timestamp(date: Date())
            ]
            
            // Add to Firestore
            try await db.collection("withdrawals").addDocument(data: withdrawalData)
            print("PayPal withdrawal saved to Firestore")
            
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
                        "amount": amount
                    ]
                )
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Error submitting PayPal withdrawal: \(error.localizedDescription)"
                
                // Analytics: Track PayPal withdrawal submission failure
                Analytics.shared.track(
                    event: "paypal_withdrawal_submission_failed",
                    properties: [
                        AnalyticsProperty.errorMessage: error.localizedDescription,
                        "amount": amount
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
    
    // MARK: - Validate PayPal Email
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Get Withdrawal Details for Display (Simplified)
    func getWithdrawalDetails(for withdrawal: Withdrawal) -> (method: String, details: String) {
        // paypalEmail is not optional in the updated model, so no need for optional binding
        return ("PayPal", "Email: \(withdrawal.paypalEmail)")
    }
}
