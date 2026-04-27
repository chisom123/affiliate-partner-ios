import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI
import FirebaseStorage

struct LinksView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedLinkForInstructions: RatingLink?
    @State private var showBlockedAlert = false
    @State private var dailyLinksRemaining: Int? = nil
    @State private var blockReason: String = ""
    @State private var isCreatingLink = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // Show blocked message if applicable
                        if let affiliateData = viewModel.affiliateData, !affiliateData.canCreateLinks {
                            blockedMessageView
                        }
                        
                        // Show loading state during initial load
                        if viewModel.isInitialDataLoad && viewModel.ratingLinks.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.gray)
                            }
                            .padding(.vertical, 100)
                            .frame(maxWidth: .infinity)
                        } else if viewModel.ratingLinks.isEmpty {
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Text("No Story Links Yet")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Create your first story link")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                Button(action: { createLinkWithBlockCheck(source: "empty_state") }) {
                                    HStack(spacing: 8) {
                                        Text("New Link")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(canCreateLinks ? Color.blue : Color.gray)
                                    .cornerRadius(200)
                                }
                                .disabled(viewModel.isLoading || !canCreateLinks || isCreatingLink)
                                .opacity((viewModel.isLoading || !canCreateLinks) ? 0.6 : 1.0)
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
                                                "link_is_active": link.isActive,
                                                "has_photo": link.photoUrl != nil
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
                    Button(action: { createLinkWithBlockCheck(source: "toolbar") }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(canCreateLinks ? Color.blue : Color.gray)
                    }
                    .disabled(viewModel.isLoading || !canCreateLinks || isCreatingLink)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Daily Limit Reached", isPresented: $showBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(blockReason)
        }
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
                    "average_earnings_per_link": viewModel.ratingLinks.isEmpty ? 0 : totalEarnings / Double(viewModel.ratingLinks.count),
                    "can_create_links": canCreateLinks
                ]
            )
            
            viewModel.loadData()
        }
        .sheet(item: $selectedLinkForInstructions) { link in
            UseLinkInstructionsView(link: link, viewModel: viewModel)
        }
    }
    
    // Computed property to check if user can create links
    private var canCreateLinks: Bool {
        viewModel.affiliateData?.canCreateLinks ?? false
    }
    
    // Blocked message view
    private var blockedMessageView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Link Creation Paused")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Please contact support")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // Helper function to handle link creation with block check
    private func createLinkWithBlockCheck(source: String) {
        guard !isCreatingLink else { return }
        guard canCreateLinks else {
            blockReason = "Link creation is currently paused for your account. Please contact support for assistance."
            showBlockedAlert = true
            
            Analytics.shared.track(
                event: "blocked_user_attempted_link_creation",
                properties: [AnalyticsProperty.screenName: "links", "creation_source": source, "blocked_reason": "canCreateLinks_false"]
            )
            return
        }
        
        isCreatingLink = true
        
        // Check daily limit before proceeding
        viewModel.checkDailyLimit { canCreate, remaining in
            defer { isCreatingLink = false }
            dailyLinksRemaining = remaining
            
            if !canCreate {
                blockReason = "You've reached your daily limit of 1 link. Please try again tomorrow."
                showBlockedAlert = true
                
                Analytics.shared.track(
                    event: "blocked_user_attempted_link_creation",
                    properties: [AnalyticsProperty.screenName: "links", "creation_source": source, "blocked_reason": "daily_limit_reached", "remaining": 0]
                )
                return
            }
            
            Analytics.shared.trackTap(
                elementId: source == "toolbar" ? "add_link_toolbar_button" : "create_first_link_button",
                screenName: "links",
                properties: ["total_links": viewModel.ratingLinks.count, "user_state": viewModel.ratingLinks.isEmpty ? "empty" : "has_links", "daily_remaining": remaining]
            )
            
            viewModel.createNewLink { newLink in
                selectedLinkForInstructions = newLink
                
                if let link = newLink {
                    // Update remaining count
                    dailyLinksRemaining = max(0, (dailyLinksRemaining ?? 0) - 1)
                    
                    Analytics.shared.track(
                        event: viewModel.ratingLinks.count == 1 ? "first_link_created" : "link_created",
                        properties: [AnalyticsProperty.screenName: "links", "link_id": link.id, "link_title": link.title, "total_links_after": viewModel.ratingLinks.count, "creation_source": source, "daily_remaining_after": dailyLinksRemaining ?? 0]
                    )
                }
            }
        }
    }
}

