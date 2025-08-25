import SwiftUI

struct WelcomeView: View {
    @State private var navigateToEmail = false
    @State private var navigateToSignIn = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top section with logo and text
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 80)
                        
                        // Logo
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        // Headlines
                        VStack(spacing: 12) {
                            Text("Welcome to SocialStar Partners")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                    
                    // Bottom section with buttons
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            // Sign Up Button
                            Button(action: {
                                // Analytics: Track sign up button tap
                                Analytics.shared.trackTap(
                                    elementId: "sign_up_button",
                                    screenName: "welcome"
                                )
                                
                                navigateToEmail = true
                            }) {
                                Text("Sign Up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            // Sign In Button
                            Button(action: {
                                // Analytics: Track log in button tap
                                Analytics.shared.trackTap(
                                    elementId: "log_in_button",
                                    screenName: "welcome"
                                )
                                
                                navigateToSignIn = true
                            }) {
                                Text("Log In")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 3)
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(height: 50)
                    }
                    
                    // Hidden Navigation Links
                    NavigationLink(destination: EmailEntryView(), isActive: $navigateToEmail) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(destination: SignInView(), isActive: $navigateToSignIn) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Analytics: Track welcome screen view
            Analytics.shared.trackScreen(name: "welcome")
        }
    }
}
