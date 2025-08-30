import SwiftUI

struct LinksView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedLinkForInstructions: RatingLink?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // Show loading state during initial load
                        if viewModel.isInitialDataLoad && viewModel.ratingLinks.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.gray)
                            }
                            .padding(.vertical, 100)
                            .frame(maxWidth: .infinity)
                        }
                        // Rating Links List
                        else if viewModel.ratingLinks.isEmpty {
                            // Centered empty state - only show after initial load
                            VStack(spacing: 16) {
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
                                    // Analytics: Track first link creation from empty state
                                    Analytics.shared.trackTap(
                                        elementId: "create_first_link_button",
                                        screenName: "links",
                                        properties: [
                                            "user_state": "empty_state",
                                            "total_links": viewModel.ratingLinks.count
                                        ]
                                    )
                                    
                                    viewModel.createNewLink { newLink in
                                        selectedLinkForInstructions = newLink
                                        
                                        // Analytics: Track successful first link creation
                                        if let link = newLink {
                                            Analytics.shared.track(
                                                event: "first_link_created",
                                                properties: [
                                                    AnalyticsProperty.screenName: "links",
                                                    "link_id": link.id,
                                                    "link_title": link.title
                                                ]
                                            )
                                        }
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
                                        
                                        // Analytics: Track link instructions opened
                                        Analytics.shared.trackTap(
                                            elementId: "use_link_button",
                                            screenName: "links",
                                            properties: [
                                                "link_id": link.id,
                                                "link_earnings": link.earnings,
                                                "link_rating_count": link.ratingCount,
                                                "link_average_rating": link.averageRating,
                                                "link_is_active": link.isActive
                                            ]
                                        )
                                    },
                                    onUpdateTitle: { newTitle in
                                        // Analytics: Track link title update
                                        Analytics.shared.track(
                                            event: "link_title_updated",
                                            properties: [
                                                AnalyticsProperty.screenName: "links",
                                                "link_id": link.id,
                                                "old_title": link.title,
                                                "new_title": newTitle,
                                                "title_length": newTitle.count
                                            ]
                                        )
                                        
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
                        // Analytics: Track new link creation from toolbar
                        Analytics.shared.trackTap(
                            elementId: "add_link_toolbar_button",
                            screenName: "links",
                            properties: [
                                "total_links": viewModel.ratingLinks.count,
                                "user_state": viewModel.ratingLinks.isEmpty ? "empty" : "has_links"
                            ]
                        )
                        
                        viewModel.createNewLink { newLink in
                            selectedLinkForInstructions = newLink
                            
                            // Analytics: Track successful link creation
                            if let link = newLink {
                                Analytics.shared.track(
                                    event: "link_created",
                                    properties: [
                                        AnalyticsProperty.screenName: "links",
                                        "link_id": link.id,
                                        "link_title": link.title,
                                        "total_links_after": viewModel.ratingLinks.count + 1,
                                        "creation_source": "toolbar"
                                    ]
                                )
                            }
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
            // Analytics: Track screen view with link statistics
            let activeLinks = viewModel.ratingLinks.filter { $0.isActive }
            let totalEarnings = viewModel.ratingLinks.reduce(0) { $0 + $1.earnings }
            let totalRatings = viewModel.ratingLinks.reduce(0) { $0 + $1.ratingCount }
            
            Analytics.shared.trackScreen(
                name: "links",
                properties: [
                    "total_links": viewModel.ratingLinks.count,
                    "active_links": activeLinks.count,
                    "inactive_links": viewModel.ratingLinks.count - activeLinks.count,
                    "total_earnings": totalEarnings,
                    "total_ratings": totalRatings,
                    "average_earnings_per_link": viewModel.ratingLinks.isEmpty ? 0 : totalEarnings / Double(viewModel.ratingLinks.count)
                ]
            )
            
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
    @State private var hasTrackedView = false
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
                                
                                // Analytics: Track title editing started
                                Analytics.shared.track(
                                    event: "link_title_edit_started",
                                    properties: [
                                        AnalyticsProperty.screenName: "links",
                                        "link_id": link.id,
                                        "current_title": link.title
                                    ]
                                )
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
                            // Analytics: Track title edit tap
                            Analytics.shared.trackTap(
                                elementId: "link_title_edit",
                                screenName: "links",
                                properties: [
                                    "link_id": link.id,
                                    "current_title": link.title
                                ]
                            )
                            
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
                Button(action: {
                    onUseLink()
                }) {
                    Text("Use Link")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            // Analytics: Track link card view (only once per card)
            if !hasTrackedView {
                Analytics.shared.track(
                    event: "link_card_viewed",
                    properties: [
                        AnalyticsProperty.screenName: "links",
                        "link_id": link.id,
                        "link_earnings": link.earnings,
                        "link_rating_count": link.ratingCount,
                        "link_average_rating": link.averageRating,
                        "link_is_active": link.isActive,
                        "link_age_days": Calendar.current.dateComponents([.day], from: link.createdAt, to: Date()).day ?? 0,
                        "has_ratings": link.hasRatings
                    ]
                )
                hasTrackedView = true
            }
        }
        .onTapGesture {
            // Analytics: Track link card tap (general interaction)
            Analytics.shared.trackTap(
                elementId: "link_card",
                screenName: "links",
                properties: [
                    "link_id": link.id,
                    "link_is_active": link.isActive,
                    "interaction_type": isEditingTitle ? "save_title" : "general_tap"
                ]
            )
            
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
        } else if trimmedTitle.isEmpty || trimmedTitle == link.title {
            // Analytics: Track title edit cancelled
            Analytics.shared.track(
                event: "link_title_edit_cancelled",
                properties: [
                    AnalyticsProperty.screenName: "links",
                    "link_id": link.id,
                    "reason": trimmedTitle.isEmpty ? "empty_title" : "no_change"
                ]
            )
        }
        isEditingTitle = false
        isTitleFieldFocused = false
    }
    
    private func cancelEditing() {
        // Analytics: Track explicit title edit cancellation
        Analytics.shared.track(
            event: "link_title_edit_cancelled",
            properties: [
                AnalyticsProperty.screenName: "links",
                "link_id": link.id,
                "reason": "explicit_cancel"
            ]
        )
        
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
    @State private var hasTrackedView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("How to Use Link")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom)
                    
                    // Step 1: Copy Link
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("1")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text("Copy Link")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text("Copy your unique rating link")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            Text("https://\(link.url)")
                                .frame(maxWidth: .infinity)
                                .padding(5)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button(action: {
                                // Analytics: Track link copy
                                Analytics.shared.trackTap(
                                    elementId: "copy_link_button",
                                    screenName: "link_instructions",
                                    properties: [
                                        "link_id": link.id,
                                        "link_url": link.url
                                    ]
                                )
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                UIPasteboard.general.string = "https://\(link.url)"
                                showCopiedMessage = true
                                
                                // Analytics: Track successful copy
                                Analytics.shared.track(
                                    event: "link_copied_to_clipboard",
                                    properties: [
                                        AnalyticsProperty.screenName: "link_instructions",
                                        "link_id": link.id
                                    ]
                                )
                                
                                // Reset message after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedMessage = false
                                }
                            }) {
                                Text(showCopiedMessage ? "Link Copied" : "Copy Link")
                                    .font(.system(size: 16, weight: .bold))
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
                    
                    // Step 2: Add to Story
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("2")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text("Add Link to Story")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text("Add the link to your Instagram or Snapchat story when sharing a photo or video")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .lineSpacing(2.5)
                        
                        HStack {
                            Text("Instagram")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pink.opacity(0.2))
                                .cornerRadius(6)
                                .onTapGesture {
                                    // Analytics: Track platform selection
                                    Analytics.shared.trackTap(
                                        elementId: "platform_tag",
                                        screenName: "link_instructions",
                                        properties: [
                                            "platform": "instagram",
                                            "link_id": link.id
                                        ]
                                    )
                                }
                            
                            Text("Snapchat")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(6)
                                .onTapGesture {
                                    // Analytics: Track platform selection
                                    Analytics.shared.trackTap(
                                        elementId: "platform_tag",
                                        screenName: "link_instructions",
                                        properties: [
                                            "platform": "snapchat",
                                            "link_id": link.id
                                        ]
                                    )
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Step 3: Start Earning
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            Text("3")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text("Get Ratings & Start Earning")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text("Earn $0.25 for every story rating you receive. Track your earnings in real-time")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .lineSpacing(2.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        // Analytics: Track instructions close
                        Analytics.shared.trackTap(
                            elementId: "close_button",
                            screenName: "link_instructions",
                            properties: [
                                "link_id": link.id,
                                "completion_type": "close_button"
                            ]
                        )
                        
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Analytics: Track instructions view (only once per session)
            if !hasTrackedView {
                Analytics.shared.trackScreen(
                    name: "link_instructions",
                    properties: [
                        "link_id": link.id,
                        "link_earnings": link.earnings,
                        "link_rating_count": link.ratingCount,
                        "link_is_active": link.isActive
                    ]
                )
                hasTrackedView = true
            }
        }
    }
}
