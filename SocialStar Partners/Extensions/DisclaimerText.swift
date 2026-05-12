import SwiftUI

struct DisclaimerText: View {
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack {
            let readOurText = Text("Read our ")
            let privacyText = Text("Privacy Policy").underline()
            let andText = Text(" and Tap \"Continue\" to accept the ")
            let termsText = Text("Terms of Use (EULA)").underline()
            
            (readOurText + privacyText + andText + termsText)
                .padding(.horizontal)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .onTapGesture {
                    showingActionSheet = true
                }
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(
                        title: Text("Choose Document"),
                        message: Text("Which document would you like to view?"),
                        buttons: [
                            .default(Text("Terms of Use (EULA)")) {
                                openURL("https://chay-b6172c.webflow.io")
                            },
                            .default(Text("Privacy Policy")) {
                                openURL("https://chay-b6172c.webflow.io/privacy-policy")
                            },
                            .cancel()
                        ]
                    )
                }
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
