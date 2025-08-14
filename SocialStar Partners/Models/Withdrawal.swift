import Foundation
import Firebase

struct Withdrawal: Identifiable {
    let id: String
    let userId: String
    let amount: Double
    let status: WithdrawalStatus
    let bankAccount: BankAccount
    let requestedAt: Date
    let processedAt: Date?
    let rejectionReason: String?
    let batchId: String?
    
    var statusDescription: String {
        switch status {
        case .pending:
            return "Pending Review"
        case .approved:
            return "Approved - Processing Soon"
        case .completed:
            return "Completed"
        case .rejected:
            return "Rejected"
        }
    }
    
    var isCompleted: Bool {
        status == .completed || status == .rejected
    }
}

enum WithdrawalStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case completed = "completed"
    case rejected = "rejected"
}

struct BankAccount: Codable {
    let accountHolderName: String
    let bankName: String
    let accountNumber: String
    let routingNumber: String
    
    // Helper properties for display
    var maskedAccountNumber: String {
        let suffix = String(accountNumber.suffix(4))
        return "****\(suffix)"
    }
    
    var displayName: String {
        return "\(maskedAccountNumber) at \(bankName)"
    }
}

// MARK: - Firestore Conversion
extension Withdrawal {
    init?(documentID: String, data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              let amount = data["amount"] as? Double,
              let statusString = data["status"] as? String,
              let status = WithdrawalStatus(rawValue: statusString),
              let bankAccountData = data["bankAccount"] as? [String: Any],
              let bankAccount = BankAccount(data: bankAccountData),
              let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = documentID
        self.userId = userId
        self.amount = amount
        self.status = status
        self.bankAccount = bankAccount
        self.requestedAt = requestedAt
        self.processedAt = (data["processedAt"] as? Timestamp)?.dateValue()
        self.rejectionReason = data["rejectionReason"] as? String
        self.batchId = data["batchId"] as? String
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "amount": amount,
            "status": status.rawValue,
            "bankAccount": bankAccount.toFirestoreData(),
            "requestedAt": Timestamp(date: requestedAt)
        ]
        
        if let processedAt = processedAt {
            data["processedAt"] = Timestamp(date: processedAt)
        }
        
        if let rejectionReason = rejectionReason {
            data["rejectionReason"] = rejectionReason
        }
        
        if let batchId = batchId {
            data["batchId"] = batchId
        }
        
        return data
    }
}

extension BankAccount {
    init?(data: [String: Any]) {
        guard let accountHolderName = data["accountHolderName"] as? String,
              let bankName = data["bankName"] as? String,
              let accountNumber = data["accountNumber"] as? String,
              let routingNumber = data["routingNumber"] as? String else {
            return nil
        }
        
        self.accountHolderName = accountHolderName
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.routingNumber = routingNumber
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "accountHolderName": accountHolderName,
            "bankName": bankName,
            "accountNumber": accountNumber,
            "routingNumber": routingNumber
        ]
    }
}
