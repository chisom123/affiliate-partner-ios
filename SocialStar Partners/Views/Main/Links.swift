import SwiftUI

struct LinksView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedLinkForInstructions: RatingLink?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
        
                        // Rating Links List
                        if viewModel.ratingLinks.isEmpty {
                            // Centered empty state
                            VStack(spacing: 16) {
                                Image(systemName: "link.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                
                                VStack(spacing: 8) {
                                    Text("No Rating Links Yet")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Create your first link to start earning")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: {
                                    viewModel.createNewLink { newLink in
                                        selectedLinkForInstructions = newLink
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16, weight: .medium))
                                        Text("New Link")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(200)
                                }
                                .disabled(viewModel.isLoading)
                                .opacity(viewModel.isLoading ? 0.6 : 1.0)
                                .padding(.top)
                            }
                            .padding(.vertical, 50)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                            
                           
                        } else {
                            ForEach(viewModel.ratingLinks.sorted(by: { $0.createdAt > $1.createdAt })) { link in
                                LinkCard(
                                    link: link,
                                    onUseLink: {
                                        selectedLinkForInstructions = link
                                    },
                                    onUpdateTitle: { newTitle in
                                        viewModel.updateLinkTitle(link: link, newTitle: newTitle)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical)
                    .padding(.horizontal)
                }
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
                            .foregroundColor(viewModel.isLoading ? .gray : Color.blue)
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
    let onUpdateTitle: (String) -> Void
    
    @State private var isEditingTitle = false
    @State private var editingTitle = ""
    @FocusState private var isTitleFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) { // Changed from default .center to .top
                VStack(alignment: .leading) {
                    if isEditingTitle {
                        TextField("Link Title", text: $editingTitle)
                            .font(.system(size: 16, weight: .bold))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTitleFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                saveTitle()
                            }
                            .onAppear {
                                editingTitle = link.title
                                isTitleFieldFocused = true
                            }
                    } else {
                        HStack(spacing: 8) {
                            Text(link.title)
                                .font(.system(size: 16, weight: .bold))
                            
                            Image("pencil")
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            startEditingTitle()
                        }
                    }
                    
                    Text(timeAgoString(from: link.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                if !isEditingTitle {
                    Spacer()
                
                    Image(systemName: link.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(link.isActive ? .green : .red)
                }
            }
            
            // Earnings and Ratings
            HStack {
                VStack(alignment: .leading) {  // Left align the earnings section
                    Text("$\(link.earnings, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                    Text("Earned")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
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
        .onTapGesture {
            // Dismiss editing when tapping outside the title
            if isEditingTitle {
                saveTitle()
            }
        }
    }
    
    private func startEditingTitle() {
        isEditingTitle = true
        editingTitle = link.title
    }
    
    private func saveTitle() {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != link.title {
            onUpdateTitle(trimmedTitle)
        }
        isEditingTitle = false
        isTitleFieldFocused = false
    }
    
    private func cancelEditing() {
        isEditingTitle = false
        editingTitle = link.title
        isTitleFieldFocused = false
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
