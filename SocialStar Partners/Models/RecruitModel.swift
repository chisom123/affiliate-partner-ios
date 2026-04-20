import SwiftUI
import Firebase

struct Recruit: Identifiable {
    let id: String
    var firstName: String
    var lastName: String
    var email: String
    let joinedAt: Date
    let totalRatings: Int           // Lifetime ratings (new)
    let hasEarnedBonus: Bool        // Did recruiter get $10 yet? (new)
    let bonusPaidAt: Date?          // When bonus was paid (new)
    let lastRatingAt: Date?
    var profilePictureUrl: String?
    
    var displayName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "Unknown Recruit"
        }
        return "\(firstName) \(lastName)"
    }
    
    var isActive: Bool {
        guard let lastRatingAt = lastRatingAt else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return lastRatingAt > sevenDaysAgo
    }
    
    var progressToBonus: Double {
        Double(min(totalRatings, 10)) / 10.0
    }
    
    var ratingsNeededForBonus: Int {
        max(0, 10 - totalRatings)
    }
    
    var bonusEarned: Double {
        hasEarnedBonus ? 10.00 : 0.00
    }
    
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        self.firstName = ""
        self.lastName = ""
        self.email = ""
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.hasEarnedBonus = data["hasEarnedRecruitmentBonus"] as? Bool ?? false
        
        if let joinedTimestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = joinedTimestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }
        
        if let bonusPaidTimestamp = data["bonusPaidAt"] as? Timestamp {
            self.bonusPaidAt = bonusPaidTimestamp.dateValue()
        } else {
            self.bonusPaidAt = nil
        }
        
        if let lastRatingTimestamp = data["lastRatingAt"] as? Timestamp {
            self.lastRatingAt = lastRatingTimestamp.dateValue()
        } else {
            self.lastRatingAt = nil
        }
        
        self.profilePictureUrl = nil
    }
}
