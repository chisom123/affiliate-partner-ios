import SwiftUI
import Firebase
import FirebaseAuth
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        application.registerForRemoteNotifications()
        
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return Auth.auth().canHandle(url)
    }
}

@main
struct SocialStarPartnersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var isProfileIncomplete = false
    @State private var isOnboardingInProgress = false
    
    init() {
        let POSTHOG_API_KEY = "phc_qj9C9wVUnzp0JrbLAjcH603STtMN7Eu0dvHEt5ndNwM"
        let POSTHOG_HOST = "https://eu.i.posthog.com"
        let analyticsService = PostHogAnalyticsService(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        Analytics.shared.configure(with: analyticsService)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    LaunchScreenView()
                } else if isProfileIncomplete {
                    ProfileCompletionView()
                } else if isAuthenticated {
                    MainTabView()
                } else {
                    WelcomeView()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                if !isProfileIncomplete && !isOnboardingInProgress {
                    checkAuthState()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileIncomplete)) { _ in
                isProfileIncomplete = true
                isOnboardingInProgress = true
                isAuthenticated = true
                isCheckingAuth = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileCompleted)) { _ in
                isProfileIncomplete = false
                isOnboardingInProgress = false
                isAuthenticated = true
                isCheckingAuth = false
            }
            .onAppear {
                checkAuthState()
            }
        }
    }
    
    private func checkAuthState() {
        guard let user = Auth.auth().currentUser else {
            isAuthenticated = false
            isCheckingAuth = false
            return
        }
        
        Firestore.firestore().collection("affiliates").document(user.uid).getDocument { document, error in
            DispatchQueue.main.async {
                guard let data = document?.data() else {
                    isAuthenticated = true
                    isCheckingAuth = false
                    return
                }
                
                let hasPhone = user.phoneNumber != nil && !user.phoneNumber!.isEmpty
                let hasProfilePicture = (data["profilePictureUrl"] as? String).map { !$0.isEmpty } ?? false
                
                if !hasPhone || !hasProfilePicture {
                    try? Auth.auth().signOut()
                    isAuthenticated = false
                    isProfileIncomplete = false
                    isOnboardingInProgress = false
                } else {
                    isAuthenticated = true
                }
                
                isCheckingAuth = false
            }
        }
    }
}

struct LaunchScreenView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.2)
            .tint(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}
