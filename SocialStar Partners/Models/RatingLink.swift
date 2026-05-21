// Models.swift — updated for pay-per-view, AI scoring, no themes

import Foundation
import Firebase

struct RatingLink: Identifiable {
    let id: String
    let linkId: String
    let title: String
    let url: String
    let totalPageViews: Int
    let earnings: Double
    let createdAt: Date
    let expiresAt: Date
    let status: String
    var photoUrl: String?
    var photoAssetIdentifier: String?

    // AI scoring fields — written by scoreAffiliatePhoto Cloud Function
    var aiScore: Double?
    var aiReason: String?
    var aiScoring: Bool

    var isActive: Bool {
        expiresAt > Date() && status == "active"
    }

    // Copy link is gated on AI score existing
    var isReadyToShare: Bool {
        aiScore != nil && !aiScoring
    }
}

extension RatingLink {
    init?(documentID: String, data: [String: Any]) {
        self.id             = documentID
        self.linkId         = data["linkId"]  as? String ?? ""
        self.title          = data["title"]   as? String ?? ""
        self.url            = data["url"]     as? String ?? ""
        self.totalPageViews = data["totalPageViews"] as? Int ?? 0
        self.earnings       = data["earnings"] as? Double ?? 0.0
        self.createdAt      = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.expiresAt      = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
        self.status         = data["status"]  as? String ?? "active"
        self.photoUrl       = data["photoUrl"] as? String
        self.photoAssetIdentifier = data["photoAssetIdentifier"] as? String
        self.aiScore        = data["aiScore"]  as? Double
        self.aiReason       = data["aiReason"] as? String
        self.aiScoring      = data["aiScoring"] as? Bool ?? false
    }
}

struct AffiliateData {
    let firstName: String
    let lastName: String
    let email: String
    let totalEarnings: Double
    let totalPageViews: Int
    let createdAt: Date
    let status: String
    let balance: Double
    let totalWithdrawn: Double
    let profilePictureUrl: String?
    let canCreateLinks: Bool

    var canWithdraw: Bool { balance >= 5 }
    var lifetimeEarnings: Double { balance + totalWithdrawn }
}

extension AffiliateData {
    init?(data: [String: Any]) {
        guard
            let firstName = data["firstName"] as? String,
            let lastName  = data["lastName"]  as? String,
            let email     = data["email"]     as? String
        else { return nil }

        self.firstName         = firstName
        self.lastName          = lastName
        self.email             = email
        self.totalEarnings     = data["totalEarnings"]  as? Double ?? 0.0
        self.totalPageViews    = data["totalPageViews"] as? Int    ?? 0
        self.createdAt         = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.status            = data["status"]         as? String ?? "active"
        self.balance           = data["balance"]        as? Double ?? 0.0
        self.totalWithdrawn    = data["totalWithdrawn"] as? Double ?? 0.0
        self.profilePictureUrl = data["profilePictureUrl"] as? String
        self.canCreateLinks    = data["canCreateLinks"] as? Bool ?? true
    }
}
