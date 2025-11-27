import SwiftUI
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

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
            UseLinkInstructionsView(link: link, viewModel: viewModel)
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
            HStack(alignment: .top) {
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
                .frame(maxWidth: .infinity, minHeight: 60)
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
                .frame(maxWidth: .infinity, minHeight: 60)
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
                        "has_ratings": link.hasRatings,
                        "has_photo": link.photoUrl != nil
                    ]
                )
                hasTrackedView = true
            }
        }
        .onTapGesture {
            Analytics.shared.trackTap(
                elementId: "link_card",
                screenName: "links",
                properties: [
                    "link_id": link.id,
                    "link_is_active": link.isActive,
                    "interaction_type": isEditingTitle ? "save_title" : "general_tap"
                ]
            )
            
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
    let viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedMessage = false
    @State private var hasTrackedView = false
    @State private var calculatorRatings = 30.0
    @State private var showExamples = false
    
    // NEW: Photo upload states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadedPhoto: UIImage?
    @State private var isUploadingPhoto = false
    @State private var hasUploadedPhoto = false // NEW: Local state for immediate UI update
    
    // Computed property to check if photo is available
    private var photoIsUploaded: Bool {
        hasUploadedPhoto || link.photoUrl != nil
    }
    
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
            if photoIsUploaded {
                calculatorSlider
            }
            ratingsRow
            earningsRow
        }
    }
    
    private var ratingsRow: some View {
        HStack {
            Text("Ratings")
                .font(.system(size: 15, weight: .medium))
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
                                        "calculated_earnings": calculatorRatings * 0.25
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
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("$\(calculatorRatings * 0.25, specifier: "%.2f")")
                .font(.system(size: 18, weight: .bold))
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
                    
                    // Step 1: Upload Photo
                    uploadPhotoStepView
                    
                    // Step 2: See Examples
                    seeExamplesStepView
                    
                    // Step 3: Copy Link
                    copyLinkStepView
                    
                    // Step 4: Add to Story
                    addToStoryStepView
                    
                    // Step 5: Start Earning
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
                                "final_calculator_earnings": calculatorRatings * 0.25,
                                "has_uploaded_photo": link.photoUrl != nil
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
                        "link_is_active": link.isActive,
                        "has_photo": link.photoUrl != nil
                    ]
                )
                hasTrackedView = true
            }
            
            // Set hasUploadedPhoto if photo already exists
            if link.photoUrl != nil {
                hasUploadedPhoto = true
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        uploadedPhoto = image
                        isUploadingPhoto = true
                        viewModel.uploadLinkPhoto(image, for: link)
                    }
                }
            }
        }
        .onChange(of: viewModel.isUploadingPhoto) { uploading in
            if !uploading && uploadedPhoto != nil {
                // Photo upload completed
                hasUploadedPhoto = true
            }
        }
    }
    
    // NEW: Upload Photo Step
    private var uploadPhotoStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("1")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Upload Photo")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text("Upload the photo that will be used in your Instagram story")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                // Photo Preview
                if viewModel.isUploadingPhoto {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        )
                } else if let photoUrl = link.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                    }
                } else if let uploadedPhoto = uploadedPhoto {
                    Image(uiImage: uploadedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                // Upload Button
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Text(photoIsUploaded ? "Change Photo" : "Upload Photo")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var seeExamplesStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("2")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(photoIsUploaded ? Color.green : Color.gray)
                
                Text("Check out Examples")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(photoIsUploaded ? .primary : .gray)
            }
            
            Text("Check out example stories")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "see_examples_button",
                    screenName: "link_instructions",
                    properties: ["link_id": link.id]
                )
                showExamples = true
            }) {
                Text("View Examples")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(photoIsUploaded ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(photoIsUploaded ? .white : Color.gray.opacity(0.7))
                    .cornerRadius(8)
            }
            .disabled(!photoIsUploaded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var copyLinkStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("3")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(photoIsUploaded ? Color.green : Color.gray)
                
                Text("Copy Link")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(photoIsUploaded ? .primary : .gray)
            }
            
            Text(photoIsUploaded ? "Copy your unique rating link" : "Upload a photo first to unlock this step")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("https://\(link.url)")
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .opacity(photoIsUploaded ? 1.0 : 0.5)
                
                Button(action: copyLink) {
                    HStack(spacing: 8) {
                        Text(showCopiedMessage ? "Link Copied" : (photoIsUploaded ? "Copy Link" : "Upload Photo First"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        showCopiedMessage ? Color.green :
                        (photoIsUploaded ? Color.blue : Color.gray.opacity(0.4))
                    )
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
    }
    
    private var addToStoryStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("4")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(photoIsUploaded ? Color.green : Color.gray)
                
                Text("Add Link to Story")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(photoIsUploaded ? .primary : .gray)
            }
            
            Text("Add the link to your Instagram story when sharing your photo")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
                .opacity(photoIsUploaded ? 1.0 : 0.6)
            
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("Make sure you add the text \"rate!\" to your link")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)
            .opacity(photoIsUploaded ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(photoIsUploaded ? 1.0 : 0.6)
    }
    
    private var startEarningStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("5")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(photoIsUploaded ? Color.green : Color.gray)
                
                Text("Start Earning")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(photoIsUploaded ? .primary : .gray)
            }
            
            Text("Earn $0.25 for every rating your story receives")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
                .opacity(photoIsUploaded ? 1.0 : 0.6)
            
            calculatorSection
                .opacity(photoIsUploaded ? 1.0 : 0.5)
                .allowsHitTesting(photoIsUploaded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(photoIsUploaded ? 1.0 : 0.6)
    }
    
    private func copyLink() {
        // Don't copy if no photo uploaded
        guard photoIsUploaded else {
            Analytics.shared.track(
                event: "copy_link_blocked_no_photo",
                properties: [
                    AnalyticsProperty.screenName: "link_instructions",
                    "link_id": link.id
                ]
            )
            return
        }
        
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
    
    private let exampleImages = ["example1", "example2", "example3", "example4"]
    
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
                                .padding(.horizontal, 70)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
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
