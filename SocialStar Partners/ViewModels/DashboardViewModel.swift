import Foundation
import Firebase
import Combine
import FirebaseAuth

class DashboardViewModel: ObservableObject {
    @Published var affiliateData: AffiliateData?
    @Published var ratingLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var linkListener: ListenerRegistration?
    private var affiliateListener: ListenerRegistration?
    
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
        
        setupAffiliateListener(userId: user.uid)
        setupRatingLinksListener(userId: user.uid)
    }
    
    private func setupAffiliateListener(userId: String) {
        let db = Firestore.firestore()
        
        // Real-time listener for affiliate data (balance updates)
        affiliateListener = db.collection("affiliates").document(userId)
            .addSnapshotListener { [weak self] document, error in
                DispatchQueue.main.async {
                    if let document = document,
                       document.exists,
                       let data = document.data(),
                       let affiliateData = AffiliateData(data: data) {
                        self?.affiliateData = affiliateData
                    }
                }
            }
    }
    
    private func setupRatingLinksListener(userId: String) {
        let db = Firestore.firestore()
        
        linkListener = db.collection("rating_links")
            .whereField("affiliateId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let documents = snapshot?.documents else { return }
                    
                    var links = documents.compactMap { doc in
                        RatingLink(documentID: doc.documentID, data: doc.data())
                    }
                    
                    // Calculate average ratings for each link
                    self?.calculateAverageRatings(for: &links)
                    
                    self?.ratingLinks = links
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
                            // Update link with no ratings
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
                        // Update the specific link in the array
                        if let index = self.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                            self.ratingLinks[index].averageRating = average
                            self.ratingLinks[index].ratingCount = ratings.count
                        }
                    }
                }
        }
    }
    
    func createNewLink() {
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        errorMessage = ""
        
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
            "expiresAt": Timestamp(date: Date().addingTimeInterval(48 * 60 * 60)), // 48 hours
            "totalRatings": 0,
            "earnings": 0.0,
            "status": "active"
        ]
        
        db.collection("rating_links").addDocument(data: linkData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error creating link: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }
}
