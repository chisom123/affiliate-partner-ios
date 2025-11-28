import Foundation
import FirebaseFirestore

class AffiliatePricingCalculator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false
    
    // MARK: - Private Properties
    private var cachedEarningsPerRating: Double = 0.25 // Default fallback
    private var lastFetchTime: Date?
    private let cacheExpirationInterval: TimeInterval = 60 // 1 minute
    private let db = Firestore.firestore()
    
    // Real-time listener and error handling
    private var configListener: ListenerRegistration?
    private var retryCount = 0
    private let maxRetries = 3
    private var lastUpdateTime: Date?
    private let debounceInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    init() {
        setupRealtimeListener()
    }
    
    deinit {
        configListener?.remove()
    }
    
    // MARK: - Real-time Configuration
    private func setupRealtimeListener() {
        configListener?.remove() // Remove existing listener before creating new one
        
        configListener = db.collection("app_config").document("affiliate_pricing")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error listening to affiliate pricing config: \(error.localizedDescription)")
                        self.handleListenerError()
                        return
                    }
                    
                    // Reset error state on successful connection
                    self.isOffline = false
                    self.retryCount = 0
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("Affiliate pricing config document does not exist, using defaults")
                        return
                    }
                    
                    self.updateConfigFromDocument(document)
                }
            }
    }
    
    private func handleListenerError() {
        isOffline = true
        
        guard retryCount < maxRetries else {
            print("Max retries reached for affiliate pricing config listener")
            return
        }
        
        retryCount += 1
        let delay = Double(retryCount * 2) // Exponential backoff: 2s, 4s, 6s
        
        print("Retrying affiliate pricing config listener in \(delay) seconds (attempt \(retryCount)/\(maxRetries))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.setupRealtimeListener()
        }
    }
    
    private func updateConfigFromDocument(_ document: DocumentSnapshot) {
        // Debounce rapid updates
        let now = Date()
        if let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < debounceInterval {
            return
        }
        lastUpdateTime = now
        
        let data = document.data() ?? [:]
        var hasChanges = false
        
        // Update earnings per rating
        if let earningsPerRating = data["earnings_per_rating"] as? Double {
            let clampedValue = max(0.0, min(10.0, earningsPerRating)) // Prevent negative or excessive values
            if earningsPerRating != clampedValue {
                print("⚠️ Earnings per rating value \(earningsPerRating) was clamped to \(clampedValue)")
            }
            if self.cachedEarningsPerRating != clampedValue {
                self.cachedEarningsPerRating = clampedValue
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("✅ Updated affiliate pricing config - Earnings per rating: $\(self.cachedEarningsPerRating)")
            self.objectWillChange.send()
        }
        
        lastFetchTime = Date()
    }
    
    // MARK: - Public Methods
    
    /// Get the current earnings per rating value
    func getEarningsPerRating() -> Double {
        return cachedEarningsPerRating
    }
    
    /// Calculate total earnings for a given number of ratings
    /// - Parameter ratingCount: Number of ratings
    /// - Returns: Total earnings (rounded to 2 decimal places)
    func calculateEarnings(for ratingCount: Int) -> Double {
        let earnings = Double(ratingCount) * cachedEarningsPerRating
        return (earnings * 100).rounded() / 100 // Round to 2 decimal places
    }
    
    /// Format earnings as currency string
    /// - Parameter earnings: Earnings amount
    /// - Returns: Formatted string like "$0.25"
    func formatEarnings(_ earnings: Double) -> String {
        return String(format: "$%.2f", earnings)
    }
    
    // MARK: - Manual Refresh (optional)
    func refreshConfig() async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let document = try await db.collection("app_config").document("affiliate_pricing").getDocument()
            
            await MainActor.run {
                self.isLoading = false
                self.isOffline = false
                if document.exists {
                    self.updateConfigFromDocument(document)
                }
            }
            
            return true
        } catch {
            print("Error fetching affiliate pricing config: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.isOffline = true
            }
            return false
        }
    }
    
    // MARK: - Utility Methods
    
    func getCurrentConfig() -> (earningsPerRating: Double, isOnline: Bool, lastUpdate: Date?) {
        return (cachedEarningsPerRating, !isOffline, lastFetchTime)
    }
    
    /// Force reconnection (useful for handling app foreground events)
    func reconnect() {
        retryCount = 0
        setupRealtimeListener()
    }
}

// MARK: - Shared Instance
extension AffiliatePricingCalculator {
    static let shared = AffiliatePricingCalculator()
}
