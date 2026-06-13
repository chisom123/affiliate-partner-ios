import Foundation
import Firebase
import Combine
import FirebaseAuth
import FirebaseStorage
import UIKit

class DashboardViewModel: ObservableObject {
    @Published var affiliateData: AffiliateData?
    @Published var ratingLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var isInitialDataLoad = true
    @Published var isUploadingPhoto = false
    @Published var isUploadingBonusPhoto = false
    @Published var errorMessage = ""

    private var linkListener: ListenerRegistration?
    private var affiliateListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private var hasReceivedInitialAffiliateData = false
    private let storage = Storage.storage()

    var totalEarnings: Double { ratingLinks.reduce(0) { $0 + $1.earnings } }
    var totalRatings: Int { ratingLinks.reduce(0) { $0 + $1.totalRatings } }

    deinit {
        linkListener?.remove()
        affiliateListener?.remove()
    }

    // MARK: - Load

    func loadData() {
        guard let user = Auth.auth().currentUser else { return }
        isInitialDataLoad = true
        hasReceivedInitialLinkData = false
        hasReceivedInitialAffiliateData = false
        setupAffiliateListener(userId: user.uid)
        setupRatingLinksListener(userId: user.uid)
    }

    private func checkInitialLoadComplete() {
        if hasReceivedInitialLinkData && hasReceivedInitialAffiliateData {
            isInitialDataLoad = false
        }
    }

    // MARK: - Listeners

