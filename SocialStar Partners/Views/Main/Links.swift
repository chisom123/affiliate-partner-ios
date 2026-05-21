// LinksView.swift — pay-per-view UI, no themes, silent AI scoring

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI
import FirebaseStorage
import FirebaseFunctions

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
                                LinkCard(link: link, onUseLink: { selectedLinkForInstructions = link })
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(link.title).font(.system(size: 16, weight: .bold))
                    Text(timeAgoString(from: link.createdAt)).font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: link.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(link.isActive ? .green : .red)
            }

            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("$\(link.earnings, specifier: "%.2f")").font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                    Text("Earned").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.green.opacity(0.1)).cornerRadius(6)

                VStack(alignment: .center, spacing: 4) {
                    Text("\(link.totalPageViews)").font(.system(size: 18, weight: .bold)).foregroundColor(.blue)
                    Text("Clicks").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.blue.opacity(0.1)).cornerRadius(6)
            }

            if link.isActive {
                Button(action: { onUseLink() }) {
                    Text("Use Link").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
            }
        }
        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadedPhoto: UIImage?
    @State private var showExamples = false
    @StateObject private var pricingCalculator = AffiliatePricingCalculator.shared
    @State private var calculatorViews = 30.0

    private var currentLink: RatingLink {
        viewModel.ratingLinks.first(where: { $0.id == link.id }) ?? link
    }

    private var photoIsUploaded: Bool { currentLink.photoUrl != nil || uploadedPhoto != nil }
    private var canCopyLink: Bool { currentLink.isReadyToShare }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("How to Use Link").font(.system(size: 24, weight: .bold)).padding(.bottom)

                    uploadPhotoStep
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
    }

    // MARK: Step views

    private var uploadPhotoStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text("1").font(.system(size: 22, weight: .bold)).foregroundColor(.green); Text("Upload Bonus Photo").font(.system(size: 18, weight: .semibold)) }
            Text("Upload your bonus photo").font(.system(size: 16)).foregroundColor(.gray)
            VStack(spacing: 12) {
                if viewModel.isUploadingPhoto {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(height: 200)
                        .overlay(ProgressView().scaleEffect(1.2))
                } else if let url = currentLink.photoUrl, !url.isEmpty {
                    AsyncImage(url: URL(string: url)) { img in
                        img.resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: { RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(height: 200) }
                } else if let photo = uploadedPhoto {
                    Image(uiImage: photo).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)).frame(height: 200)
                        .overlay(Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.gray))
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text(photoIsUploaded ? "Change Photo" : "Upload Photo")
                        .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    private var copyLinkStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("2").font(.system(size: 22, weight: .bold)).foregroundColor(.green)
                Text("Copy Link").font(.system(size: 18, weight: .semibold))
                Spacer()
                if currentLink.aiScoring {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7).tint(.gray)
                        Text("Please wait...")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.gray.opacity(0.15)).cornerRadius(100)
                }
            }

            Text("https://\(currentLink.url)").frame(maxWidth: .infinity).padding(15)
                .background(Color.gray.opacity(0.1)).cornerRadius(8)
                .opacity(canCopyLink ? 1.0 : 0.5)

            Button(action: copyLink) {
                Text(showCopiedMessage ? "Link Copied" : (canCopyLink ? "Copy Link" : "Upload Photo First"))
                    .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(showCopiedMessage ? Color.green : (canCopyLink ? Color.blue : Color.gray.opacity(0.4)))
                    .foregroundColor(canCopyLink ? .white : Color.gray.opacity(0.7)).cornerRadius(8)
            }
            .disabled(!canCopyLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
        .opacity(photoIsUploaded ? 1.0 : 0.5)
    }

    private var addToStoryStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text("3").font(.system(size: 22, weight: .bold)).foregroundColor(.green); Text("Add Link to Story").font(.system(size: 18, weight: .semibold)) }
            Text("Add the link to your Instagram Story").font(.system(size: 16)).foregroundColor(.gray)
            Button(action: { showExamples = true }) {
                Text("See Examples").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.blue).foregroundColor(.white).cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    private var startEarningStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text("4").font(.system(size: 22, weight: .bold)).foregroundColor(.green); Text("Start Earning").font(.system(size: 18, weight: .semibold)) }
            Text("Earn \(pricingCalculator.formatEarnings(pricingCalculator.getEarningsPerRating())) every time your link is clicked")
                .font(.system(size: 16)).foregroundColor(.gray)
            earningsCalculator
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.gray.opacity(0.1)).cornerRadius(8)
    }

    private var earningsCalculator: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Clicks").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(calculatorViews))").font(.system(size: 18, weight: .bold))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.blue).frame(width: geometry.size.width * CGFloat((calculatorViews - 10) / 90), height: 6)
                    Circle().fill(Color.blue).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: geometry.size.width * CGFloat((calculatorViews - 10) / 90) - 11)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let pct = max(0, min(1, value.location.x / geometry.size.width))
                            calculatorViews = round((10 + pct * 90) / 10) * 10
                        })
                }
            }.frame(height: 24)
            HStack {
                Text("Earnings").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(pricingCalculator.formatEarnings(calculatorViews * pricingCalculator.getEarningsPerRating()))
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
            }
        }
        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
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
