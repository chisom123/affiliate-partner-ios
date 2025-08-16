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
                        
                        if let affiliateData = viewModel.affiliateData, affiliateData.canWithdraw {
                            Button(action: {
                                showingWithdrawSheet = true
                            }) {
                                Text("Withdraw")
                                    .frame(maxWidth: .infinity)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(8)
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
            withdrawalViewModel.loadWithdrawals()
        }
        .sheet(isPresented: $showingWithdrawSheet) {
            WithdrawView()
        }
    }
}

struct WithdrawalCard: View {
    let withdrawal: Withdrawal
    let withdrawalViewModel: WithdrawalViewModel
    
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
                Text("Reason: \(reason)")
                    .font(.system(size: 14))
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
