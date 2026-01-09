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
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("Your Recruit Link")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("Copy your unique recruit link")
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
                    
                    // How It Works
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("How It Works")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 15) {
                            StepView(number: "1", title: "Share your link", description: "Share your unique link with friends")
                            StepView(number: "2", title: "They sign up", description: "Friends sign up through your link")
                            StepView(number: "3", title: "They post & earn", description: "They earn $0.25 per rating on their stories")
                            StepView(number: "4", title: "You earn forever", description: "You earn $0.05 for every rating they get")
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

// MARK: - Step View
struct StepView: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
    }
}
