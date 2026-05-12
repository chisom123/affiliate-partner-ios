import SwiftUI

struct NameView: View {
    let phoneNumber: String

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var navigateToEmail = false

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.system(size: 24, weight: .bold))

            VStack(spacing: 15) {
                TextField("First Name", text: $firstName)
                    .frame(maxWidth: .infinity)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                TextField("Last Name", text: $lastName)
                    .frame(maxWidth: .infinity)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 12)
                    .padding(.leading, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "continue_button",
                    screenName: "name_entry",
                    properties: [
                        "form_valid": !firstName.isEmpty && !lastName.isEmpty
                    ]
                )
                navigateToEmail = true
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        (firstName.isEmpty || lastName.isEmpty) ?
                        Color.gray.opacity(0.5) :
                        Color.blue
                    )
                    .cornerRadius(8)
            }
            .disabled(firstName.isEmpty || lastName.isEmpty)
            .padding(.horizontal)

            NavigationLink(
                destination: EmailEntryView(
                    phoneNumber: phoneNumber,
                    firstName: firstName,
                    lastName: lastName
                ),
                isActive: $navigateToEmail
            ) {
                EmptyView()
            }
            .hidden()
        }
        .padding()
        .padding(.vertical, 30)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onAppear {
            Analytics.shared.trackScreen(name: "name_entry")
        }
    }
}
