import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RecruitView: View {
    @StateObject private var viewModel = RecruitViewModel()
    @State private var showCopiedMessage = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // How It Works - Only show if no recruits
                    if viewModel.recruits.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center) {
                                Text("How It Works")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 20)
                            
                            // Horizontal scroll with clean edges - 5 cards total
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Card 1: Green highlight card
                                    VStack(spacing: 0) {
                                        Spacer()
                                        
                                        Text("Earn Money\nRecruiting\nFriends")
                                            .font(.system(size: 21, weight: .bold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Spacer()
                                    }
                                    .frame(width: 160, height: 200)
                                    .background(Color.green)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    .padding(.leading, 20)
                                    
                                    // Cards 2-4: Middle step cards
                                    ForEach(stepCards[0...2]) { step in
                                        StepCardView(step: step)
                                    }
                                    
                                    // Card 5: Last step card with trailing padding
                                    StepCardView(step: stepCards[3])
                                        .padding(.trailing, 20)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Your Recruit Link
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("Your Recruit Link")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("Share your unique recruit link")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            Text(viewModel.recruitLink)
                                .frame(maxWidth: .infinity)
                                .padding(5)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button(action: copyLink) {
                                HStack(spacing: 8) {
                                    Text(showCopiedMessage ? "Link Copied" : "Copy Link")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    showCopiedMessage ? Color.green : Color.blue
                                )
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Your Recruits List
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("Your Recruits")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        if viewModel.recruits.isEmpty {
                            VStack(spacing: 8) {
                                Text("No Recruits Yet")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Share your link to start earning")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .padding(.vertical, 30)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            
                        } else {
                            ForEach(viewModel.recruits) { recruit in
                                RecruitRow(recruit: recruit)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                }
                .padding()
            }
            .navigationTitle("Recruits")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadRecruitData()
        }
    }
    
    private var stepCards: [StepCard] {
        [
            StepCard(
                id: 1,
                icon: "link",
                title: "Share Link",
                description: "Share your recruit link with friends"
            ),
            StepCard(
                id: 2,
                icon: "person.fill.badge.plus",
                title: "Friends Join",
                description: "Friends sign up through your link"
            ),
            StepCard(
                id: 3,
                icon: "camera.fill",
                title: "Friends Post",
                description: "Friends post stories and earn"
            ),
            StepCard(
                id: 4,
                icon: "dollarsign",
                title: "You Earn",
                description: "You earn $0.10 for every rating they get"
            )
        ]
    }
    
    private func copyLink() {
        guard !viewModel.recruitLink.isEmpty else { return }
        
        UIPasteboard.general.string = viewModel.recruitLink
        showCopiedMessage = true
        
        // Analytics
        Analytics.shared.trackTap(
            elementId: "copy_recruit_link",
            screenName: "recruit"
        )
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedMessage = false
        }
    }
}

// MARK: - Models
struct StepCard: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
}

// MARK: - Step Card View
struct StepCardView: View {
    let step: StepCard
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed-height icon section
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: step.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Text content with consistent spacing
            VStack(alignment: .center, spacing: 8) {
                Text(step.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(step.description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            
            Spacer(minLength: 0)
        }
        .frame(width: 160, height: 200)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Recruit Row
struct RecruitRow: View {
    let recruit: Recruit
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Profile Picture or Initials Avatar
                if let profilePictureUrl = recruit.profilePictureUrl,
                   !profilePictureUrl.isEmpty {
                    AsyncImage(url: URL(string: profilePictureUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Text(getInitials())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    // Initials Avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Text(getInitials())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recruit.displayName)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(recruit.recruiterEarnings, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("\(recruit.totalRatings) rating\(recruit.totalRatings == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func getInitials() -> String {
        let firstNameInitial = recruit.firstName.prefix(1)
        let lastNameInitial = recruit.lastName.prefix(1)
        
        if firstNameInitial.isEmpty && lastNameInitial.isEmpty {
            return "?"
        }
        
        return "\(firstNameInitial)\(lastNameInitial)".uppercased()
    }
}
