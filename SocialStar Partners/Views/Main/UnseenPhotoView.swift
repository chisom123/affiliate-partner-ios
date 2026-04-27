// UnseenPhotoView.swift
import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct UnseenPhotoView: View {
    let unseenPhotoUrl: String?
    var onUploadSuccess: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = UnseenPhotoViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Description
                HStack {
                    Text("Upload a bonus photo for your followers to rate")
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Photo preview
                Group {
                    if viewModel.isUploading {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 280)
                            .overlay(
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                }
                            )
                    } else if let localPreview = viewModel.localPreview {
                        Image(uiImage: localPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let urlString = viewModel.currentPhotoUrl ?? unseenPhotoUrl,
                              let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 280)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 280)
                                .overlay(ProgressView())
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                            .frame(height: 280)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 44))
                                        .foregroundColor(.gray)
                                    Text("No bonus photo yet")
                                        .font(.system(.subheadline))
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }

                // Upload button
                PhotosPicker(
                    selection: $viewModel.selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(viewModel.hasPhoto ? "Change Photo" : "Upload Photo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(viewModel.isUploading)

                // Success / error messages
                if !viewModel.successMessage.isEmpty {
                    HStack(spacing: 8) {
                        Text(viewModel.successMessage)
                            .font(.system(.body, weight: .bold))
                            .foregroundColor(.green)
                        Spacer()
                    }
                }

                if !viewModel.errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Text(viewModel.errorMessage)
                            .font(.system(.body, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .navigationTitle("Bonus Photo")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Analytics.shared.trackScreen(
                name: "unseen_photo",
                properties: ["has_photo": unseenPhotoUrl != nil]
            )
        }
        .onChange(of: viewModel.selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.onUploadSuccess = onUploadSuccess
                        viewModel.upload(image)
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

class UnseenPhotoViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var localPreview: UIImage?
    @Published var currentPhotoUrl: String?
    @Published var isUploading = false
    @Published var successMessage = ""
    @Published var errorMessage = ""

    var onUploadSuccess: (() -> Void)?

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    var hasPhoto: Bool {
        currentPhotoUrl != nil || localPreview != nil
    }

    func upload(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else { return }

        localPreview = image
        isUploading = true
        successMessage = ""
        errorMessage = ""
        selectedItem = nil // Reset picker so it can be reopened

        Analytics.shared.track(
            event: "unseen_photo_upload_started",
            properties: [
                AnalyticsProperty.screenName: "unseen_photo",
                "image_size_kb": imageData.count / 1024
            ]
        )

        let ref = storage.reference().child("unseen_photos/\(userId)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(imageData, metadata: metadata) { [weak self] _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isUploading = false
                    self?.localPreview = nil
                    self?.errorMessage = "Failed to upload photo"
                    Analytics.shared.trackError(
                        message: "Unseen photo upload failed: \(error.localizedDescription)",
                        properties: [AnalyticsProperty.screenName: "unseen_photo"]
                    )
                }
                return
            }

            ref.downloadURL { [weak self] url, error in
                DispatchQueue.main.async {
                    self?.isUploading = false

                    if let error = error {
                        self?.localPreview = nil
                        self?.errorMessage = "Failed to get photo URL"
                        Analytics.shared.trackError(
                            message: "Failed to get bonus photo URL: \(error.localizedDescription)",
                            properties: [AnalyticsProperty.screenName: "unseen_photo"]
                        )
                        return
                    }

                    guard let urlString = url?.absoluteString else { return }

                    self?.db.collection("affiliates").document(userId).updateData([
                        "unseenPhotoUrl": urlString
                    ]) { [weak self] error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.localPreview = nil
                                self?.errorMessage = "Failed to save photo"
                                Analytics.shared.trackError(
                                    message: "Firestore bonus photo update failed: \(error.localizedDescription)",
                                    properties: [AnalyticsProperty.screenName: "unseen_photo"]
                                )
                                return
                            }

                            self?.currentPhotoUrl = urlString
                            self?.localPreview = nil
                            self?.successMessage = "Bonus photo updated"
                            self?.onUploadSuccess?()

                            Analytics.shared.track(
                                event: "unseen_photo_updated_successfully",
                                properties: [
                                    AnalyticsProperty.screenName: "unseen_photo",
                                    "user_id": userId
                                ]
                            )

                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self?.successMessage = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
