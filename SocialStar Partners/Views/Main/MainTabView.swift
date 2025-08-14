import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
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
                .tabItem {
                    Image("banknote")
                        .renderingMode(.template)
                    Text("Earnings")
                        .font(.system(size: 11, weight: .bold))
                }
                .tag(1)
            
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
        }
    }
}
