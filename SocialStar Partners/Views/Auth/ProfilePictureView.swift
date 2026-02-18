import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct ProfilePictureView: View {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phoneVerificationID: String
    let phoneOTPCode: String

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var navigateToDashboard = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Add Profile Picture")
                .font(.system(size: 24, weight: .bold))

            VStack(spacing: 20) {
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
                        elementId: "complete_profile_picture_button",
                        screenName: "profile_picture_entry",
                        properties: ["has_image": selectedImage != nil]
                    )
                    if let image = selectedImage {
                        uploadProfilePicture(image)
                    }
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

        NavigationLink(destination: MainTabView(), isActive: $navigateToDashboard) {
            EmptyView()
        }
        .hidden()
    }

    private func uploadProfilePicture(_ image: UIImage) {
        isLoading = true
        errorMessage = ""

        guard let imageData = image.optimizedForProfilePicture() else {
            errorMessage = "Failed to process image"
            isLoading = false
            return
        }

        let profilePicturesRef = Storage.storage().reference()
            .child("profile_pictures/\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        profilePicturesRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                errorMessage = "Failed to upload image: \(error.localizedDescription)"
                isLoading = false
                return
            }
            profilePicturesRef.downloadURL { url, error in
                if let error = error {
                    errorMessage = "Failed to get image URL: \(error.localizedDescription)"
                    isLoading = false
                    return
                }
                createAccount(with: url?.absoluteString)
            }
        }
    }

    private func createAccount(with profilePictureUrl: String?) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
            guard let user = result?.user else {
                errorMessage = "Failed to get user information"
                isLoading = false
                return
            }
            linkPhoneCredential(to: user, profilePictureUrl: profilePictureUrl)
        }
    }

    private func linkPhoneCredential(to user: User, profilePictureUrl: String?) {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: phoneVerificationID,
            verificationCode: phoneOTPCode
        )

        user.link(with: credential) { _, error in
            if let error = error {
                let code = (error as NSError).code

                // Delete the just-created email account in ALL error cases
                // to avoid orphaned accounts on retry
                user.delete { _ in }
                isLoading = false

                if code == 17025 {
                    errorMessage = "This phone number is already associated with an account. Please sign in instead."
                    Analytics.shared.track(
                        event: "phone_link_duplicate",
                        properties: [AnalyticsProperty.screenName: "profile_picture_entry"]
                    )
                } else if code == 17044 || code == 17045 {
                    errorMessage = "Your verification code has expired. Please go back and request a new one."
                } else {
                    errorMessage = "Phone verification failed. Please go back and try again."
                    Analytics.shared.track(
                        event: "phone_link_failed",
                        properties: [
                            AnalyticsProperty.screenName: "profile_picture_entry",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                }
                return  // ← always return on any error, never fall through to Firestore
            }

            createFirestoreDocument(for: user, profilePictureUrl: profilePictureUrl)
        }
    }

    private func createFirestoreDocument(for user: User, profilePictureUrl: String?) {
        // phoneNumber intentionally not stored here — it lives in Firebase Auth only
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
            isLoading = false

            if let error = error {
                errorMessage = "Failed to create account: \(error.localizedDescription)"
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

            navigateToDashboard = true
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }
}
