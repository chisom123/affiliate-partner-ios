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
    let accountType: String        // "checking" or "savings"
    let addressLine1: String
    let city: String
    let state: String        // 2-letter state code (AL, CA, TX, etc.)
    let zipCode: String
    
    // Helper properties for display
    var maskedAccountNumber: String {
        let suffix = String(accountNumber.suffix(4))
        return "****\(suffix)"
    }
    
    var displayName: String {
        return "\(maskedAccountNumber) at \(bankName)"
    }
    
    var fullAddress: String {
        return "\(addressLine1), \(city), \(state) \(zipCode)"
    }
}

// MARK: - US States for Picker
struct USState {
    let name: String
    let code: String
    
    static let allStates = [
        USState(name: "Alabama", code: "AL"),
        USState(name: "Alaska", code: "AK"),
        USState(name: "Arizona", code: "AZ"),
        USState(name: "Arkansas", code: "AR"),
        USState(name: "California", code: "CA"),
        USState(name: "Colorado", code: "CO"),
        USState(name: "Connecticut", code: "CT"),
        USState(name: "Delaware", code: "DE"),
        USState(name: "Florida", code: "FL"),
        USState(name: "Georgia", code: "GA"),
        USState(name: "Hawaii", code: "HI"),
        USState(name: "Idaho", code: "ID"),
        USState(name: "Illinois", code: "IL"),
        USState(name: "Indiana", code: "IN"),
        USState(name: "Iowa", code: "IA"),
        USState(name: "Kansas", code: "KS"),
        USState(name: "Kentucky", code: "KY"),
        USState(name: "Louisiana", code: "LA"),
        USState(name: "Maine", code: "ME"),
        USState(name: "Maryland", code: "MD"),
        USState(name: "Massachusetts", code: "MA"),
        USState(name: "Michigan", code: "MI"),
        USState(name: "Minnesota", code: "MN"),
        USState(name: "Mississippi", code: "MS"),
        USState(name: "Missouri", code: "MO"),
        USState(name: "Montana", code: "MT"),
        USState(name: "Nebraska", code: "NE"),
        USState(name: "Nevada", code: "NV"),
        USState(name: "New Hampshire", code: "NH"),
        USState(name: "New Jersey", code: "NJ"),
        USState(name: "New Mexico", code: "NM"),
        USState(name: "New York", code: "NY"),
        USState(name: "North Carolina", code: "NC"),
        USState(name: "North Dakota", code: "ND"),
        USState(name: "Ohio", code: "OH"),
        USState(name: "Oklahoma", code: "OK"),
        USState(name: "Oregon", code: "OR"),
        USState(name: "Pennsylvania", code: "PA"),
        USState(name: "Rhode Island", code: "RI"),
        USState(name: "South Carolina", code: "SC"),
        USState(name: "South Dakota", code: "SD"),
        USState(name: "Tennessee", code: "TN"),
        USState(name: "Texas", code: "TX"),
        USState(name: "Utah", code: "UT"),
        USState(name: "Vermont", code: "VT"),
        USState(name: "Virginia", code: "VA"),
        USState(name: "Washington", code: "WA"),
        USState(name: "West Virginia", code: "WV"),
        USState(name: "Wisconsin", code: "WI"),
        USState(name: "Wyoming", code: "WY")
    ]
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
              let routingNumber = data["routingNumber"] as? String,
              let accountType = data["accountType"] as? String,
              let addressLine1 = data["addressLine1"] as? String,
              let city = data["city"] as? String,
              let state = data["state"] as? String,
              let zipCode = data["zipCode"] as? String else {
            return nil
        }
        
        self.accountHolderName = accountHolderName
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.routingNumber = routingNumber
        self.accountType = accountType
        self.addressLine1 = addressLine1
        self.city = city
        self.state = state
        self.zipCode = zipCode
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "accountHolderName": accountHolderName,
            "bankName": bankName,
            "accountNumber": accountNumber,
            "routingNumber": routingNumber,
            "accountType": accountType,
            "addressLine1": addressLine1,
            "city": city,
            "state": state,
            "zipCode": zipCode
        ]
    }
}