// MARK: - LinkCard (unchanged)

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
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    if isEditingTitle {
                        TextField("Link Title", text: $editingTitle)
                            .font(.system(size: 16, weight: .bold))
                            .padding(.bottom, 8)
                            .background(VStack { Spacer(); Capsule().frame(height: 1).foregroundColor(Color(hex: "C8C8C8")) })
                            .focused($isTitleFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { saveTitle() }
                            .padding(.bottom, 8)
                            .onAppear {
                                editingTitle = link.title
                                isTitleFieldFocused = true
                                Analytics.shared.track(event: "link_title_edit_started", properties: [AnalyticsProperty.screenName: "links", "link_id": link.id, "current_title": link.title])
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
                            Analytics.shared.trackTap(elementId: "link_title_edit", screenName: "links", properties: ["link_id": link.id, "current_title": link.title])
                            startEditingTitle()
                        }
                    }
                    Text(timeAgoString(from: link.createdAt)).font(.system(size: 12)).foregroundColor(.gray)
                }
                if !isEditingTitle {
                    Spacer()
                    Image(systemName: link.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(link.isActive ? .green : .red)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("$\(link.earnings, specifier: "%.2f")").font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                    Text("Earned").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(link.averageRating, specifier: "%.1f")").font(.system(size: 18, weight: .bold)).foregroundColor(link.hasRatings ? .orange : .gray)
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Text("★").font(.system(size: 14)).foregroundColor(link.hasRatings && Double(star) <= link.averageRating.rounded() ? .orange : .gray.opacity(0.5))
                            }
                        }
                    }
                    Text("\(link.ratingCount) rating\(link.ratingCount != 1 ? "s" : "")").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
            if link.isActive {
                Button(action: { onUseLink() }) {
                    Text("Use Link").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            if !hasTrackedView {
                Analytics.shared.track(
                    event: "link_card_viewed",
                    properties: [AnalyticsProperty.screenName: "links", "link_id": link.id, "link_earnings": link.earnings, "link_rating_count": link.ratingCount, "link_average_rating": link.averageRating, "link_is_active": link.isActive, "link_age_days": Calendar.current.dateComponents([.day], from: link.createdAt, to: Date()).day ?? 0, "has_ratings": link.hasRatings, "has_photo": link.photoUrl != nil]
                )
                hasTrackedView = true
            }
        }
        .onTapGesture {
            Analytics.shared.trackTap(elementId: "link_card", screenName: "links", properties: ["link_id": link.id, "link_is_active": link.isActive, "interaction_type": isEditingTitle ? "save_title" : "general_tap"])
            if isEditingTitle { saveTitle() }
        }
    }
    
    private func startEditingTitle() { isEditingTitle = true; editingTitle = link.title }
    
    private func saveTitle() {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != link.title {
            onUpdateTitle(trimmedTitle)
        } else {
            Analytics.shared.track(event: "link_title_edit_cancelled", properties: [AnalyticsProperty.screenName: "links", "link_id": link.id, "reason": trimmedTitle.isEmpty ? "empty_title" : "no_change"])
        }
        isEditingTitle = false
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

// MARK: - UseLinkInstructionsView

struct UseLinkInstructionsView: View {
    let link: RatingLink
    let viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedMessage = false
    @State private var hasTrackedView = false
    @State private var calculatorRatings = 30.0
    @State private var showExamples = false
    @StateObject private var pricingCalculator = AffiliatePricingCalculator.shared
    
    private var copyLinkStepNumber: Int { hasBonusPhoto ? 3 : 4 }
    private var addToStoryStepNumber: Int { hasBonusPhoto ? 4 : 5 }
    private var startEarningStepNumber: Int { hasBonusPhoto ? 5 : 6 }

    // Photo upload states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadedPhoto: UIImage?
    @State private var isUploadingPhoto = false
    @State private var hasUploadedPhoto = false

    // Theme selection states
    @State private var showThemeSelection = false
    @State private var selectedTheme: String?

    // Bonus photo state
    @State private var hasBonusPhoto = false
    @State private var showBonusPhotoView = false

    private var photoIsUploaded: Bool { hasUploadedPhoto || link.photoUrl != nil }
    private var themeIsSelected: Bool { selectedTheme != nil || link.theme != nil }

    // Copy link is now gated on photo + theme + bonus photo
    private var canCopyLink: Bool { themeIsSelected && hasBonusPhoto }

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
            calculatorSlider
            ratingsRow
            earningsRow
        }
        .padding(.horizontal, 5)
    }

    private var ratingsRow: some View {
        HStack {
            Text("Ratings").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text("\(Int(calculatorRatings))").font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
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
                                        "calculated_earnings": calculatorRatings * pricingCalculator.getEarningsPerRating(),
                                        "earnings_per_rating": pricingCalculator.getEarningsPerRating()
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
            Text("Earnings").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(pricingCalculator.formatEarnings(calculatorRatings * pricingCalculator.getEarningsPerRating()))
                .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Text("How to Use Link")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom)

                    uploadPhotoStepView
                    selectThemeStepView
                    if !hasBonusPhoto { bonusPhotoStepView }
                    copyLinkStepView
                    addToStoryStepView
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
                            properties: ["link_id": link.id, "completion_type": "close_button", "final_calculator_ratings": Int(calculatorRatings), "final_calculator_earnings": calculatorRatings * pricingCalculator.getEarningsPerRating(), "earnings_per_rating": pricingCalculator.getEarningsPerRating(), "has_uploaded_photo": link.photoUrl != nil, "has_selected_theme": themeIsSelected, "has_bonus_photo": hasBonusPhoto]
                        )
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showExamples) { ExamplesView() }
        .sheet(isPresented: $showThemeSelection) {
            ThemeSelectionView(selectedTheme: $selectedTheme)
                .onDisappear {
                    if let theme = selectedTheme { viewModel.updateLinkTheme(link: link, theme: theme) }
                }
        }
        .sheet(isPresented: $showBonusPhotoView, onDismiss: {
            loadBonusPhotoStatus()
        }) {
            NavigationView {
                UnseenPhotoView(unseenPhotoUrl: nil, onUploadSuccess: {
                    hasBonusPhoto = true
                })
                .navigationBarItems(trailing: Button("Done") {
                    showBonusPhotoView = false
                }
                .fontWeight(.semibold))
            }
        }
        .onAppear {
            if !hasTrackedView {
                Analytics.shared.trackScreen(name: "link_instructions", properties: ["link_id": link.id, "link_earnings": link.earnings, "link_rating_count": link.ratingCount, "link_is_active": link.isActive, "has_photo": link.photoUrl != nil, "has_theme": link.theme != nil])
                hasTrackedView = true
            }
            if link.photoUrl != nil { hasUploadedPhoto = true }
            if let theme = link.theme { selectedTheme = theme }
            loadBonusPhotoStatus()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await MainActor.run { uploadedPhoto = image; isUploadingPhoto = true; viewModel.uploadLinkPhoto(image, for: link) }
                }
            }
        }
        .onChange(of: viewModel.isUploadingPhoto) { uploading in
            if !uploading && uploadedPhoto != nil { hasUploadedPhoto = true }
        }
    }

    // ── Load bonus photo status from affiliate document ───────────────────────
    private func loadBonusPhotoStatus() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("affiliates").document(userId).getDocument { document, _ in
            DispatchQueue.main.async {
                let url = document?.data()?["unseenPhotoUrl"] as? String
                hasBonusPhoto = !(url?.isEmpty ?? true)
                Analytics.shared.track(
                    event: "bonus_photo_status_loaded",
                    properties: [AnalyticsProperty.screenName: "link_instructions", "has_bonus_photo": hasBonusPhoto]
                )
            }
        }
    }

    // MARK: - Step Views

    private var uploadPhotoStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("1").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Upload Photo").font(.system(size: 18, weight: .semibold))
            }
            Text("Upload the photo that will be used in your Instagram story")
                .font(.system(size: 16)).foregroundColor(.gray)

            VStack(spacing: 12) {
                if viewModel.isUploadingPhoto {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(height: 200)
                        .overlay(ProgressView().scaleEffect(1.2).progressViewStyle(CircularProgressViewStyle(tint: .black)))
                } else if let photoUrl = link.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image.resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(height: 200)
                    }
                } else if let uploadedPhoto = uploadedPhoto {
                    Image(uiImage: uploadedPhoto).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)).frame(height: 200)
                        .overlay(VStack(spacing: 8) { Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.gray) })
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text(photoIsUploaded ? "Change Photo" : "Upload Photo")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var selectThemeStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("2").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Pick a Theme").font(.system(size: 18, weight: .semibold))
            }
            Text(photoIsUploaded ? "Give your photo a theme" : "Upload a photo first to unlock this step")
                .font(.system(size: 16)).foregroundColor(.gray)

            VStack(spacing: 12) {
                if let theme = selectedTheme ?? link.theme {
                    HStack {
                        Image(systemName: "tag.fill").font(.system(size: 16)).foregroundColor(.blue)
                        Text(theme).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(.green)
                    }
                    .padding().background(Color.blue.opacity(0.1)).cornerRadius(8)
                } else {
                    HStack {
                        Image(systemName: "tag").font(.system(size: 16)).foregroundColor(.gray)
                        Text("No theme selected").font(.system(size: 16)).foregroundColor(.gray)
                        Spacer()
                    }
                    .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                }

                Button(action: {
                    Analytics.shared.trackTap(elementId: themeIsSelected ? "change_theme_button" : "select_theme_button", screenName: "link_instructions", properties: ["link_id": link.id, "current_theme": selectedTheme ?? link.theme ?? "none"])
                    showThemeSelection = true
                }) {
                    Text(themeIsSelected ? "Change Theme" : (photoIsUploaded ? "Select Theme" : "Upload Photo First"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(photoIsUploaded ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(photoIsUploaded ? .white : Color.gray.opacity(0.7))
                        .cornerRadius(8)
                }
                .disabled(!photoIsUploaded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(photoIsUploaded ? 1.0 : 0.5)
    }

    // ── Step 3: Bonus Photo (new) ─────────────────────────────────────────────
    private var bonusPhotoStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("3").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Upload Bonus Photo").font(.system(size: 18, weight: .semibold))
            }

            Text(themeIsSelected
                 ? "Upload a bonus photo for your followers to rate"
                 : "Select a theme first to unlock this step")
                .font(.system(size: 16)).foregroundColor(.gray)

            if hasBonusPhoto {
                HStack {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(.green)
                    Text("Bonus photo uploaded").font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                    Spacer()
                }
                .padding().background(Color.green.opacity(0.1)).cornerRadius(8)
            }

            Button(action: {
                Analytics.shared.trackTap(
                    elementId: hasBonusPhoto ? "change_bonus_photo_button" : "upload_bonus_photo_button",
                    screenName: "link_instructions",
                    properties: ["link_id": link.id, "has_bonus_photo": hasBonusPhoto]
                )
                showBonusPhotoView = true
            }) {
                Text(hasBonusPhoto ? "Change Bonus Photo" : (themeIsSelected ? "Upload Bonus Photo" : "Select Theme First"))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(themeIsSelected ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(themeIsSelected ? .white : Color.gray.opacity(0.7))
                    .cornerRadius(8)
            }
            .disabled(!themeIsSelected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(themeIsSelected ? 1.0 : 0.5)
    }

    // ── Step 4: Copy Link (gated on bonus photo) ──────────────────────────────
    private var copyLinkStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("\(copyLinkStepNumber)").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Copy Link").font(.system(size: 18, weight: .semibold)).foregroundColor(.primary)
            }

            Text(canCopyLink
                 ? "Copy your unique rating link"
                 : (!themeIsSelected ? "Select a theme first to unlock this step" : "Upload a bonus photo first to unlock your link"))
                .font(.system(size: 16)).foregroundColor(.gray)

            VStack(spacing: 12) {
                Text("https://\(link.url)")
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .opacity(canCopyLink ? 1.0 : 0.5)
                
                Button(action: copyLink) {
                    Text(showCopiedMessage ? "Link Copied" : (canCopyLink ? "Copy Link" : (!themeIsSelected ? "Select Theme First" : "Upload Bonus Photo First")))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(showCopiedMessage ? Color.green : (canCopyLink ? Color.blue : Color.gray.opacity(0.4)))
                        .foregroundColor(canCopyLink ? .white : Color.gray.opacity(0.7))
                        .cornerRadius(8)
                }
                .disabled(!canCopyLink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(canCopyLink ? 1.0 : 0.5)
    }

    private var addToStoryStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("\(addToStoryStepNumber)").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Add Link to Story").font(.system(size: 18, weight: .semibold)).foregroundColor(.primary)
            }
            Text("Add the link to your Instagram story when sharing your photo")
                .font(.system(size: 16)).foregroundColor(.gray).lineSpacing(2.5)
            Button(action: {
                Analytics.shared.trackTap(elementId: "see_examples_button", screenName: "link_instructions", properties: ["link_id": link.id])
                showExamples = true
            }) {
                Text("See Examples").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.blue).foregroundColor(.white).cornerRadius(8)
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
                Text("\(startEarningStepNumber)").font(.system(size: 22, weight: .bold)).foregroundColor(Color.green)
                Text("Start Earning").font(.system(size: 18, weight: .semibold)).foregroundColor(.primary)
            }
            Text("Earn \(pricingCalculator.formatEarnings(pricingCalculator.getEarningsPerRating())) for every rating your story receives")
                .font(.system(size: 16)).foregroundColor(.gray).lineSpacing(2.5)
            calculatorSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func copyLink() {
        guard canCopyLink else {
            Analytics.shared.track(event: "copy_link_blocked_no_bonus_photo", properties: [AnalyticsProperty.screenName: "link_instructions", "link_id": link.id])
            return
        }
        Analytics.shared.trackTap(elementId: "copy_link_button", screenName: "link_instructions", properties: ["link_id": link.id, "link_url": link.url])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIPasteboard.general.string = "https://\(link.url)"
        showCopiedMessage = true
        Analytics.shared.track(event: "link_copied_to_clipboard", properties: [AnalyticsProperty.screenName: "link_instructions", "link_id": link.id])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopiedMessage = false }
    }
}

