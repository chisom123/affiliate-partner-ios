import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct ProfilePictureView: View {
    let firstName: String
    let lastName: String
    let email: String

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            Text("Add Profile Picture")
                .font(.system(size: 24, weight: .bold))

            Text("Add a photo so your followers can recognise you.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)

                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                }
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text(selectedImage == nil ? "Choose Photo" : "Change Photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(1.2)
                    Spacer()
                }
                .frame(height: 50)
                .padding(.horizontal)
            } else {
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "complete_setup_button",
                        screenName: "profile_picture_entry",
                        properties: ["has_image": selectedImage != nil]
                    )
                    completeSetup()
                }) {
                    Text("Complete Setup")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(selectedImage == nil ? Color.gray.opacity(0.3) : .white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(selectedImage == nil ? Color.gray.opacity(0.3) : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(selectedImage == nil)
                .padding(.horizontal)
            }
        }
        .padding()
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { selectedImage = image }
                }
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "profile_picture_entry")
        }
    }

    private func completeSetup() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user session found. Please restart the app."
            return
        }

        isLoading = true
        errorMessage = ""

        if let image = selectedImage {
            uploadProfilePicture(image, for: user)
        } else {
            saveFirestoreDocument(for: user, profilePictureUrl: nil)
        }
    }

    private func uploadProfilePicture(_ image: UIImage, for user: User) {
        guard let imageData = image.optimizedForProfilePicture() else {
            saveFirestoreDocument(for: user, profilePictureUrl: nil)
            return
        }

        let storageRef = Storage.storage().reference()
            .child("profile_pictures/\(user.uid)_\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    isLoading = false
                    Analytics.shared.track(
                        event: "profile_picture_upload_failed",
                        properties: [
                            AnalyticsProperty.screenName: "profile_picture_entry",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                }
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = "Failed to get image URL: \(error.localizedDescription)"
                        isLoading = false
                        Analytics.shared.track(
                            event: "profile_picture_url_failed",
                            properties: [
                                AnalyticsProperty.screenName: "profile_picture_entry",
                                AnalyticsProperty.errorMessage: error.localizedDescription
                            ]
                        )
                    }
                    return
                }
                saveFirestoreDocument(for: user, profilePictureUrl: url?.absoluteString)
            }
        }
    }

    private func saveFirestoreDocument(for user: User, profilePictureUrl: String?) {
        let affiliateData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "profilePictureUrl": profilePictureUrl ?? NSNull(),
            "totalEarnings": 0,
            "totalRatings": 0,
            "createdAt": Timestamp(),
            "status": "active",
            "paymentInfo": NSNull(),
            "payoutHistory": [],
            "balance": 0.0,
            "totalWithdrawn": 0.0,
            "linkCredits": 0
        ]

        Firestore.firestore().collection("affiliates").document(user.uid).setData(affiliateData) { error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Failed to create account: \(error.localizedDescription)"
                    Analytics.shared.track(
                        event: "firestore_save_failed",
                        properties: [
                            AnalyticsProperty.screenName: "profile_picture_entry",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                    return
                }

                Analytics.shared.track(
                    event: "account_created_successfully",
                    properties: [
                        AnalyticsProperty.screenName: "profile_picture_entry",
                        "user_id": user.uid,
                        "has_profile_picture": profilePictureUrl != nil
                    ]
                )

                NotificationCenter.default.post(name: .authStateDidChange, object: nil)
            }
        }
    }
}
