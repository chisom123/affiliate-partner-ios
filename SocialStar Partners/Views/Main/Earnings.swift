import SwiftUI

struct EarningsView: View {
    @StateObject private var viewModel = DashboardViewModel()
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
                            Button("Withdraw") {
                                showingWithdrawSheet = true
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                        } else {
                            Text("Minimum withdrawal: $0.25")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Earnings Summary
                    if let affiliateData = viewModel.affiliateData {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Lifetime Earnings")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("$\(affiliateData.lifetimeEarnings, specifier: "%.2f")")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            
                            HStack {
                                Text("Total Withdrawn")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("$\(affiliateData.totalWithdrawn, specifier: "%.2f")")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            HStack {
                                Text("Total Ratings")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(viewModel.totalRatings)")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Withdrawal History
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Withdrawal History")
                            .font(.system(size: 20, weight: .bold))
                        
                        if withdrawalViewModel.withdrawals.isEmpty {
                            VStack(spacing: 8) {
                                Text("No withdrawals yet")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Your withdrawal history will appear here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        } else {
                            ForEach(withdrawalViewModel.withdrawals.sorted(by: { $0.requestedAt > $1.requestedAt })) { withdrawal in
                                WithdrawalCard(withdrawal: withdrawal)
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
            viewModel.loadData()
            withdrawalViewModel.loadWithdrawals()
        }
        .sheet(isPresented: $showingWithdrawSheet) {
            WithdrawView()
        }
    }
}

struct WithdrawalCard: View {
    let withdrawal: Withdrawal
    
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
                    
                    if withdrawal.status == .approved {
                        Text("Processing soon")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else if withdrawal.status == .completed {
                        Text("Completed")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Bank account info (last 4 digits)
            Text("****\(withdrawal.bankAccount.accountNumber.suffix(4))")
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
