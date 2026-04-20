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
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    VStack(spacing: 0) {
                                        Spacer()
                                        Text("Earn money\nrecruiting\nfriends")
                                            .font(.system(size: 21, weight: .bold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, 12)
                                        Spacer()
                                    }
                                    .frame(width: 160, height: 200)
                                    .background(Color.green)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    .padding(.leading, 20)
                                    
                                    ForEach(stepCards) { step in
                                        StepCardView(step: step)
                                            .padding(.trailing, step.id == 2 ? 20 : 0)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Total Earnings Summary (NEW)
                    if viewModel.totalRecruiterEarnings > 0 {
                        VStack(spacing: 8) {
                            Text("Total Earned from Recruits")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text("$\(viewModel.totalRecruiterEarnings, specifier: "%.2f")")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
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
                                .background(showCopiedMessage ? Color.green : Color.blue)
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
                            Spacer()
                            if !viewModel.recruits.isEmpty {
                                Text("\(viewModel.recruits.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        
                        if viewModel.recruits.isEmpty {
                            VStack(spacing: 8) {
                                Text("No Recruits Yet")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Share your link to start earning $10 per recruit")
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
            StepCard(id: 1, icon: "link", title: "Share Link", description: "Share your recruit link with friends"),
            StepCard(id: 2, icon: "dollarsign", title: "Earn $10", description: "When they get 10 total ratings")
        ]
    }
    
    private func copyLink() {
        guard !viewModel.recruitLink.isEmpty else { return }
        UIPasteboard.general.string = viewModel.recruitLink
        showCopiedMessage = true
        Analytics.shared.trackTap(elementId: "copy_recruit_link", screenName: "recruit")
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedMessage = false
        }
    }
}

// MARK: - Recruit Row (All info in one row - no detail sheet needed)
struct RecruitRow: View {
    let recruit: Recruit
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Profile image
                if let profilePictureUrl = recruit.profilePictureUrl,
                   !profilePictureUrl.isEmpty {
                    AsyncImage(url: URL(string: profilePictureUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } placeholder: {
                        initialsAvatar
                    }
                } else {
                    initialsAvatar
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recruit.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    
                    // Status line
                    if recruit.hasEarnedBonus {
                        Text("10+ ratings")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else {
                        Text("\(recruit.totalRatings) ratings")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Earnings display
                if recruit.hasEarnedBonus {
                    Text("$10.00")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$0")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(recruit.ratingsNeededForBonus) ratings to go")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 10)
            
            // Progress bar (only if not completed)
            if !recruit.hasEarnedBonus {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * recruit.progressToBonus, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 44, height: 44)
            Text(getInitials())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.blue)
        }
    }
    
    private func getInitials() -> String {
        let firstNameInitial = recruit.firstName.prefix(1)
        let lastNameInitial = recruit.lastName.prefix(1)
        if firstNameInitial.isEmpty && lastNameInitial.isEmpty { return "?" }
        return "\(firstNameInitial)\(lastNameInitial)".uppercased()
    }
}

// MARK: - Models (unchanged)
struct StepCard: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
}

// MARK: - Step Card View (unchanged)
struct StepCardView: View {
    let step: StepCard
    
    var body: some View {
        VStack(spacing: 0) {
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
