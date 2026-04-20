import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class RecruitViewModel: ObservableObject {
    @Published var recruitLink: String = ""
    @Published var totalRecruits: Int = 0
    @Published var totalRecruiterEarnings: Double = 0.0
    @Published var recruits: [Recruit] = []
    @Published var isLoadingRecruits: Bool = false
    
    private var db = Firestore.firestore()
    private var recruitsListener: ListenerRegistration?
    private var recruitDetailsListeners: [String: ListenerRegistration] = [:]
    
    deinit {
        recruitsListener?.remove()
        recruitDetailsListeners.values.forEach { $0.remove() }
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
        
        // Listen to recruiter's recruits subcollection
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
                    }
                }
            }
        
        recruitDetailsListeners[recruit.id] = listener
    }
    
    private func sortRecruits() {
        recruits.sort { recruit1, recruit2 in
            // Sort by bonus earned first
            if recruit1.hasEarnedBonus != recruit2.hasEarnedBonus {
                return recruit1.hasEarnedBonus && !recruit2.hasEarnedBonus
            }
            // Then by progress
            if recruit1.progressToBonus != recruit2.progressToBonus {
                return recruit1.progressToBonus > recruit2.progressToBonus
            }
            // Then by join date
            return recruit1.joinedAt > recruit2.joinedAt
        }
    }
}