    private func setupAffiliateListener(userId: String) {
        let db = Firestore.firestore()
        affiliateListener = db.collection("affiliates").document(userId)
            .addSnapshotListener { [weak self] document, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Analytics.shared.trackError(message: "Affiliate data listener error: \(error.localizedDescription)")
                        self?.hasReceivedInitialAffiliateData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    if let data = document?.data(), let ad = AffiliateData(data: data) {
                        self?.affiliateData = ad
                    }
                    self?.hasReceivedInitialAffiliateData = true
                    self?.checkInitialLoadComplete()
                }
            }
    }

    private func setupRatingLinksListener(userId: String) {
        let db = Firestore.firestore()
        linkListener = db.collection("rating_links")
            .whereField("affiliateId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Analytics.shared.trackError(message: "Rating links listener error: \(error.localizedDescription)")
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    var links = documents.compactMap { RatingLink(documentID: $0.documentID, data: $0.data()) }
                    self?.calculateAverageRatings(for: &links)
                    self?.ratingLinks = links
                    self?.hasReceivedInitialLinkData = true
                    self?.checkInitialLoadComplete()
                }
            }
    }

    // MARK: - Ratings

    private func calculateAverageRatings(for links: inout [RatingLink]) {
        let db = Firestore.firestore()
        for i in 0..<links.count {
            let link = links[i]
            db.collection("ratings")
                .whereField("linkIdString", isEqualTo: link.linkId)
                .getDocuments { [weak self] snapshot, _ in
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        DispatchQueue.main.async {
                            if let idx = self?.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                                self?.ratingLinks[idx].averageRating = 0.0
                                self?.ratingLinks[idx].ratingCount   = 0
                            }
                        }
                        return
                    }
                    let ratings = documents.compactMap { $0.data()["rating"] as? Double }
                    let average = ratings.reduce(0, +) / Double(ratings.count)
                    DispatchQueue.main.async {
                        if let idx = self?.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                            self?.ratingLinks[idx].averageRating = average
                            self?.ratingLinks[idx].ratingCount   = ratings.count
                        }
                    }
                }
        }
    }

    // MARK: - Story Photo Upload

    func uploadLinkPhoto(_ image: UIImage, for link: RatingLink, assetIdentifier: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else { return }

        isUploadingPhoto = true
        errorMessage = ""

        let photoRef = storage.reference().child("link_photos/\(userId)/\(link.linkId)_\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        photoRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    Analytics.shared.trackError(message: "Story photo upload failed: \(error.localizedDescription)")
                }
                return
            }
            photoRef.downloadURL { [weak self] url, error in
                DispatchQueue.main.async { self?.isUploadingPhoto = false }
                guard let urlString = url?.absoluteString else { return }
                self?.updateLinkPhotoUrl(urlString, for: link, assetIdentifier: assetIdentifier)
            }
        }
    }

    private func updateLinkPhotoUrl(_ url: String, for link: RatingLink, assetIdentifier: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        var updateData: [String: Any] = ["photoUrl": url]
        if let id = assetIdentifier { updateData["photoAssetIdentifier"] = id }

        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("affiliateId", isEqualTo: userId)
            .getDocuments { _, _ in } // listener will update UI automatically
        
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("affiliateId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                guard let document = snapshot?.documents.first else { return }
                document.reference.updateData(updateData) { error in
                    if let error = error {
                        Analytics.shared.trackError(message: "Story photo Firestore update failed: \(error.localizedDescription)")
                    } else {
                        Analytics.shared.track(event: "link_story_photo_updated", properties: ["link_id": link.linkId])
                    }
                }
            }
    }

    // MARK: - Bonus Photo Upload

    func uploadBonusPhoto(_ image: UIImage, for link: RatingLink, identifier: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else {
            completion(false)
            return
        }

        isUploadingBonusPhoto = true

        let ref = storage.reference().child("unseen_photos/\(userId)_\(link.id)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(imageData, metadata: metadata) { [weak self] _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isUploadingBonusPhoto = false
                    Analytics.shared.trackError(message: "Bonus photo upload failed: \(error.localizedDescription)")
                    completion(false)
                }
                return
            }
            ref.downloadURL { [weak self] url, error in
                guard let urlString = url?.absoluteString else {
                    DispatchQueue.main.async {
                        self?.isUploadingBonusPhoto = false
                        completion(false)
                    }
                    return
                }
                Firestore.firestore().collection("rating_links").document(link.id)
                    .updateData(["bonusPhotoUrl": urlString]) { error in
                        DispatchQueue.main.async {
                            self?.isUploadingBonusPhoto = false
                            if let error = error {
                                Analytics.shared.trackError(message: "Bonus photo Firestore update failed: \(error.localizedDescription)")
                                completion(false)
                            } else {
                                Analytics.shared.track(event: "link_bonus_photo_updated", properties: ["link_id": link.linkId])
                                completion(true)
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Title

    func updateLinkTitle(link: RatingLink, newTitle: String) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("affiliateId", isEqualTo: user.uid)
            .getDocuments { snapshot, _ in
                snapshot?.documents.first?.reference.updateData(["title": newTitle])
            }
    }

    // MARK: - Daily Limit

    func checkDailyLimit(completion: @escaping (Bool, Int) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { completion(true, 1); return }
        let db = Firestore.firestore()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        db.collection("rating_links")
            .whereField("affiliateId", isEqualTo: userId)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("createdAt", isLessThan: Timestamp(date: endOfDay))
            .getDocuments { snapshot, _ in
                let count = snapshot?.documents.count ?? 0
                completion(count < 1, max(0, 1 - count))
            }
    }

    // MARK: - Create Link

    func createNewLink(completion: @escaping (RatingLink?) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(nil); return }
        guard let affiliateData = affiliateData, affiliateData.canCreateLinks else { completion(nil); return }

        checkDailyLimit { [weak self] canCreate, _ in
            guard canCreate else { completion(nil); return }
            self?.performLinkCreation(userId: user.uid, completion: completion)
        }
    }

    private func performLinkCreation(userId: String, completion: @escaping (RatingLink?) -> Void) {
        isLoading = true
        let db     = Firestore.firestore()
        let linkId = "\(userId)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let title  = "Rating Link #\(ratingLinks.count + 1)"

        let linkData: [String: Any] = [
            "affiliateId":  userId,
            "linkId":       linkId,
            "title":        title,
            "description":  "",
            "url":          "rate.socialstarapp.com/rate/\(userId)/\(linkId)",
            "createdAt":    Timestamp(),
            "expiresAt":    Timestamp(date: Date().addingTimeInterval(48 * 60 * 60)),
            "totalRatings": 0,
            "earnings":     0.0,
            "status":       "active"
        ]

        let linkRef = db.collection("rating_links").document()
        linkRef.setData(linkData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if error == nil, let link = RatingLink(documentID: linkRef.documentID, data: linkData) {
                    completion(link)
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }
}

// MARK: - UIImage Optimisation

extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.6) -> Data? {
        resizeIfNeeded(maxDimension: maxDimension).compressedData(compressionQuality: compressionQuality)
    }

    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > maxDimension || h > maxDimension else { return self }
        let scale   = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }

    private func compressedData(compressionQuality: CGFloat) -> Data? {
        var quality = compressionQuality
        var data    = jpegData(compressionQuality: quality)
        let target  = 500 * 1024
        while let d = data, d.count > target, quality > 0.1 {
            quality -= 0.1
            data = jpegData(compressionQuality: quality)
        }
        return data
    }
}
