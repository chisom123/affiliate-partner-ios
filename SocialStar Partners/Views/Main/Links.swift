import SwiftUI
import FirebaseFirestore

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
                                    
                                    Text("Create your first story rating link")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: {
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
                                .opacity(
                                    viewModel.isLoading ? 0.6 : 1.0
                                )
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
                            .foregroundColor(Color.blue)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
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
                            .padding(.bottom, 8)
                            .background(
                                VStack {
                                    Spacer()
                                    Capsule()
                                        .frame(height: 1)
                                        .foregroundColor(Color(hex: "C8C8C8"))
                                }
                            )
                            .focused($isTitleFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                saveTitle()
                            }
                            .padding(.bottom, 8)
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
            
            HStack(spacing: 16) {
                // Earnings Section
                VStack(alignment: .center, spacing: 4) {
                    Text("$\(link.earnings, specifier: "%.2f")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    Text("Earned")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)  // Fixed height for consistency
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                // Rating Section
                VStack(alignment: .center, spacing: 4) {
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
                    
                    Text("\(link.ratingCount) rating\(link.ratingCount != 1 ? "s" : "")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)  // Fixed height for consistency
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
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
    @State private var calculatorRatings = 30.0
    @State private var showExamples = false
    
    // Calculator section as a computed property to reduce complexity
    private var calculatorSection: some View {
        VStack(spacing: 15) {
            calculatorContent
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var calculatorContent: some View {
        VStack(spacing: 18) {
            ratingsRow
            calculatorSlider
            earningsRow
        }
    }
    
    private var ratingsRow: some View {
        HStack {
            Text("Ratings")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(Int(calculatorRatings))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private var calculatorSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat((calculatorRatings - 10) / (100 - 10)), height: 6)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                    )
                    .offset(x: geometry.size.width * CGFloat((calculatorRatings - 10) / (100 - 10)) - 12)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percent = max(0, min(1, value.location.x / geometry.size.width))
                                let newValue = 10 + (percent * (100 - 10))
                                calculatorRatings = round(newValue / 10) * 10
                            }
                            .onEnded { _ in
                                Analytics.shared.track(
                                    event: "earnings_calculator_used",
                                    properties: [
                                        AnalyticsProperty.screenName: "link_instructions",
                                        "link_id": link.id,
                                        "calculated_ratings": Int(calculatorRatings),
                                        "calculated_earnings": calculatorRatings * 0.50
                                    ]
                                )
                            }
                    )
            }
        }
        .frame(height: 24)
    }
    
    private var earningsRow: some View {
        HStack {
            Text("Earnings")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("$\(calculatorRatings * 0.50, specifier: "%.2f")")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.green)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Text("How to Use Link")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom)
                    
                    // Step 1: Copy Link
                    copyLinkStepView
                    
                    // Step 2: Add to Story
                    addToStoryStepView
                    
                    // Step 3: Start Earning
                    startEarningStepView
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Analytics.shared.trackTap(
                            elementId: "close_button",
                            screenName: "link_instructions",
                            properties: [
                                "link_id": link.id,
                                "completion_type": "close_button",
                                "final_calculator_ratings": Int(calculatorRatings),
                                "final_calculator_earnings": calculatorRatings * 0.50
                            ]
                        )
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showExamples) {
            ExamplesView()
        }
        .onAppear {
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
    
    private var copyLinkStepView: some View {
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
                
                Button(action: copyLink) {
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
    }
    
    private var addToStoryStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("2")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Add Link to Story")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text("Add the link to your Instagram story when sharing a photo or video")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
            
            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "see_examples_button",
                    screenName: "link_instructions",
                    properties: ["link_id": link.id]
                )
                showExamples = true
            }) {
                HStack(spacing: 4) {
                    Text("See Examples")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var startEarningStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("3")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Start Earning")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text("Earn $0.50 for every rating your story receives")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
            
            calculatorSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func copyLink() {
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
        
        Analytics.shared.track(
            event: "link_copied_to_clipboard",
            properties: [
                AnalyticsProperty.screenName: "link_instructions",
                "link_id": link.id
            ]
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedMessage = false
        }
    }
}

struct ExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    
    // Replace with your actual screenshot names
    private let exampleImages = ["example1", "example2", "example3", "example4"] // Your screenshot asset names
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Example Stories")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.vertical)
                
                ZStack {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<exampleImages.count, id: \.self) { index in
                            Image(exampleImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .tag(index)
                                .cornerRadius(8)
                                .padding(.horizontal, 70) // Add padding to prevent overlap
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Navigation arrows overlaid on center sides
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentIndex = max(0, currentIndex - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(currentIndex > 0 ? .blue : .gray)
                                .padding()
                        }
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentIndex = min(exampleImages.count - 1, currentIndex + 1)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(currentIndex < exampleImages.count - 1 ? .blue : .gray)
                                .padding()
                        }
                        .disabled(currentIndex == exampleImages.count - 1)
                    }
                }
                
                // Page indicator below the image
                Text("\(currentIndex + 1) of \(exampleImages.count)")
                    .foregroundColor(.gray)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.vertical, 8)
            }
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
}
