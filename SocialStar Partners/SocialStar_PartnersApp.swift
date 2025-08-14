import SwiftUI
import Firebase
import FirebaseAuth

@main
struct SocialStarPartnersApp: App {
    @State private var isAuthenticated = false
    
    init() {
        FirebaseApp.configure()
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
