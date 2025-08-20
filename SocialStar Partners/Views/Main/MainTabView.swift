import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var sessionStartTime = Date()
    @State private var tabSessionTimes: [Int: Date] = [:]
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LinksView()
                .tabItem {
                    Image("link")
                        .renderingMode(.template)
                    Text("Links")
                        .font(.system(size: 11, weight: .bold))
                }
                .tag(0)
            
            EarningsView()
                .environmentObject(dashboardViewModel) // Pass the shared view model
                .tabItem {
                    Image("banknote")
                        .renderingMode(.template)
                    Text("Earnings")
                        .font(.system(size: 11, weight: .bold))
                }
                .tag(1)
                .badge(dashboardViewModel.affiliateData?.balance ?? 0 > 0 ? "1" : nil) // iOS 15+ badge
            
            SettingsView()
                .tabItem {
                    Image("settings-2")
                        .renderingMode(.template)
                    Text("Settings")
                        .font(.system(size: 11, weight: .bold))
                }
                .tag(2)
        }
        .accentColor(.primary)
        .onAppear {
            // Analytics: Track app session start
            Analytics.shared.track(
                event: "app_session_started",
                properties: [
                    "initial_tab": getTabName(for: selectedTab),
                    "session_start_time": ISO8601DateFormatter().string(from: sessionStartTime),
                    "has_balance": (dashboardViewModel.affiliateData?.balance ?? 0) > 0
                ]
            )
            
            // Initialize tab session tracking
            tabSessionTimes[selectedTab] = Date()
            
            // Load data when the tab view appears
            dashboardViewModel.loadData()
            
            // Modern tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Keep the subtle top border for definition
            appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)
            
            // Style selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.label,
                .font: UIFont.systemFont(ofSize: 11, weight: .bold)
            ]
            
            // Style unselected state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 11, weight: .bold)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            // Customize badge appearance
            appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.red
            appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = UIColor.red
            appearance.stackedLayoutAppearance.normal.badgeTextAttributes = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            appearance.stackedLayoutAppearance.selected.badgeTextAttributes = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        }
        .onChange(of: selectedTab) { newTab in
            let now = Date()
            
            // Calculate time spent on previous tab
            if let previousTabStartTime = tabSessionTimes[previousTab] {
                let timeSpent = now.timeIntervalSince(previousTabStartTime)
                
                // Analytics: Track time spent on previous tab
                Analytics.shared.track(
                    event: "tab_time_spent",
                    properties: [
                        "tab_name": getTabName(for: previousTab),
                        "time_spent_seconds": timeSpent,
                        "previous_tab": getTabName(for: previousTab),
                        "next_tab": getTabName(for: newTab)
                    ]
                )
            }
            
            // Analytics: Track tab switch
            Analytics.shared.track(
                event: "tab_switched",
                properties: [
                    "from_tab": getTabName(for: previousTab),
                    "to_tab": getTabName(for: newTab),
                    "tab_index": newTab,
                    "session_duration_seconds": now.timeIntervalSince(sessionStartTime),
                    "has_earnings_badge": (dashboardViewModel.affiliateData?.balance ?? 0) > 0
                ]
            )
            
            // Track screen view for the new tab
            Analytics.shared.trackScreen(
                name: getTabName(for: newTab),
                properties: [
                    "navigation_source": "tab_bar",
                    "previous_screen": getTabName(for: previousTab),
                    "session_duration_seconds": now.timeIntervalSince(sessionStartTime)
                ]
            )
            
            // Update tracking variables
            previousTab = selectedTab
            tabSessionTimes[newTab] = now
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Analytics: Track app return from background
            Analytics.shared.track(
                event: "app_returned_from_background",
                properties: [
                    "current_tab": getTabName(for: selectedTab),
                    "session_duration_seconds": Date().timeIntervalSince(sessionStartTime)
                ]
            )
            
            // Reset tab session time for current tab
            tabSessionTimes[selectedTab] = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            let now = Date()
            
            // Calculate time spent on current tab before backgrounding
            if let currentTabStartTime = tabSessionTimes[selectedTab] {
                let timeSpent = now.timeIntervalSince(currentTabStartTime)
                
                // Analytics: Track time spent before backgrounding
                Analytics.shared.track(
                    event: "app_backgrounded",
                    properties: [
                        "current_tab": getTabName(for: selectedTab),
                        "time_on_current_tab_seconds": timeSpent,
                        "total_session_duration_seconds": now.timeIntervalSince(sessionStartTime)
                    ]
                )
            }
        }
        .onChange(of: dashboardViewModel.affiliateData?.balance) { newBalance in
            // Analytics: Track balance changes that affect badge
            let hasBalance = (newBalance ?? 0) > 0
            let previouslyHadBalance = tabSessionTimes.isEmpty ? false : true // Simplified check
            
            if hasBalance != previouslyHadBalance {
                Analytics.shared.track(
                    event: "earnings_badge_changed",
                    properties: [
                        "current_tab": getTabName(for: selectedTab),
                        "new_balance": newBalance ?? 0,
                        "badge_visible": hasBalance,
                        "change_type": hasBalance ? "badge_appeared" : "badge_disappeared"
                    ]
                )
            }
        }
    }
    
    private func getTabName(for index: Int) -> String {
        switch index {
        case 0:
            return "links"
        case 1:
            return "earnings"
        case 2:
            return "settings"
        default:
            return "unknown"
        }
    }
}
