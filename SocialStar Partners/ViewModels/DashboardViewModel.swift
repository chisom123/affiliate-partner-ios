// DashboardViewModel.swift — updated for pay-per-view + scoreAffiliatePhoto, no themes

import Foundation
import Firebase
import Combine
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
import UIKit

class DashboardViewModel: ObservableObject {
    @Published var affiliateData: AffiliateData?
    @Published var ratingLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var isInitialDataLoad = true
    @Published var isUploadingPhoto = false
    @Published var errorMessage = ""

    private var linkListener: ListenerRegistration?
    private var affiliateListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private var hasReceivedInitialAffiliateData = false
    private let storage = Storage.storage()

    private lazy var marketingFunctions = Functions.functions()

    deinit { linkListener?.remove(); affiliateListener?.remove() }

    func loadData() {
        guard let user = Auth.auth().currentUser else { return }
        isInitialDataLoad = true
        hasReceivedInitialLinkData = false
        hasReceivedInitialAffiliateData = false
        setupAffiliateListener(userId: user.uid)
        setupRatingLinksListener(userId: user.uid)
    }

    private func checkInitialLoadComplete() {
        if hasReceivedInitialLinkData && hasReceivedInitialAffiliateData { isInitialDataLoad = false }
    }

    private func setupAffiliateListener(userId: String) {
        let db = Firestore.firestore()
        affiliateListener = db.collection("affiliates").document(userId)
            .addSnapshotListener { [weak self] document, _ in
                DispatchQueue.main.async {
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
            .addSnapshotListener { [weak self] snapshot, _ in
                DispatchQueue.main.async {
                    let links = (snapshot?.documents ?? []).compactMap { doc in
                        RatingLink(documentID: doc.documentID, data: doc.data())
                    }
                    self?.ratingLinks = links
                    self?.hasReceivedInitialLinkData = true
                    self?.checkInitialLoadComplete()
                }
            }
    }

    // MARK: - scoreAffiliatePhoto
    // Called after photo is uploaded. No theme needed.

    func scoreAffiliatePhoto(link: RatingLink) {
        guard let photoUrl = link.photoUrl else {
            print("scoreAffiliatePhoto: missing photoUrl")
            return
        }
        if link.aiScore != nil && !link.aiScoring { return }

        print("scoreAffiliatePhoto: calling Cloud Function for link \(link.id)")

        marketingFunctions.httpsCallable("scoreAffiliatePhoto").call([
            "linkDocId": link.id,
            "photoUrl":  photoUrl
        ]) { result, error in
            if let error = error {
                print("scoreAffiliatePhoto error: \(error.localizedDescription)")
            } else {
                print("scoreAffiliatePhoto: success — Firestore listener will update UI")
            }
        }
    }

    // MARK: - Photo upload
    // Triggers AI scoring immediately after upload completes — no theme needed

    func uploadLinkPhoto(_ image: UIImage, for link: RatingLink, assetIdentifier: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else { return }

        isUploadingPhoto = true

        let photoRef = storage.reference().child("link_photos/\(userId)/\(link.linkId)_\(UUID().uuidString).jpg")
        let metadata = StorageMetadata(); metadata.contentType = "image/jpeg"

        photoRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            if error != nil { DispatchQueue.main.async { self?.isUploadingPhoto = false }; return }

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
            .getDocuments { [weak self] snapshot, _ in
                guard let document = snapshot?.documents.first else { return }
                document.reference.updateData(updateData) { _ in
                    // Trigger AI scoring immediately after photo is saved
                    DispatchQueue.main.async {
                        if let updated = self?.ratingLinks.first(where: { $0.id == document.documentID }) {
                            self?.scoreAffiliatePhoto(link: updated)
                        }
                    }
                }
            }
    }

    // MARK: - Title update
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

    // MARK: - Daily limit check
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

    // MARK: - Create new link
    func createNewLink(completion: @escaping (RatingLink?) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(nil); return }
        guard let affiliateData = affiliateData, affiliateData.canCreateLinks else { completion(nil); return }

        checkDailyLimit(userId: user.uid) { [weak self] canCreate, _ in
            guard canCreate else { completion(nil); return }
            self?.performLinkCreation(userId: user.uid, completion: completion)
        }
    }

    private func checkDailyLimit(userId: String, completion: @escaping (Bool, Int) -> Void) {
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

    private func performLinkCreation(userId: String, completion: @escaping (RatingLink?) -> Void) {
        isLoading = true
        let db     = Firestore.firestore()
        let linkId = "\(userId)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let title  = "Photo Link #\(ratingLinks.count + 1)"

        let linkData: [String: Any] = [
            "affiliateId":    userId,
            "linkId":         linkId,
            "title":          title,
            "url":            "photo.socialstarapp.com/photo/\(userId)/\(linkId)",
            "createdAt":      Timestamp(),
            "expiresAt":      Timestamp(date: Date().addingTimeInterval(48 * 60 * 60)),
            "totalPageViews": 0,
            "earnings":       0.0,
            "status":         "active"
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

    func signOut() {
        try? Auth.auth().signOut()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }
}

// MARK: - UIImage optimisation
extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.6) -> Data? {
        resizeIfNeeded(maxDimension: maxDimension).compressedData(compressionQuality: compressionQuality)
    }
    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > maxDimension || h > maxDimension else { return self }
        let scale = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
    private func compressedData(compressionQuality: CGFloat) -> Data? {
        var quality = compressionQuality
        var data = jpegData(compressionQuality: quality)
        let target = 500 * 1024
        while let d = data, d.count > target, quality > 0.1 { quality -= 0.1; data = jpegData(compressionQuality: quality) }
        return data
    }
}
