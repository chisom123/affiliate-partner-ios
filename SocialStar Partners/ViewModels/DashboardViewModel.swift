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
    @Published var isUploadingPhoto = false // NEW: Photo upload state
    @Published var errorMessage = ""
    
    private var linkListener: ListenerRegistration?
    private var affiliateListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private var hasReceivedInitialAffiliateData = false
    private let storage = Storage.storage() // NEW: Firebase Storage reference
    
    var totalEarnings: Double {
        ratingLinks.reduce(0) { $0 + $1.earnings }
    }
    
    var totalRatings: Int {
        ratingLinks.reduce(0) { $0 + $1.totalRatings }
    }
    
    deinit {
        linkListener?.remove()
        affiliateListener?.remove()
    }
    
    func loadData() {
        guard let user = Auth.auth().currentUser else { return }
        
        isInitialDataLoad = true
        hasReceivedInitialLinkData = false
        hasReceivedInitialAffiliateData = false
        
        Analytics.shared.track(
            event: "dashboard_data_load_started",
            properties: [
                "user_id": user.uid
            ]
        )
        
        setupAffiliateListener(userId: user.uid)
        setupRatingLinksListener(userId: user.uid)
    }
    
    private func checkInitialLoadComplete() {
        if hasReceivedInitialLinkData && hasReceivedInitialAffiliateData {
            isInitialDataLoad = false
        }
    }
    
    private func setupAffiliateListener(userId: String) {
        let db = Firestore.firestore()
        
        affiliateListener = db.collection("affiliates").document(userId)
            .addSnapshotListener { [weak self] document, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Analytics.shared.trackError(
                            message: "Affiliate data listener error: \(error.localizedDescription)"
                        )
                        
                        self?.hasReceivedInitialAffiliateData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    
                    if let document = document,
                       document.exists,
                       let data = document.data(),
                       let affiliateData = AffiliateData(data: data) {
                        self?.affiliateData = affiliateData
                        
                        Analytics.shared.track(
                            event: "affiliate_data_loaded",
                            properties: [
                                "balance": affiliateData.balance,
                                "total_earnings": affiliateData.totalEarnings,
                                "total_withdrawn": affiliateData.totalWithdrawn
                            ]
                        )
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
                        Analytics.shared.trackError(
                            message: "Rating links listener error: \(error.localizedDescription)"
                        )
                        
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    
                    var links = documents.compactMap { doc in
                        RatingLink(documentID: doc.documentID, data: doc.data())
                    }
                    
                    self?.calculateAverageRatings(for: &links)
                    
                    self?.ratingLinks = links
                    
                    Analytics.shared.track(
                        event: "rating_links_loaded",
                        properties: [
                            "link_count": links.count,
                            "active_links": links.filter { $0.isActive }.count,
                            "links_with_photos": links.filter { $0.photoUrl != nil }.count
                        ]
                    )
                    
                    self?.hasReceivedInitialLinkData = true
                    self?.checkInitialLoadComplete()
                }
            }
    }
    
    private func calculateAverageRatings(for links: inout [RatingLink]) {
        let db = Firestore.firestore()
        
        for i in 0..<links.count {
            let link = links[i]
            
            db.collection("ratings")
                .whereField("linkIdString", isEqualTo: link.linkId)
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        DispatchQueue.main.async {
                            if let index = self.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                                self.ratingLinks[index].averageRating = 0.0
                                self.ratingLinks[index].ratingCount = 0
                            }
                        }
                        return
                    }
                    
                    let ratings = documents.compactMap { doc in
                        doc.data()["rating"] as? Double
                    }
                    
                    let total = ratings.reduce(0, +)
                    let average = total / Double(ratings.count)
                    
                    DispatchQueue.main.async {
                        if let index = self.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                            self.ratingLinks[index].averageRating = average
                            self.ratingLinks[index].ratingCount = ratings.count
                        }
                    }
                }
        }
    }
    
    // NEW: Upload photo for a specific link
    func uploadLinkPhoto(_ image: UIImage, for link: RatingLink) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else { return }
        
        isUploadingPhoto = true
        errorMessage = ""
        
        Analytics.shared.track(
            event: "link_photo_upload_started",
            properties: [
                "link_id": link.linkId,
                "image_size_kb": imageData.count / 1024
            ]
        )
        
        let storageRef = storage.reference()
        let photoRef = storageRef.child("link_photos/\(userId)/\(link.linkId)_\(UUID().uuidString).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        photoRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    
                    Analytics.shared.trackError(
                        message: "Link photo upload failed: \(error.localizedDescription)",
                        properties: [
                            "link_id": link.linkId
                        ]
                    )
                }
                return
            }
            
            // Get download URL
            photoRef.downloadURL { [weak self] url, error in
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    
                    if let error = error {
                        self?.errorMessage = "Failed to get photo URL: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to get link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                        return
                    }
                    
                    // Update Firestore with new photo URL
                    self?.updateLinkPhotoUrl(url?.absoluteString, for: link)
                }
            }
        }
    }
    
    // NEW: Update link's photo URL in Firestore
    private func updateLinkPhotoUrl(_ url: String?, for link: RatingLink) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [:]
        if let url = url {
            updateData["photoUrl"] = url
        } else {
            updateData["photoUrl"] = NSNull()
        }
        
        // Find the document by linkId and affiliateId
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("affiliateId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to update link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Link document not found"
                    }
                    return
                }
                
                document.reference.updateData(updateData) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                            
                            Analytics.shared.trackError(
                                message: "Firestore photo update failed: \(error.localizedDescription)",
                                properties: [
                                    "link_id": link.linkId
                                ]
                            )
                        } else {
                            // Success - the listener will update the UI automatically
                            Analytics.shared.track(
                                event: "link_photo_updated_successfully",
                                properties: [
                                    "link_id": link.linkId,
                                    "has_photo": url != nil
                                ]
                            )
                        }
                    }
                }
            }
    }
    
    func updateLinkTitle(link: RatingLink, newTitle: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        Analytics.shared.track(
            event: "link_title_update_started",
            properties: [
                "link_id": link.linkId,
                "old_title": link.title,
                "new_title": newTitle
            ]
        )
        
        let db = Firestore.firestore()
        
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("affiliateId", isEqualTo: user.uid)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error updating title: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Link title update failed: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Link document not found"
                        
                        Analytics.shared.trackError(
                            message: "Link document not found for title update",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                document.reference.updateData([
                    "title": newTitle
                ]) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Error updating title: \(error.localizedDescription)"
                            
                            Analytics.shared.trackError(
                                message: "Firestore title update failed: \(error.localizedDescription)",
                                properties: [
                                    "link_id": link.linkId
                                ]
                            )
                        }
                    } else {
                        Analytics.shared.track(
                            event: "link_title_updated_successfully",
                            properties: [
                                "link_id": link.linkId,
                                "new_title": newTitle
                            ]
                        )
                    }
                }
            }
    }
    
    func createNewLink(completion: @escaping (RatingLink?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Analytics.shared.track(
            event: "link_creation_started",
            properties: [
                "current_link_count": ratingLinks.count
            ]
        )
        
        let db = Firestore.firestore()
        let linkId = "\(user.uid)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let linkNumber = ratingLinks.count + 1
        let title = "Rating Link #\(linkNumber)"
        
        // Generate random parlay amounts
        let parlayAmounts = generateRandomParlayAmounts()
        
        let linkData: [String: Any] = [
            "affiliateId": user.uid,
            "linkId": linkId,
            "title": title,
            "description": "",
            "url": "rate.socialstarapp.com/rate/\(user.uid)/\(linkId)",
            "createdAt": Timestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(48 * 60 * 60)),
            "totalRatings": 0,
            "earnings": 0.0,
            "status": "active",
            "parlayEntry": parlayAmounts.entry,
            "parlayWin": parlayAmounts.win,
            "parlayProfit": parlayAmounts.profit
            // photoUrl will be added later when user uploads a photo
        ]
        
        // Create link in a batch
        let batch = db.batch()
        
        let linkRef = db.collection("rating_links").document()
        batch.setData(linkData, forDocument: linkRef)
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error creating link: \(error.localizedDescription)"
                    
                    Analytics.shared.track(
                        event: "link_creation_failed",
                        properties: [
                            AnalyticsProperty.errorMessage: error.localizedDescription,
                            "current_link_count": self?.ratingLinks.count ?? 0
                        ]
                    )
                    
                    completion(nil)
                } else {
                    let newLink = RatingLink(
                        documentID: linkRef.documentID,
                        data: linkData
                    )
                    
                    Analytics.shared.track(
                        event: "link_created_successfully",
                        properties: [
                            "link_id": linkId,
                            "link_title": title,
                            "new_link_count": (self?.ratingLinks.count ?? 0) + 1,
                            "parlay_entry": parlayAmounts.entry,
                            "parlay_win": parlayAmounts.win,
                            "parlay_profit": parlayAmounts.profit
                        ]
                    )
                    
                    completion(newLink)
                }
            }
        }
    }
    
    private func generateRandomParlayAmounts() -> (entry: Int, win: Int, profit: Int) {
        // Generate entry amount between 50 and 200, ending in 0 or 5
        let entryBase = Int.random(in: 50...200)
        let entry = (entryBase / 5) * 5 // Round to nearest 5
        
        // Generate multiplier between 2x and 4x
        let multiplier = Double.random(in: 2.0...4.0)
        
        // Calculate win amount and round to nearest 5
        let winBase = Double(entry) * multiplier
        let win = Int((winBase / 5).rounded()) * 5
        
        // Calculate profit
        let profit = win - entry
        
        return (entry, win, profit)
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            
            Analytics.shared.track(
                event: "user_signed_out_from_dashboard"
            )
            
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
            
            Analytics.shared.trackError(
                message: "Sign out failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - UIImage Extension for Optimization
extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.6) -> Data? {
        // Step 1: Resize the image if needed
        let resizedImage = self.resizeIfNeeded(maxDimension: maxDimension)
        
        // Step 2: Apply progressive compression until we get a reasonable file size
        return resizedImage.compressedData(compressionQuality: compressionQuality)
    }
    
    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        let originalWidth = self.size.width
        let originalHeight = self.size.height
        
        // If the image is already smaller than our target, return the original
        if originalWidth <= maxDimension && originalHeight <= maxDimension {
            return self
        }
        
        // Figure out which dimension to scale based on
        let scaleFactor: CGFloat
        if originalWidth > originalHeight {
            scaleFactor = maxDimension / originalWidth
        } else {
            scaleFactor = maxDimension / originalHeight
        }
        
        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        // Render the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func compressedData(compressionQuality: CGFloat) -> Data? {
        // Start with the specified compression quality
        var quality = compressionQuality
        var data = self.jpegData(compressionQuality: quality)
        
        // Target size: 500KB for average mobile uploads
        let targetSize: Int = 500 * 1024
        
        // Try progressively lower quality if needed, with a minimum threshold
        while let imageData = data, imageData.count > targetSize && quality > 0.1 {
            quality -= 0.1
            data = self.jpegData(compressionQuality: quality)
        }
        
        return data
    }
}
