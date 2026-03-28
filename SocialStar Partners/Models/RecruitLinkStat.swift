import Foundation
import Firebase

struct RecruitLinkStat: Identifiable {
    let id: String
    let linkId: String
    let affiliateId: String
    let title: String
    let photoUrl: String?
    let theme: String?
    let linkUrl: String
    let totalRatings: Int
    let storiesCompleted: Int
    let earnings: Double
    let linkCreatedAt: Date
    let createdAt: Date
    let lastRatingAt: Date
    let completedAt: Date?
    
    var hasCompleted: Bool {
        completedAt != nil
    }
    
    var progressToNextPayout: Double {
        Double(totalRatings % 10) / 10.0
    }
    
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        self.linkId = data["linkId"] as? String ?? ""
        self.affiliateId = data["affiliateId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.photoUrl = data["photoUrl"] as? String
        self.theme = data["theme"] as? String
        self.linkUrl = data["linkUrl"] as? String ?? ""
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.storiesCompleted = data["storiesCompleted"] as? Int ?? 0
        self.earnings = data["earnings"] as? Double ?? 0.0
        self.linkCreatedAt = (data["linkCreatedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.lastRatingAt = (data["lastRatingAt"] as? Timestamp)?.dateValue() ?? Date()
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
    }
}
