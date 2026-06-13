import SwiftUI

struct ProgramExplainerView: View {
    @State private var currentStep = 0
    @State private var navigateToPhone = false
    @State private var calculatorRatings = 30.0
    @StateObject private var pricingCalculator = AffiliatePricingCalculator.shared

    private var steps: [ExplainerStep] {
        let earningsPerRating = pricingCalculator.getEarningsPerRating()
        let formattedEarnings = pricingCalculator.formatEarnings(earningsPerRating)

        return [
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
                description: "Make \(formattedEarnings) every time your story is rated",
                showCalculator: true
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Step content
            VStack(spacing: 32) {
                if steps[currentStep].showCalculator {
                    calculatorView
                } else {
                    Image(steps[currentStep].imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .overlay(
                            Group {
                                if currentStep == 1 {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                }
                            }
                        )
                        .padding(.horizontal, 24)
                }

                Text(steps[currentStep].title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(steps[currentStep].description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            // Navigation button
            VStack(spacing: 16) {
                if currentStep < steps.count - 1 {
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "next_button",
                            screenName: "program_explainer",
                            properties: [
                                "current_step": currentStep + 1,
                                "step_title": steps[currentStep].title
                            ]
                        )
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
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
                        Analytics.shared.trackTap(
                            elementId: "get_started_button",
                            screenName: "program_explainer",
                            properties: [
                                "completed_all_steps": true,
                                "total_steps": steps.count,
                                "final_calculator_ratings": Int(calculatorRatings),
                                "final_calculator_earnings": calculatorRatings * pricingCalculator.getEarningsPerRating()
                            ]
                        )
                        Analytics.shared.track(
                            event: "program_explainer_completed",
                            properties: [
                                AnalyticsProperty.screenName: "program_explainer",
                                "total_steps_viewed": steps.count,
                                "final_calculator_ratings": Int(calculatorRatings),
                                "final_calculator_earnings": calculatorRatings * pricingCalculator.getEarningsPerRating()
                            ]
                        )
                        navigateToPhone = true
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

            NavigationLink(destination: PhoneEntryView(), isActive: $navigateToPhone) {
                EmptyView()
            }
            .hidden()
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .onAppear {
            Analytics.shared.trackScreen(name: "program_explainer")
            Analytics.shared.track(
                event: "explainer_step_viewed",
                properties: [
                    AnalyticsProperty.screenName: "program_explainer",
                    "step_number": 1,
                    "step_title": steps[0].title
                ]
            )
        }
        .onChange(of: currentStep) { newStep in
            Analytics.shared.track(
                event: "explainer_step_viewed",
                properties: [
                    AnalyticsProperty.screenName: "program_explainer",
                    "step_number": newStep + 1,
                    "step_title": steps[newStep].title
                ]
            )
        }
        .onDisappear {
            if currentStep < steps.count - 1 {
                Analytics.shared.track(
                    event: "program_explainer_abandoned",
                    properties: [
                        AnalyticsProperty.screenName: "program_explainer",
                        "last_step_viewed": currentStep + 1,
                        "total_steps": steps.count,
                        "completion_percentage": Double(currentStep + 1) / Double(steps.count) * 100,
                        "last_calculator_ratings": Int(calculatorRatings),
                        "last_calculator_earnings": calculatorRatings * pricingCalculator.getEarningsPerRating()
                    ]
                )
            }
        }
    }

    // MARK: - Calculator View
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
                            .onEnded { _ in
                                Analytics.shared.track(
                                    event: "explainer_calculator_used",
                                    properties: [
                                        AnalyticsProperty.screenName: "program_explainer",
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
}

struct ExplainerStep {
    let imageName: String
    let title: String
    let description: String
    let showCalculator: Bool
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
