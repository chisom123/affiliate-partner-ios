import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI
import FirebaseStorage

// MARK: - LinksView

struct LinksView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedLinkForInstructions: RatingLink?
    @State private var showBlockedAlert = false
    @State private var blockReason: String = ""
    @State private var isCreatingLink = false

    var body: some View {
        NavigationView {
            GeometryReader { _ in
                ScrollView {
                    VStack(spacing: 20) {
                        if let affiliateData = viewModel.affiliateData, !affiliateData.canCreateLinks {
                            blockedMessageView
                        }

                        if viewModel.isInitialDataLoad && viewModel.ratingLinks.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView().scaleEffect(1.2).tint(.gray)
                            }
                            .padding(.vertical, 100).frame(maxWidth: .infinity)

                        } else if viewModel.ratingLinks.isEmpty {
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Text("No Links Yet").font(.system(size: 20, weight: .semibold))
                                    Text("Create your first link").font(.system(size: 16)).foregroundColor(.secondary).multilineTextAlignment(.center)
                                }
                                Button(action: { createLinkWithBlockCheck(source: "empty_state") }) {
                                    Text("New Link").font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white).padding(.horizontal, 28).padding(.vertical, 12)
                                        .background(canCreateLinks ? Color.blue : Color.gray).cornerRadius(200)
                                }
                                .disabled(viewModel.isLoading || !canCreateLinks || isCreatingLink)
                                .padding(.top)
                            }
                            .padding(.vertical, 50).frame(maxWidth: .infinity).padding(.horizontal, 20)
                            .background(Color.gray.opacity(0.05)).cornerRadius(12)

                        } else {
                            ForEach(viewModel.ratingLinks.sorted(by: { $0.createdAt > $1.createdAt })) { link in
                                LinkCard(
                                    link: link,
                                    onUseLink: { selectedLinkForInstructions = link },
                                    onUpdateTitle: { newTitle in viewModel.updateLinkTitle(link: link, newTitle: newTitle) }
                                )
                            }
                        }
                    }
                    .padding(.vertical).padding(.horizontal)
                }
            }
            .navigationTitle("Links")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { createLinkWithBlockCheck(source: "toolbar") }) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                            .foregroundColor(canCreateLinks ? Color.blue : Color.gray)
                    }
                    .disabled(viewModel.isLoading || !canCreateLinks || isCreatingLink)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Limit Reached", isPresented: $showBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(blockReason) }
        .onAppear { viewModel.loadData() }
        .sheet(item: $selectedLinkForInstructions) { link in
            UseLinkInstructionsView(link: link, viewModel: viewModel)
        }
    }

    private var canCreateLinks: Bool { viewModel.affiliateData?.canCreateLinks ?? false }

    private var blockedMessageView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 20)).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Link Creation Paused").font(.system(size: 16, weight: .semibold))
                Text("Please contact support").font(.system(size: 14)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding().background(Color.orange.opacity(0.1)).cornerRadius(8)
    }

    private func createLinkWithBlockCheck(source: String) {
        guard !isCreatingLink else { return }
        guard canCreateLinks else {
            blockReason = "Link creation is currently paused for your account."
            showBlockedAlert = true
            return
        }
        isCreatingLink = true
        viewModel.checkDailyLimit { canCreate, _ in
            defer { isCreatingLink = false }
            if !canCreate {
                blockReason = "You've reached your daily limit of 1 link. Try again tomorrow."
                showBlockedAlert = true
                return
            }
            viewModel.createNewLink { newLink in
                selectedLinkForInstructions = newLink
            }
        }
    }
}

// MARK: - LinkCard

struct LinkCard: View {
    let link: RatingLink
    let onUseLink: () -> Void
    let onUpdateTitle: (String) -> Void

    @State private var isEditingTitle = false
    @State private var editingTitle = ""
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
                        .onTapGesture { isEditingTitle = true; editingTitle = link.title }
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
                .background(Color.green.opacity(0.1)).cornerRadius(6)

                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(link.averageRating, specifier: "%.1f")").font(.system(size: 18, weight: .bold))
                            .foregroundColor(link.hasRatings ? .orange : .gray)
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Text("★").font(.system(size: 13))
                                    .foregroundColor(link.hasRatings && Double(star) <= link.averageRating.rounded() ? .orange : .gray.opacity(0.4))
                            }
                        }
                    }
                    Text("\(link.ratingCount) rating\(link.ratingCount != 1 ? "s" : "")").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.orange.opacity(0.1)).cornerRadius(6)
            }

            if link.isActive {
                Button(action: onUseLink) {
                    Text("Use Link").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
            }
        }
        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
        .onTapGesture { if isEditingTitle { saveTitle() } }
    }

    private func saveTitle() {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != link.title { onUpdateTitle(trimmed) }
        isEditingTitle = false
        isTitleFieldFocused = false
    }

    private func timeAgoString(from date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        let minutes = Int(diff / 60); let hours = Int(diff / 3600); let days = Int(diff / 86400)
        if minutes < 1 { return "Just now" } else if minutes < 60 { return "\(minutes)m ago" }
        else if hours < 24 { return "\(hours)h ago" } else { return "\(days)d ago" }
    }
}

