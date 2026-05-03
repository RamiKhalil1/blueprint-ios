import SwiftUI
import SwiftData

struct ReviewAreasView: View {
    @ObservedObject var vm: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var canvases: [Canvas]

    private var lifeAreas: [LifeArea] {
        canvases.first?.lifeAreas.sorted { $0.priorityRank < $1.priorityRank } ?? []
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Blueprint")
                                .font(.custom("Georgia", size: 30))
                                .foregroundColor(.primary)
                            Text("Based on your swipes and answers, here are the 5 life areas Claude identified for you.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(.top, 56)

                        // Life area cards
                        VStack(spacing: 12) {
                            ForEach(lifeAreas) { area in
                                AreaReviewCard(area: area)
                            }
                        }

                        // Regenerate option
                        Button {
                            vm.regenerateAreas()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13))
                                Text("These don't feel right — regenerate")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 4)

                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 24)
                }

                // Bottom button
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 12) {
                        Button {
                            vm.confirmAreas()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("This is my Blueprint — let's go")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#412402"))
                            .foregroundColor(Color(hex: "#FAEEDA"))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
    }
}

// MARK: - Area Review Card
struct AreaReviewCard: View {
    let area: LifeArea

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Area header
            HStack(spacing: 10) {
                Text(area.emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(area.areaDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            Divider()

            // Vision
            VStack(alignment: .leading, spacing: 4) {
                Text("VISION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#BA7517"))
                    .tracking(1)
                Text(area.vision.isEmpty ? "Being generated..." : area.vision)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .lineLimit(3)
            }

            // Current reality
            VStack(alignment: .leading, spacing: 4) {
                Text("WHERE YOU ARE NOW")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#1D9E75"))
                    .tracking(1)
                Text(area.currentReality.isEmpty ? "Being generated..." : area.currentReality)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .lineLimit(3)
            }

            // Task count
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(area.tasks.count) growth tasks generated")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
