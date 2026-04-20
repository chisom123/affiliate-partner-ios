import Foundation
import Firebase

struct RecruitLinkStat: Identifiable {
    let id: String
    let linkId: String
    let title: String
    let photoUrl: String?
    let theme: String?
    let totalRatings: Int
    let lastRatingAt: Date
    
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        self.linkId = data["linkId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.photoUrl = data["photoUrl"] as? String
        self.theme = data["theme"] as? String
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.lastRatingAt = (data["lastRatingAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}