// MARK: - UseLinkInstructionsView

struct UseLinkInstructionsView: View {
    let link: RatingLink
    let viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCopiedMessage = false
    @State private var showExamples = false
    @StateObject private var pricingCalculator = AffiliatePricingCalculator.shared
    @State private var calculatorRatings = 30.0

    // Story photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadedPhoto: UIImage?

    // Bonus photo
    @State private var selectedBonusPhotoItem: PhotosPickerItem?
    @State private var uploadedBonusPhoto: UIImage?
    @State private var bonusPhotoError = ""

    private var currentLink: RatingLink {
        viewModel.ratingLinks.first(where: { $0.id == link.id }) ?? link
    }

    private var storyPhotoUploaded: Bool { currentLink.photoUrl != nil || uploadedPhoto != nil }
    private var bonusPhotoUploaded: Bool { !(currentLink.bonusPhotoUrl?.isEmpty ?? true) || uploadedBonusPhoto != nil }
    private var canCopyLink: Bool { currentLink.isReadyToShare }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("How to Use Link").font(.system(size: 24, weight: .bold)).padding(.bottom)

                    storyPhotoStep
                    bonusPhotoStep
                    copyLinkStep
                    addToStoryStep
                    startEarningStep
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }.foregroundColor(.black).fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showExamples) { ExamplesView() }
        .onAppear {
            // Reflect any already-uploaded photos
            if link.photoUrl != nil, uploadedPhoto == nil { /* listener covers it */ }
        }
        // Story photo picker
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        uploadedPhoto = image
                        viewModel.uploadLinkPhoto(image, for: link, assetIdentifier: newItem?.itemIdentifier)
                    }
                }
            }
        }
        // Bonus photo picker — prevent same-as-story photo
        .onChange(of: selectedBonusPhotoItem) { newItem in
            Task {
                let newIdentifier   = newItem?.itemIdentifier
                let storyIdentifier = selectedPhotoItem?.itemIdentifier ?? currentLink.photoAssetIdentifier

                // Block same photo being used for both slots
                if let newId = newIdentifier, let storyId = storyIdentifier, newId == storyId {
                    await MainActor.run {
                        selectedBonusPhotoItem = nil
                        bonusPhotoError = "Bonus photo must be different from your story photo."
                    }
                    return
                }

                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        bonusPhotoError = ""
                        uploadedBonusPhoto = image
                        viewModel.uploadBonusPhoto(image, for: link, identifier: newItem?.itemIdentifier) { success in
                            if !success { uploadedBonusPhoto = nil }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Story Photo

    private var storyPhotoStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("1").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Upload Story Photo").font(.system(size: 18, weight: .semibold))
            }
            Text("Upload the photo you'll share in your Instagram story")
                .font(.system(size: 16)).foregroundColor(.gray)

            VStack(spacing: 12) {
                if viewModel.isUploadingPhoto {
                    photoPlaceholder.overlay(ProgressView().scaleEffect(1.2))
                } else if let urlString = currentLink.photoUrl, !urlString.isEmpty {
                    AsyncImage(url: URL(string: urlString)) { img in
                        img.resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: { photoPlaceholder }
                } else if let photo = uploadedPhoto {
                    Image(uiImage: photo).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    photoPlaceholder
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text(storyPhotoUploaded ? "Change Photo" : "Upload Photo")
                        .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    // MARK: - Step 2: Bonus Photo

    private var bonusPhotoStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("2").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Upload Bonus Photo").font(.system(size: 18, weight: .semibold))
            }
            Text(storyPhotoUploaded
                 ? "Upload a different bonus photo your followers will unlock"
                 : "Upload your story photo first to unlock this step")
                .font(.system(size: 16)).foregroundColor(.gray)

            if storyPhotoUploaded {
                VStack(spacing: 12) {
                    if viewModel.isUploadingBonusPhoto {
                        photoPlaceholder.overlay(ProgressView().scaleEffect(1.2))
                    } else if let urlString = currentLink.bonusPhotoUrl, !urlString.isEmpty {
                        AsyncImage(url: URL(string: urlString)) { img in
                            img.resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: { photoPlaceholder }
                    } else if let photo = uploadedBonusPhoto {
                        Image(uiImage: photo).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        photoPlaceholder
                    }

                    PhotosPicker(selection: $selectedBonusPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Text(bonusPhotoUploaded ? "Change Bonus Photo" : "Upload Bonus Photo")
                            .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    }
                    .disabled(viewModel.isUploadingBonusPhoto)

                    if !bonusPhotoError.isEmpty {
                        Text(bonusPhotoError).font(.system(size: 14, weight: .semibold)).foregroundColor(.red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
        .opacity(storyPhotoUploaded ? 1.0 : 0.5)
    }

    // MARK: - Step 3: Copy Link

    private var copyLinkStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("3").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Copy Link").font(.system(size: 18, weight: .semibold))
            }
            Text(canCopyLink
                 ? "Copy your unique rating link"
                 : (storyPhotoUploaded ? "Upload your bonus photo to unlock your link" : "Upload both photos to unlock your link"))
                .font(.system(size: 16)).foregroundColor(.gray)

            Text("https://\(currentLink.url)")
                .frame(maxWidth: .infinity).padding(15)
                .background(Color.gray.opacity(0.1)).cornerRadius(8)
                .opacity(canCopyLink ? 1.0 : 0.4)

            Button(action: copyLink) {
                Text(showCopiedMessage ? "Link Copied" : (canCopyLink ? "Copy Link" : "Upload Both Photos First"))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(showCopiedMessage ? Color.green : (canCopyLink ? Color.blue : Color.gray.opacity(0.4)))
                    .foregroundColor(canCopyLink ? .white : Color.gray.opacity(0.7)).cornerRadius(8)
            }
            .disabled(!canCopyLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
        .opacity(canCopyLink ? 1.0 : 0.5)
    }

    // MARK: - Step 4: Add to Story

    private var addToStoryStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("4").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Add Link to Story").font(.system(size: 18, weight: .semibold))
            }
            Text("Add the link to your Instagram story when sharing your photo")
                .font(.system(size: 16)).foregroundColor(.gray)
            Button(action: { showExamples = true }) {
                Text("See Examples").font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.blue).foregroundColor(.white).cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    // MARK: - Step 5: Start Earning

    private var startEarningStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("5").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Start Earning").font(.system(size: 18, weight: .semibold))
            }
            Text("Make \(pricingCalculator.formatEarnings(pricingCalculator.getEarningsPerRating())) every time your story is rated")
                .font(.system(size: 16)).foregroundColor(.gray)
            earningsCalculator
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    // MARK: - Earnings Calculator

    private var earningsCalculator: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Ratings").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(calculatorRatings))").font(.system(size: 18, weight: .bold))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat((calculatorRatings - 10) / 90), height: 6)
                    Circle().fill(Color.blue).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: geometry.size.width * CGFloat((calculatorRatings - 10) / 90) - 11)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let pct = max(0, min(1, value.location.x / geometry.size.width))
                            calculatorRatings = round((10 + pct * 90) / 10) * 10
                        })
                }
            }.frame(height: 24)
            HStack {
                Text("Earnings").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(pricingCalculator.formatEarnings(calculatorRatings * pricingCalculator.getEarningsPerRating()))
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
            }
        }
        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    // MARK: - Helpers

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)).frame(height: 200)
            .overlay(Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.gray))
    }

    private func copyLink() {
        guard canCopyLink else { return }
        UIPasteboard.general.string = "https://\(currentLink.url)"
        showCopiedMessage = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopiedMessage = false }
    }
}

// MARK: - ExamplesView

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
                            Image(exampleImages[index]).resizable().aspectRatio(contentMode: .fit)
                                .tag(index).cornerRadius(8).padding(.horizontal, 70)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    HStack {
                        Button(action: { withAnimation { currentIndex = max(0, currentIndex - 1) } }) {
                            Image(systemName: "chevron.left").font(.title2).fontWeight(.bold)
                                .foregroundColor(currentIndex > 0 ? .blue : .gray).padding()
                        }
                        .disabled(currentIndex == 0)
                        Spacer()
                        Button(action: { withAnimation { currentIndex = min(exampleImages.count - 1, currentIndex + 1) } }) {
                            Image(systemName: "chevron.right").font(.title2).fontWeight(.bold)
                                .foregroundColor(currentIndex < exampleImages.count - 1 ? .blue : .gray).padding()
                        }
                        .disabled(currentIndex == exampleImages.count - 1)
                    }
                }
                Text("\(currentIndex + 1) of \(exampleImages.count)")
                    .foregroundColor(.gray).font(.system(size: 15, weight: .semibold)).padding(.vertical, 8)
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
