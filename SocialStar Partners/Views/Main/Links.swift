import SwiftUI

struct LinksView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedLinkForInstructions: RatingLink?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Rating Links List
                    if viewModel.ratingLinks.isEmpty {
                        VStack {
                            Text("No rating links yet")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Create your first link to start earning")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        ForEach(viewModel.ratingLinks.sorted(by: { $0.createdAt > $1.createdAt })) { link in
                            LinkCard(link: link, onUseLink: {
                                selectedLinkForInstructions = link
                            })
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Links")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.createNewLink { newLink in
                            selectedLinkForInstructions = newLink
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.isLoading ? .gray : Color(hex: "4169E1"))
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadData()
        }
        .sheet(item: $selectedLinkForInstructions) { link in
            UseLinkInstructionsView(link: link)
        }
    }
}

struct LinkCard: View {
    let link: RatingLink
    let onUseLink: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(link.title)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(timeAgoString(from: link.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(link.isActive ? "Active" : "Expired")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(link.isActive ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            // Earnings and Ratings
            HStack {
                VStack {
                    Text("$\(link.earnings, specifier: "%.2f")")
                        .font(.system(size: 18, weight: .bold))
                    Text("Earned")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack {
                    Text("\(link.totalRatings)")
                        .font(.system(size: 18, weight: .bold))
                    Text("Ratings")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Average Rating Display
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(link.averageRating, specifier: "%.1f")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(link.hasRatings ? .orange : .gray)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Text("★")
                                .font(.system(size: 14))
                                .foregroundColor(link.hasRatings && Double(star) <= link.averageRating.rounded() ? .orange : .gray.opacity(0.5))
                        }
                    }
                }
                
                Text("Average from \(link.ratingCount) rating\(link.ratingCount != 1 ? "s" : "")")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
            
            // Use Link Button
            if link.isActive {
                Button("Use Link") {
                    onUseLink()
                }
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        let minutes = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(days)d ago"
        }
    }
}

struct UseLinkInstructionsView: View {
    let link: RatingLink
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedMessage = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("How to Use Link")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top)
                    
                    // Step 1: Copy Link
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("1")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            
                            Text("Copy Link")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        
                        Text("Copy your unique rating link")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            Text("https://\(link.url)")
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button(showCopiedMessage ? "Link Copied!" : "Copy Link") {
                                UIPasteboard.general.string = "https://\(link.url)"
                                showCopiedMessage = true
                                
                                // Reset message after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedMessage = false
                                }
                            }
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(showCopiedMessage ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Step 2: Add to Story
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("2")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            
                            Text("Add Link to Story")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        
                        Text("Add the link to your Instagram or Snapchat story when sharing a photo or video")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text("Instagram")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                            
                            Text("Snapchat")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Step 3: Start Earning
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("3")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            
                            Text("Start Earning")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        
                        Text("Earn $0.25 for every story rating you receive. Track your earnings in real-time")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 Pro Tip")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            Text("Links expire after 48 hours. Create new ones regularly for the best results and maximum earnings")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Done Button
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
