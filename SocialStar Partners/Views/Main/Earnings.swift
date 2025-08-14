import SwiftUI

struct EarningsView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Earnings Card
                    VStack(spacing: 15) {
                        Text("Total Earnings")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("$\(viewModel.totalEarnings, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("\(viewModel.totalRatings) total ratings")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Earnings Breakdown
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Earnings Breakdown")
                            .font(.system(size: 20, weight: .bold))
                        
                        if viewModel.ratingLinks.isEmpty {
                            Text("No earnings yet. Create your first link to start earning!")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            ForEach(viewModel.ratingLinks.sorted(by: { $0.earnings > $1.earnings })) { link in
                                EarningsCard(link: link)
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
        }
    }
}

struct EarningsCard: View {
    let link: RatingLink
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack {
                    Text("\(link.totalRatings) ratings")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if link.hasRatings {
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("\(link.averageRating, specifier: "%.1f") ★")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                }
                
                Text(link.isActive ? "Active" : "Expired")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(link.isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(link.isActive ? .green : .red)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(link.earnings, specifier: "%.2f")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                
                Text("$0.25 per rating")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
