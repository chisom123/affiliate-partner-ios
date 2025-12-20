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
                    Label("Links", image: "link")
                }
                .tag(0)
            
            EarningsView()
                .environmentObject(dashboardViewModel)
                .tabItem {
                    Label("Earnings", image: "banknote")
                }
                .tag(1)
                .badge(dashboardViewModel.affiliateData?.balance ?? 0 > 0 ? "1" : nil)
            
            SettingsView()
                .tabItem {
                    Label("Settings", image: "settings-2")
                }
                .tag(2)
        }
        .accentColor(.primary)
        .onAppear {
            configureTabBarAppearance()
            
            // Analytics: Track app session start
            Analytics.shared.track(
                event: "app_session_started",
                properties: [
                    "initial_tab": getTabName(for: selectedTab),
                    "session_start_time": ISO8601DateFormatter().string(from: sessionStartTime),
                    "has_balance": (dashboardViewModel.affiliateData?.balance ?? 0) > 0
                ]
            )
            
            tabSessionTimes[selectedTab] = Date()
            dashboardViewModel.loadData()
        }
        .onChange(of: selectedTab) { newTab in
            let now = Date()
            
            if let previousTabStartTime = tabSessionTimes[previousTab] {
                let timeSpent = now.timeIntervalSince(previousTabStartTime)
                
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
            
            Analytics.shared.trackScreen(
                name: getTabName(for: newTab),
                properties: [
                    "navigation_source": "tab_bar",
                    "previous_screen": getTabName(for: previousTab),
                    "session_duration_seconds": now.timeIntervalSince(sessionStartTime)
                ]
            )
            
            previousTab = selectedTab
            tabSessionTimes[newTab] = now
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Analytics.shared.track(
                event: "app_returned_from_background",
                properties: [
                    "current_tab": getTabName(for: selectedTab),
                    "session_duration_seconds": Date().timeIntervalSince(sessionStartTime)
                ]
            )
            
            tabSessionTimes[selectedTab] = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            let now = Date()
            
            if let currentTabStartTime = tabSessionTimes[selectedTab] {
                let timeSpent = now.timeIntervalSince(currentTabStartTime)
                
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
            let hasBalance = (newBalance ?? 0) > 0
            let previouslyHadBalance = tabSessionTimes.isEmpty ? false : true
            
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
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Embrace the Liquid Glass design with subtle customization
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.2)
        
        // Selected state - keep icons/text bold for better visibility
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]
        
        // Unselected state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        
        // Badge styling
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.systemRed
        appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = UIColor.systemRed
        appearance.stackedLayoutAppearance.normal.badgeTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        appearance.stackedLayoutAppearance.selected.badgeTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func getTabName(for index: Int) -> String {
        switch index {
        case 0: return "links"
        case 1: return "earnings"
        case 2: return "settings"
        default: return "unknown"
        }
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
