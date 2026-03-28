import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RecruitView: View {
    @StateObject private var viewModel = RecruitViewModel()
    @State private var showCopiedMessage = false
    @State private var selectedRecruit: Recruit? = nil
    
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
                                        Text("Earn Money\nRecruiting\nFriends")
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
                                    .onTapGesture {
                                        selectedRecruit = recruit
                                    }
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
        .sheet(item: $selectedRecruit) { recruit in
            RecruitDetailSheet(
                recruit: recruit,
                linkStats: viewModel.recruitLinkStats[recruit.id] ?? []
            )
        }
    }
    
    private var stepCards: [StepCard] {
        [
            StepCard(id: 1, icon: "link", title: "Share Link", description: "Share your recruit link with friends"),
            StepCard(id: 2, icon: "dollarsign", title: "Earn Money", description: "Earn $1 every time they post a story")
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

// MARK: - Recruit Detail Sheet
struct RecruitDetailSheet: View {
    let recruit: Recruit
    let linkStats: [RecruitLinkStat]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recruit Header
                    HStack(spacing: 16) {
                        if let profilePictureUrl = recruit.profilePictureUrl,
                           !profilePictureUrl.isEmpty {
                            AsyncImage(url: URL(string: profilePictureUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } placeholder: {
                                initialsAvatar(size: 60)
                            }
                        } else {
                            initialsAvatar(size: 60)
                        }
                        
                        Text(recruit.displayName)
                            .font(.system(size: 20, weight: .bold))
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("$\(Double(recruit.storiesCompleted), specifier: "%.2f")")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                            Text("Earned")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Stories Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stories")
                            .font(.system(size: 18, weight: .semibold))
                        
                        if linkStats.isEmpty {
                            VStack(spacing: 8) {
                                Text("No stories yet")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Stories will appear here once your recruit posts their first link")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        } else {
                            ForEach(linkStats) { stat in
                                RecruitLinkStatRow(stat: stat)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(recruit.firstName)'s Stories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func initialsAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: size, height: size)
            Text(getInitials())
                .font(.system(size: size * 0.35, weight: .bold))
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

// MARK: - Recruit Link Stat Row
struct RecruitLinkStatRow: View {
    let stat: RecruitLinkStat
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail
            if let photoUrl = stat.photoUrl, !photoUrl.isEmpty {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    photoPlaceholder
                }
            } else {
                photoPlaceholder
            }
            
            // Title, theme and progress
            VStack(alignment: .leading, spacing: 6) {
                Text(stat.title.isEmpty ? "Untitled Story" : stat.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                if let theme = stat.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                
                if stat.hasCompleted {
                    Text("$1.00 Earned")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(20)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(stat.progressToNextPayout), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(stat.totalRatings)/10 ratings")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
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

// MARK: - Recruit Row
struct RecruitRow: View {
    let recruit: Recruit
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recruit.displayName)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Spacer()
            
            Text("$\(Double(recruit.storiesCompleted), specifier: "%.2f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
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
