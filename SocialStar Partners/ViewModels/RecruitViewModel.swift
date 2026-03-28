import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class RecruitViewModel: ObservableObject {
    @Published var recruitLink: String = ""
    @Published var totalRecruits: Int = 0
    @Published var totalRecruiterEarnings: Double = 0.0
    @Published var recruits: [Recruit] = []
    @Published var isLoadingRecruits: Bool = false
    @Published var recruitLinkStats: [String: [RecruitLinkStat]] = [:]
    
    private var db = Firestore.firestore()
    private var recruitsListener: ListenerRegistration?
    private var recruitDetailsListeners: [String: ListenerRegistration] = [:]
    private var recruitLinkStatsListeners: [String: ListenerRegistration] = [:]
    
    deinit {
        recruitsListener?.remove()
        recruitDetailsListeners.values.forEach { $0.remove() }
        recruitLinkStatsListeners.values.forEach { $0.remove() }
    }
    
    func loadRecruitData() {
        loadRecruitLink()
        setupRecruitsListener()
    }
    
    func loadRecruitLink() {
        guard let userId = Auth.auth().currentUser?.uid else {
            recruitLink = "https://partners.socialstarapp.com"
            return
        }
        
        recruitLink = "https://partners.socialstarapp.com/recruit/\(userId)"
        
        Analytics.shared.trackScreen(
            name: "recruit",
            properties: [
                "has_user_id": !userId.isEmpty
            ]
        )
    }
    
    private func setupRecruitsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingRecruits = true
        
        // Listen to recruiter's affiliate document for total stats
        db.collection("affiliates").document(userId)
            .addSnapshotListener { [weak self] document, error in
                if let data = document?.data() {
                    DispatchQueue.main.async {
                        self?.totalRecruits = data["totalRecruits"] as? Int ?? 0
                        self?.totalRecruiterEarnings = data["recruiterEarnings"] as? Double ?? 0.0
                    }
                }
            }
        
        // Listen to recruiter's recruits subcollection for recruit IDs
        recruitsListener = db.collection("affiliates").document(userId)
            .collection("recruits")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoadingRecruits = false
                    
                    if let error = error {
                        print("Error loading recruits: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let recruits = documents.compactMap { doc -> Recruit? in
                        let recruitID = doc.documentID
                        let recruitData = doc.data()
                        return Recruit(documentID: recruitID, data: recruitData)
                    }
                    
                    // Clear existing listeners
                    self?.recruitDetailsListeners.values.forEach { $0.remove() }
                    self?.recruitDetailsListeners.removeAll()
                    self?.recruitLinkStatsListeners.values.forEach { $0.remove() }
                    self?.recruitLinkStatsListeners.removeAll()
                    
                    // Clear current recruits array
                    self?.recruits.removeAll()
                    
                    for recruit in recruits {
                        self?.setupRecruitDetailListener(recruit: recruit, recruiterId: userId)
                    }
                }
            }
    }
    
    private func setupRecruitDetailListener(recruit: Recruit, recruiterId: String) {
        let listener = db.collection("affiliates").document(recruit.id)
            .addSnapshotListener { [weak self] document, error in
                if let data = document?.data() {
                    var updatedRecruit = recruit
                    updatedRecruit.firstName = data["firstName"] as? String ?? "Recruit"
                    updatedRecruit.lastName = data["lastName"] as? String ?? ""
                    updatedRecruit.email = data["email"] as? String ?? ""
                    updatedRecruit.profilePictureUrl = data["profilePictureUrl"] as? String
                    
                    DispatchQueue.main.async {
                        if let index = self?.recruits.firstIndex(where: { $0.id == recruit.id }) {
                            self?.recruits[index] = updatedRecruit
                        } else {
                            self?.recruits.append(updatedRecruit)
                        }
                        
                        self?.sortRecruits()
                        self?.setupRecruitLinkStatsListener(recruiterId: recruiterId, recruitId: recruit.id)
                    }
                } else if let error = error {
                    print("Error fetching recruit details for \(recruit.id): \(error.localizedDescription)")
                }
            }
        
        recruitDetailsListeners[recruit.id] = listener
    }
    
    private func setupRecruitLinkStatsListener(recruiterId: String, recruitId: String) {
        recruitLinkStatsListeners[recruitId]?.remove()
        
        let listener = db.collection("affiliates").document(recruiterId)
            .collection("recruits").document(recruitId)
            .collection("recruitLinkStats")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching link stats for \(recruitId): \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let stats = documents.compactMap { doc in
                    RecruitLinkStat(documentID: doc.documentID, data: doc.data())
                }.sorted { $0.lastRatingAt > $1.lastRatingAt }
                
                DispatchQueue.main.async {
                    self?.recruitLinkStats[recruitId] = stats
                }
            }
        
        recruitLinkStatsListeners[recruitId] = listener
    }
    
    private func sortRecruits() {
        recruits.sort { recruit1, recruit2 in
            if recruit1.recruiterEarnings != recruit2.recruiterEarnings {
                return recruit1.recruiterEarnings > recruit2.recruiterEarnings
            }
            return recruit1.joinedAt > recruit2.joinedAt
        }
    }
}
