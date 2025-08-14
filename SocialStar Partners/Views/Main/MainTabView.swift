import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            LinksView()
                .tabItem {
                    Image(systemName: "link")
                    Text("Links")
                }
            
            EarningsView()
                .tabItem {
                    Image(systemName: "dollarsign.circle")
                    Text("Earnings")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}
