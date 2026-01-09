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
        // Remove all recruit detail listeners
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
                    
                    // First, process the recruit documents to get basic info
                    let recruits = documents.compactMap { doc -> Recruit? in
                        let recruitID = doc.documentID
                        let recruitData = doc.data()
                        return Recruit(documentID: recruitID, data: recruitData)
                    }
                    
                    // Clear existing recruit detail listeners
                    self?.recruitDetailsListeners.values.forEach { $0.remove() }
                    self?.recruitDetailsListeners.removeAll()
                    
                    // Clear current recruits array
                    self?.recruits.removeAll()
                    
                    // Fetch detailed info from main affiliates collection for each recruit
                    for recruit in recruits {
                        self?.setupRecruitDetailListener(recruit: recruit)
                    }
                }
            }
    }
    
    private func setupRecruitDetailListener(recruit: Recruit) {
        // Set up listener for this recruit's main affiliate document
        let listener = db.collection("affiliates").document(recruit.id)
            .addSnapshotListener { [weak self] document, error in
                if let data = document?.data() {
                    // Create updated recruit with data from main affiliates collection
                    var updatedRecruit = recruit
                    updatedRecruit.firstName = data["firstName"] as? String ?? "Recruit"
                    updatedRecruit.lastName = data["lastName"] as? String ?? ""
                    updatedRecruit.email = data["email"] as? String ?? ""
                    updatedRecruit.profilePictureUrl = data["profilePictureUrl"] as? String
                    
                    DispatchQueue.main.async {
                        // Update or add this recruit to the array
                        if let index = self?.recruits.firstIndex(where: { $0.id == recruit.id }) {
                            self?.recruits[index] = updatedRecruit
                        } else {
                            self?.recruits.append(updatedRecruit)
                        }
                        
                        // Sort the recruits
                        self?.sortRecruits()
                    }
                } else if let error = error {
                    print("Error fetching recruit details for \(recruit.id): \(error.localizedDescription)")
                }
            }
        
        // Store the listener for cleanup
        recruitDetailsListeners[recruit.id] = listener
    }
    
    private func sortRecruits() {
        recruits.sort { recruit1, recruit2 in
            // Sort by most earnings first, then most recent
            if recruit1.recruiterEarnings != recruit2.recruiterEarnings {
                return recruit1.recruiterEarnings > recruit2.recruiterEarnings
            }
            return recruit1.joinedAt > recruit2.joinedAt
        }
    }
}
