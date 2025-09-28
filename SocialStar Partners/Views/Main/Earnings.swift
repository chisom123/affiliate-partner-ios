import SwiftUI

struct EarningsView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var withdrawalViewModel = WithdrawalViewModel()
    @State private var showingWithdrawSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Balance Card
                    VStack(spacing: 15) {
                        Text("Available Balance")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("$\(viewModel.affiliateData?.balance ?? 0.0, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                        
                        if let affiliateData = viewModel.affiliateData {
                            VStack(spacing: 8) {
                                // Always show withdraw button
                                Button(action: {
                                    if affiliateData.canWithdraw {
                                        // Analytics: Track withdraw button tap
                                        Analytics.shared.trackTap(
                                            elementId: "withdraw_button",
                                            screenName: "earnings",
                                            properties: [
                                                "available_balance": affiliateData.balance
                                            ]
                                        )
                                        
                                        showingWithdrawSheet = true
                                    }
                                }) {
                                    Text("Withdraw")
                                        .frame(maxWidth: .infinity)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(affiliateData.canWithdraw ? .white : Color(.systemGray2))
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(affiliateData.canWithdraw ? Color.blue : Color(.systemGray4))
                                        .cornerRadius(8)
                                }
                                .disabled(!affiliateData.canWithdraw)
                                
                                // Show message when balance is below $5
                                if !affiliateData.canWithdraw && affiliateData.balance > 0 {
                                    Text("Minimum withdrawal is $10.00")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.orange)
                                        .padding(.vertical)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Withdrawal History
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Withdrawal History")
                            .font(.system(size: 20, weight: .bold))
                        
                        if withdrawalViewModel.withdrawals.isEmpty {
                            VStack(spacing: 8) {
                                Text("No Withdrawals Yet")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Your withdrawal history will appear here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .padding(.vertical, 30)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        } else {
                            ForEach(withdrawalViewModel.withdrawals.sorted(by: { $0.requestedAt > $1.requestedAt })) { withdrawal in
                                WithdrawalCard(withdrawal: withdrawal, withdrawalViewModel: withdrawalViewModel)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Earnings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Analytics: Track screen view
            Analytics.shared.trackScreen(
                name: "earnings",
                properties: [
                    "available_balance": viewModel.affiliateData?.balance ?? 0.0,
                    "can_withdraw": viewModel.affiliateData?.canWithdraw ?? false,
                    "withdrawal_count": withdrawalViewModel.withdrawals.count
                ]
            )
            
            withdrawalViewModel.loadWithdrawals()
        }
        .sheet(isPresented: $showingWithdrawSheet) {
            WithdrawView()
        }
        .onChange(of: showingWithdrawSheet) { isPresented in
            if isPresented {
                // Analytics: Track withdrawal sheet presentation
                Analytics.shared.track(
                    event: "withdrawal_sheet_opened",
                    properties: [
                        AnalyticsProperty.screenName: "earnings",
                        "available_balance": viewModel.affiliateData?.balance ?? 0.0
                    ]
                )
            } else {
                // Analytics: Track withdrawal sheet dismissal
                Analytics.shared.track(
                    event: "withdrawal_sheet_closed",
                    properties: [
                        AnalyticsProperty.screenName: "earnings"
                    ]
                )
            }
        }
    }
}

struct WithdrawalCard: View {
    let withdrawal: Withdrawal
    let withdrawalViewModel: WithdrawalViewModel
    @State private var hasTrackedView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$\(withdrawal.amount, specifier: "%.2f")")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(withdrawal.requestedAt, style: .date)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(withdrawal.statusDescription)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor(for: withdrawal.status))
                        .foregroundColor(statusTextColor(for: withdrawal.status))
                        .cornerRadius(6)
                }
            }
            
            // Bank account info (using encrypted data safely)
            Text(getBankAccountDisplay(for: withdrawal))
                .foregroundColor(.gray)
            
            // Rejection reason if rejected
            if withdrawal.status == .rejected, let reason = withdrawal.rejectionReason {
                Text("\(reason)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // Helper to safely get bank account display info
    private func getBankAccountDisplay(for withdrawal: Withdrawal) -> String {
        // Use the safe maskedBankInfo property from Withdrawal
        return withdrawal.maskedBankInfo
    }
    
    private func statusColor(for status: WithdrawalStatus) -> Color {
        switch status {
        case .pending:
            return Color.orange.opacity(0.2)
        case .approved:
            return Color.blue.opacity(0.2)
        case .completed:
            return Color.green.opacity(0.2)
        case .rejected:
            return Color.red.opacity(0.2)
        }
    }
    
    private func statusTextColor(for status: WithdrawalStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .approved:
            return .blue
        case .completed:
            return .green
        case .rejected:
            return .red
        }
    }
}
