import Foundation
import Firebase

struct Withdrawal: Identifiable {
    let id: String
    let userId: String
    let amount: Double
    let status: WithdrawalStatus
    let requestedAt: Date
    let processedAt: Date?
    let rejectionReason: String?
    let batchId: String?
    
    // PayPal specific fields
    let paypalEmail: String
    let paymentMethod: String
    
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
    
    // Display helper for PayPal info
    var paymentInfo: String {
        return "\(paypalEmail)"
    }
    
    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: requestedAt)
    }
}

enum WithdrawalStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case completed = "completed"
    case rejected = "rejected"
}

// MARK: - Firestore Conversion
extension Withdrawal {
    init?(documentID: String, data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              let amount = data["amount"] as? Double,
              let statusString = data["status"] as? String,
              let status = WithdrawalStatus(rawValue: statusString),
              let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue(),
              let paypalEmail = data["paypalEmail"] as? String else {
            print("❌ Missing required fields for PayPal withdrawal: \(documentID)")
            return nil
        }
        
        self.id = documentID
        self.userId = userId
        self.amount = amount
        self.status = status
        self.requestedAt = requestedAt
        self.paypalEmail = paypalEmail
        self.paymentMethod = data["paymentMethod"] as? String ?? "paypal"
        self.processedAt = (data["processedAt"] as? Timestamp)?.dateValue()
        self.rejectionReason = data["rejectionReason"] as? String
        self.batchId = data["batchId"] as? String
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "amount": amount,
            "status": status.rawValue,
            "requestedAt": Timestamp(date: requestedAt),
            "paypalEmail": paypalEmail,
            "paymentMethod": paymentMethod
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
