import SwiftUI
import FirebaseAuth
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct ProfileCompletionView: View {
    @State private var currentStep = 0

    // Explainer state
    @State private var explainerStep = 0
    @State private var calculatorRatings = 30.0
    @StateObject private var pricingCalculator = AffiliatePricingCalculator.shared

    private let explainerSteps: [ExplainerStep] = [
        ExplainerStep(
            imageName: "explain1",
            title: "Add Rating Link",
            description: "Simply add our link to your Instagram story",
            showCalculator: false
        ),
        ExplainerStep(
            imageName: "explain2",
            title: "Get Ratings",
            description: "Your followers tap the link and rate your story",
            showCalculator: false
        ),
        ExplainerStep(
            imageName: "",
            title: "Get Paid",
            description: "",
            showCalculator: true
        )
    ]

    // Phone state
    private let countries: [(name: String, code: String, flag: String)] = [
        ("United States", "+1", "🇺🇸"),
        ("United Kingdom", "+44", "🇬🇧")
    ]
    @State private var selectedCountryIndex = 0
    @State private var phoneNumber = ""
    @State private var verificationID = ""
    @State private var otpCode = ""
    @State private var resendCooldown = 0
    @State private var cooldownTimer: Timer?

    // Profile picture state
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage = ""

    private var selectedCountry: (name: String, code: String, flag: String) {
        countries[selectedCountryIndex]
    }

    private var fullPhoneNumber: String {
        var digits = phoneNumber.trimmingCharacters(in: .whitespaces)
        if selectedCountry.code == "+44" {
            digits = digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
        }
        return "\(selectedCountry.code)\(digits)"
    }

    private var isPhoneValid: Bool {
        phoneNumber.filter(\.isNumber).count >= 9
    }

    private var isCodeComplete: Bool {
        otpCode.filter(\.isNumber).count == 6
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Progress bar — hidden on explainer step
                if currentStep > 0 {
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
                }

                Group {
                    switch currentStep {
                    case 0:
                        explainerStepView
                    case 1:
                        phoneEntryStep
                    case 2:
                        phoneVerificationStep
                    case 3:
                        profilePictureStep
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle(currentStep == 0 ? "" : "Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            NotificationCenter.default.post(name: .profileIncomplete, object: nil)
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
        .onDisappear {
            cooldownTimer?.invalidate()
        }
    }

    private var progressValue: CGFloat {
        CGFloat(currentStep) / 3.0
    }

    // MARK: - Explainer Step (step 0)
    private var explainerStepView: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<explainerSteps.count, id: \.self) { index in
                    Capsule()
                        .fill(index == explainerStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Step content
            VStack(spacing: 32) {
                if explainerSteps[explainerStep].showCalculator {
                    calculatorView
                } else {
                    Image(explainerSteps[explainerStep].imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .overlay(
                            Group {
                                if explainerStep == 1 {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                }
                            }
                        )
                        .padding(.horizontal, 24)
                }

                Text(explainerSteps[explainerStep].title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if !explainerSteps[explainerStep].showCalculator {
                    Text(explainerSteps[explainerStep].description)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                } else {
                    Text("Make \(pricingCalculator.formatEarnings(pricingCalculator.getEarningsPerRating())) every time your story is rated")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }
            }
            .id(explainerStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            VStack(spacing: 16) {
                if explainerStep < explainerSteps.count - 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            explainerStep += 1
                        }
                    }) {
                        Text("Next")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button(action: {
                        currentStep = 1
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }

    // MARK: - Calculator View (reused from ProgramExplainerView)
    private var calculatorView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 15) {
                HStack {
                    Text("Number of Ratings")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(calculatorRatings))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }

                calculatorSlider
            }
            .padding(.horizontal, 10)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12, corners: [.topLeft, .topRight])

            VStack(spacing: 8) {
                Text("Story Earnings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)

                Text(pricingCalculator.formatEarnings(calculatorRatings * pricingCalculator.getEarningsPerRating()))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
        }
        .padding(.horizontal, 24)
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
                    )
            }
        }
        .frame(height: 24)
    }

    // MARK: - Phone Entry Step (step 1)
    private var phoneEntryStep: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 12) {
                Text("Verify Your Number")
                    .font(.system(size: 24, weight: .bold))

                Text("We need to verify your phone number to keep your account secure.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 0) {
                Menu {
                    ForEach(countries.indices, id: \.self) { index in
                        Button(action: {
                            selectedCountryIndex = index
                            phoneNumber = ""
                        }) {
                            Text("\(countries[index].flag)  \(countries[index].name) (\(countries[index].code))")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                            .font(.system(size: 22))
                        Text(selectedCountry.code)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer().frame(width: 10)

                TextField(selectedCountry.code == "+1" ? "(555) 000-0000" : "07700 900000", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Button(action: sendVerificationCode) {
                    Text("Send Code")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(isPhoneValid ? Color.blue : Color.gray.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!isPhoneValid)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
    }

    // MARK: - Phone Verification Step (step 2)
    private var phoneVerificationStep: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 12) {
                Text("Enter Your Code")
                    .font(.system(size: 24, weight: .bold))

                Text("We sent a 6-digit code to\n\(fullPhoneNumber)")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            TextField("6-digit code", text: $otpCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: otpCode) { newValue in
                    let digits = newValue.filter(\.isNumber)
                    otpCode = String(digits.prefix(6))
                }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Group {
                if resendCooldown > 0 {
                    Text("Resend code in \(resendCooldown)s")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else {
                    Button(action: sendVerificationCode) {
                        Text("Resend Code")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Button(action: verifyCode) {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(isCodeComplete ? Color.blue : Color.gray.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!isCodeComplete)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
    }

    // MARK: - Profile Picture Step (step 3)
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

            Button(action: uploadProfilePicture) {
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
    private func sendVerificationCode() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true
        errorMessage = ""

        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { verificationId, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = friendlyPhoneError(error)
                    return
                }

                guard let verificationId = verificationId else {
                    errorMessage = "Something went wrong. Please try again."
                    return
                }

                verificationID = verificationId
                startCooldown()
                currentStep = 2
            }
        }
    }

    private func verifyCode() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true
        errorMessage = ""

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )

        guard let currentUser = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "No user session found. Please restart the app."
            return
        }

        currentUser.link(with: credential) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    let code = (error as NSError).code

                    if code == 17015 || code == 17025 {
                        currentUser.reauthenticate(with: credential) { _, reauthError in
                            DispatchQueue.main.async {
                                isLoading = false
                                if let reauthError = reauthError {
                                    let reauthCode = (reauthError as NSError).code
                                    if reauthCode == 17044 || reauthCode == 17045 {
                                        errorMessage = "Your verification code has expired. Please go back and request a new one."
                                    } else {
                                        errorMessage = "Verification failed. Please try again."
                                    }
                                } else {
                                    currentStep = 3
                                }
                            }
                        }
                        return
                    }

                    isLoading = false
                    if code == 17044 || code == 17045 {
                        errorMessage = "Your verification code has expired. Please go back and request a new one."
                    } else {
                        errorMessage = "Verification failed. Please try again."
                    }
                    return
                }

                isLoading = false
                currentStep = 3
            }
        }
    }

    private func uploadProfilePicture() {
        guard let user = Auth.auth().currentUser,
              let image = selectedImage,
              let imageData = image.optimizedForProfilePicture() else { return }

        isLoading = true
        errorMessage = ""

        let storageRef = Storage.storage().reference()
            .child("profile_pictures/\(user.uid)_\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to get image URL: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }

                guard let url = url else { return }

                Firestore.firestore().collection("affiliates").document(user.uid).updateData([
                    "profilePictureUrl": url.absoluteString
                ]) { error in
                    DispatchQueue.main.async {
                        self.isLoading = false

                        if let error = error {
                            self.errorMessage = "Failed to save profile picture: \(error.localizedDescription)"
                            return
                        }

                        NotificationCenter.default.post(name: .profileCompleted, object: nil)
                    }
                }
            }
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                resendCooldown -= 1
                if resendCooldown <= 0 { timer.invalidate() }
            }
        }
    }

    private func friendlyPhoneError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17010: return "Too many requests. Please wait a moment and try again."
        case 17042: return "Invalid phone number. Please check and try again."
        default: return "Couldn't send code. Please check your number and try again."
        }
    }
}
