import SwiftUI
import Firebase

struct Recruit: Identifiable {
    let id: String // User ID
    var firstName: String
    var lastName: String
    var email: String
    let joinedAt: Date
    let recruiterEarnings: Double
    let totalRatings: Int
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
    
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        
        // These will be populated from the main affiliates collection
        self.firstName = ""
        self.lastName = ""
        self.email = ""
        
        // Stats from recruits subcollection
        self.recruiterEarnings = data["recruiterEarnings"] as? Double ?? 0.0
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        
        if let joinedTimestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = joinedTimestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }
        
        if let lastRatingTimestamp = data["lastRatingAt"] as? Timestamp {
            self.lastRatingAt = lastRatingTimestamp.dateValue()
        } else {
            self.lastRatingAt = nil
        }
        
        self.profilePictureUrl = nil
    }
}
