import SwiftUI
import Firebase
import FirebaseAuth

@main
struct SocialStarPartnersApp: App {
    @State private var isAuthenticated = false
    
    init() {
        FirebaseApp.configure()
        
        // Configure analytics with PostHog
        let POSTHOG_API_KEY = "phc_qj9C9wVUnzp0JrbLAjcH603STtMN7Eu0dvHEt5ndNwM"
        let POSTHOG_HOST = "https://eu.i.posthog.com"
        
        // Setup analytics with PostHog implementation
        let analyticsService = PostHogAnalyticsService(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        Analytics.shared.configure(with: analyticsService)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    MainTabView()
                } else {
                    WelcomeView()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                checkAuthState()
            }
            .onAppear {
                checkAuthState()
            }
        }
    }
    
    private func checkAuthState() {
        isAuthenticated = Auth.auth().currentUser != nil
    }
}
