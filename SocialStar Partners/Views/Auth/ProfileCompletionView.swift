import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct ProfileCompletionView: View {
    // Steps: 1 = email, 2 = profile picture
    @State private var currentStep = 1

    // Email state
    @State private var email = ""
    @State private var emailError = ""

    // Profile picture state
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage = ""

    private var progressValue: CGFloat {
        CGFloat(currentStep) / 2.0
    }

    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progressValue, height: 6)
                            .cornerRadius(3)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal)
                .padding(.top, 20)

                Group {
                    switch currentStep {
                    case 1:
                        emailStep
                    case 2:
                        profilePictureStep
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Analytics.shared.trackScreen(name: "profile_completion")
        }
        .onChange(of: currentStep) { newStep in
            Analytics.shared.track(
                event: "profile_completion_step_viewed",
                properties: [
                    AnalyticsProperty.screenName: "profile_completion",
                    "step_number": newStep
                ]
            )
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            }
        }
    }

    // MARK: - Email Step (step 1)
    private var emailStep: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 12) {
                Text("What's your email?")
                    .font(.system(size: 24, weight: .bold))

                Text("We'll use this to send you important account updates.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            TextField("Email", text: $email)
                .frame(maxWidth: .infinity)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding(.vertical, 12)
                .padding(.leading, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)

            if !emailError.isEmpty {
                Text(emailError)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onAppear {
                        Analytics.shared.trackError(
                            message: emailError,
                            properties: [AnalyticsProperty.screenName: "profile_completion_email"]
                        )
                    }
            }

            Spacer()

            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "continue_button",
                    screenName: "profile_completion_email",
                    properties: ["form_valid": isEmailValid]
                )
                guard isEmailValid else {
                    emailError = "Please enter a valid email address"
                    Analytics.shared.track(
                        event: "email_validation_failed",
                        properties: [
                            AnalyticsProperty.screenName: "profile_completion_email",
                            "validation_error": "invalid_email_format"
                        ]
                    )
                    return
                }
                emailError = ""
                currentStep = 2
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(email.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(email.isEmpty)
            .padding(.horizontal)
        }
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
    }

    // MARK: - Profile Picture Step (step 2)
    private var profilePictureStep: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 12) {
                Text("Add Profile Picture")
                    .font(.system(size: 24, weight: .bold))

                Text("Add a photo so your followers can recognise you.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

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

            Spacer()

            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "complete_setup_button",
                    screenName: "profile_completion_picture",
                    properties: ["has_image": selectedImage != nil]
                )
                completeSetup()
            }) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Complete Setup")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedImage == nil ? Color.gray.opacity(0.3) : .white)
                .padding(.vertical, 14)
                .background(selectedImage == nil ? Color.gray.opacity(0.3) : Color.blue)
                .cornerRadius(8)
            }
            .disabled(isLoading || selectedImage == nil)
            .padding(.horizontal)
        }
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
    }

    // MARK: - Actions
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
                            AnalyticsProperty.screenName: "profile_completion_picture",
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
                                AnalyticsProperty.screenName: "profile_completion_picture",
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
        Firestore.firestore().collection("affiliates").document(user.uid).updateData([
            "email": email,
            "profilePictureUrl": profilePictureUrl ?? NSNull()
        ]) { error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    Analytics.shared.track(
                        event: "firestore_save_failed",
                        properties: [
                            AnalyticsProperty.screenName: "profile_completion_picture",
                            AnalyticsProperty.errorMessage: error.localizedDescription
                        ]
                    )
                    return
                }

                Analytics.shared.track(
                    event: "profile_completed_successfully",
                    properties: [
                        AnalyticsProperty.screenName: "profile_completion_picture",
                        "user_id": user.uid,
                        "has_profile_picture": profilePictureUrl != nil
                    ]
                )

                NotificationCenter.default.post(name: .profileCompleted, object: nil)
            }
        }
    }
}
