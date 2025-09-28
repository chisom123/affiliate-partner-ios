import Foundation
import Firebase

struct RatingLink: Identifiable {
    let id: String
    let linkId: String
    let title: String
    let url: String
    let totalRatings: Int
    let earnings: Double
    let createdAt: Date
    let expiresAt: Date
    let status: String
    var averageRating: Double
    var ratingCount: Int
    
    var isActive: Bool {
        expiresAt > Date() && status == "active"
    }
    
    var hasRatings: Bool {
        ratingCount > 0
    }
}

// MARK: - Firestore Conversion
extension RatingLink {
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        self.linkId = data["linkId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.url = data["url"] as? String ?? ""
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.earnings = data["earnings"] as? Double ?? 0.0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
        self.status = data["status"] as? String ?? "active"
        self.averageRating = 0.0 // Will be calculated separately
        self.ratingCount = 0 // Will be calculated separately
    }
}

struct AffiliateData {
    let firstName: String
    let lastName: String
    let email: String
    let totalEarnings: Double
    let totalRatings: Int
    let createdAt: Date
    let status: String
    let balance: Double // Available for withdrawal
    let totalWithdrawn: Double // Total amount withdrawn (lifetime)
}

// MARK: - Firestore Conversion
extension AffiliateData {
    init?(data: [String: Any]) {
        guard let firstName = data["firstName"] as? String,
              let lastName = data["lastName"] as? String,
              let email = data["email"] as? String else {
            return nil
        }
        
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.totalEarnings = data["totalEarnings"] as? Double ?? 0.0
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.status = data["status"] as? String ?? "active"
        self.balance = data["balance"] as? Double ?? 0.0
        self.totalWithdrawn = data["totalWithdrawn"] as? Double ?? 0.0
    }
    
    var canWithdraw: Bool {
        balance >= 10
    }
    
    var lifetimeEarnings: Double {
        balance + totalWithdrawn
    }
}