// MARK: - ExamplesView (unchanged)

struct ExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    private let exampleImages = ["explain1", "example1", "example2"]

    var body: some View {
        NavigationView {
            VStack {
                Text("Example Stories").font(.system(size: 24, weight: .bold)).padding(.vertical)
                ZStack {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<exampleImages.count, id: \.self) { index in
                            Image(exampleImages[index]).resizable().aspectRatio(contentMode: .fit).tag(index).cornerRadius(8).padding(.horizontal, 70)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    HStack {
                        Button(action: { withAnimation { currentIndex = max(0, currentIndex - 1) } }) {
                            Image(systemName: "chevron.left").font(.title2).fontWeight(.bold).foregroundColor(currentIndex > 0 ? .blue : .gray).padding()
                        }
                        .disabled(currentIndex == 0)
                        Spacer()
                        Button(action: { withAnimation { currentIndex = min(exampleImages.count - 1, currentIndex + 1) } }) {
                            Image(systemName: "chevron.right").font(.title2).fontWeight(.bold).foregroundColor(currentIndex < exampleImages.count - 1 ? .blue : .gray).padding()
                        }
                        .disabled(currentIndex == exampleImages.count - 1)
                    }
                }
                Text("\(currentIndex + 1) of \(exampleImages.count)").foregroundColor(.gray).font(.system(size: 15, weight: .semibold)).padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }.foregroundColor(.black).fontWeight(.semibold)
                }
            }
        }
    }
}
