import SwiftUI
import SwiftData

struct MonthlyCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: MonthlyCheckInViewModel
    @State private var navigateToStory = false

    init(modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: MonthlyCheckInViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isComplete {
                    completeView
                } else {
                    checkInView
                }
            }
            .navigationTitle("Monthly check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToStory) {
                if let story = vm.aiStory, let report = vm.realReport {
                    ProofOfGrowthView(narrative: story, report: report)
                }
            }
        }
    }

    // MARK: - Check-in view
    private var checkInView: some View {
        VStack(spacing: 0) {

            VStack(spacing: 8) {
                HStack {
                    Text(vm.monthLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(vm.ratedCount) of \(vm.areas.count) rated")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#BA7517"))
                            .frame(width: geo.size.width * vm.progress, height: 3)
                            .animation(.easeInOut, value: vm.progress)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.currentArea.displayName)
                        .font(.system(size: 22, weight: .medium))
                    Text("Did you live this?")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach([CheckInRating.yes, .partly, .notReally], id: \.self) { rating in
                        Button {
                            vm.rate(rating)
                        } label: {
                            HStack {
                                Text(rating.label)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(rating.textColor)
                                Spacer()
                                if vm.ratings[vm.currentArea] == rating {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(rating.textColor)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                vm.ratings[vm.currentArea] == rating
                                    ? rating.color
                                    : Color(.systemBackground)
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.ratings[vm.currentArea] == rating
                                            ? rating.color
                                            : Color.secondary.opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                    }
                }

                if vm.ratings[vm.currentArea] != .notRated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want to add a note? (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField(
                            reflectionPlaceholder(for: vm.currentArea, rating: vm.ratings[vm.currentArea]!),
                            text: Binding(
                                get: { vm.reflections[vm.currentArea] ?? "" },
                                set: { vm.reflections[vm.currentArea] = $0 }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    Button {
                        vm.advance()
                    } label: {
                        Text(vm.isLastArea ? "Complete check-in" : "Next →")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#412402"))
                            .foregroundColor(Color(hex: "#FAEEDA"))
                            .cornerRadius(12)
                    }
                    .transition(.opacity)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)

            Spacer()

            if vm.currentIndex > 0 {
                Button("← Back") { vm.goBack() }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Complete view
    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#1D9E75"))

                Text("Check-in complete")
                    .font(.system(size: 22, weight: .medium))

                Text("Your \(vm.monthLabel) story is ready.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            if let report = vm.realReport {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        RealDataStat(
                            value: "$\(Int(report.savedAmount))",
                            label: "saved"
                        )
                        RealDataStat(
                            value: "\(report.completedActions)/\(report.totalActions)",
                            label: "actions"
                        )
                        RealDataStat(
                            value: "\(report.canvasChanges.reduce(0) { $0 + $1.delta })",
                            label: "canvas pts"
                        )
                    }
                    .padding(16)
                    .background(Color(hex: "#FAEEDA"))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                }
            }

            if vm.isLoadingStory {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Building your story...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Spacer()

            Button {
                navigateToStory = true
            } label: {
                Text("See my story →")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        vm.isLoadingStory || vm.aiStory == nil
                            ? Color.secondary
                            : Color(hex: "#412402")
                    )
                    .foregroundColor(Color(hex: "#FAEEDA"))
                    .cornerRadius(12)
            }
            .disabled(vm.isLoadingStory || vm.aiStory == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .animation(.easeInOut, value: vm.isLoadingStory)
        }
    }
}

private func reflectionPlaceholder(for area: LifeAreaType, rating: CheckInRating) -> String {
    switch rating {
    case .yes:
        return "What made this area feel good this month?"
    case .partly:
        return "What held you back from fully living this?"
    case .notReally:
        return "What got in the way? What would you do differently?"
    case .notRated:
        return ""
    }
}

// MARK: - Real data stat widget
private struct RealDataStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "#412402"))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#854F0B"))
        }
        .frame(maxWidth: .infinity)
    }
}
