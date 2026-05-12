import SwiftUI

struct WelcomeView: View {
    @State private var navigateToExplainer = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 80)

                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 5))

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

                    VStack(spacing: 16) {
                        DisclaimerText()
                        
                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "welcome_continue_button",
                                screenName: "welcome"
                            )
                            navigateToExplainer = true
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top)
                        
                        Spacer()
                            .frame(height: 50)
                    }

                    NavigationLink(
                        destination: ProgramExplainerView(),
                        isActive: $navigateToExplainer
                    ) {
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
            Analytics.shared.trackScreen(name: "welcome")
        }
    }
}
