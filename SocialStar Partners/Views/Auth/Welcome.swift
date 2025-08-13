import SwiftUI

struct WelcomeView: View {
    @State private var navigateToEmail = false
    @State private var navigateToSignIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Text("Welcome to SocialStar Partners")
                    .font(.system(size: 30, weight: .bold))
                
                Text("Get paid for your story ratings")
                    .font(.system(size: 18))
                
                VStack(spacing: 20) {
                    Button("Sign Up") {
                        navigateToEmail = true
                    }
                    .font(.system(size: 18, weight: .bold))
                    .padding()
                    
                    Button("Sign In") {
                        navigateToSignIn = true
                    }
                    .font(.system(size: 18, weight: .bold))
                    .padding()
                }
                
                NavigationLink(destination: EmailEntryView(), isActive: $navigateToEmail) {
                    EmptyView()
                }
                
                NavigationLink(destination: SignInView(), isActive: $navigateToSignIn) {
                    EmptyView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
