import SwiftUI
import Firebase
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
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
    
    init() {
        // FirebaseApp.configure() moved to AppDelegate
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
        let wasCheckingAuth = isCheckingAuth
        isAuthenticated = Auth.auth().currentUser != nil
        if wasCheckingAuth {
            isCheckingAuth = false
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
