import Foundation
import Firebase
import Combine
import FirebaseAuth

class DashboardViewModel: ObservableObject {
    @Published var affiliateData: AffiliateData?
    @Published var ratingLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var isInitialDataLoad = true
    @Published var errorMessage = ""
    
    private var linkListener: ListenerRegistration?
    private var affiliateListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private var hasReceivedInitialAffiliateData = false
    
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
                    
                    // NEW: Track prediction statistics
                    let linksWithPredictions = links.filter { $0.hasPrediction }
                    Analytics.shared.track(
                        event: "rating_links_loaded",
                        properties: [
                            "link_count": links.count,
                            "active_links": links.filter { $0.isActive }.count,
                            "links_with_predictions": linksWithPredictions.count
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
                            
                            // NEW: Track prediction accuracy if prediction exists
                            if let prediction = link.predictedRating, ratings.count > 0 {
                                let accuracy = self.ratingLinks[index].predictionAccuracy ?? 0
                                Analytics.shared.track(
                                    event: "prediction_accuracy_calculated",
                                    properties: [
                                        "link_id": link.id,
                                        "predicted_rating": prediction,
                                        "actual_rating": average,
                                        "accuracy_percentage": accuracy,
                                        "rating_count": ratings.count
                                    ]
                                )
                            }
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
            "status": "active"
            // Note: predictedRating will be added when user saves their prediction
        ]
        
        db.collection("rating_links").addDocument(data: linkData) { [weak self] error in
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
                        documentID: "",
                        data: linkData
                    )
                    
                    Analytics.shared.track(
                        event: "link_created_successfully",
                        properties: [
                            "link_id": linkId,
                            "link_title": title,
                            "new_link_count": (self?.ratingLinks.count ?? 0) + 1
                        ]
                    )
                    
                    completion(newLink)
                }
            }
        }
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
