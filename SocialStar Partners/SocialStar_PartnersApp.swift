import SwiftUI
import Firebase
import FirebaseAuth

@main
struct SocialStarPartnersApp: App {
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    
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
                if isCheckingAuth {
                    // Show loading state while checking authentication
                    LaunchScreenView()
                } else if isAuthenticated {
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
        // Check if this is the initial auth check
        let wasCheckingAuth = isCheckingAuth
        
        isAuthenticated = Auth.auth().currentUser != nil
        
        // Only set isCheckingAuth to false after the initial check
        if wasCheckingAuth {
            isCheckingAuth = false
        }
    }
}

// Loading screen to show while checking authentication
struct LaunchScreenView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.2)
            .tint(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}
