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
                if vm.isComplete {
                    completeView
                        .transition(.opacity)
                } else {
                    checkInView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: vm.isComplete)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToStory) {
                if let story = vm.aiStory, let report = vm.realReport {
                    ProofOfGrowthView(narrative: story, report: report)
                }
            }
        }
    }

    // MARK: - Check-in view
    private var checkInView: some View {
        ZStack {
            // Dark background
            Color(hex: "#1A1208").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(vm.monthLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#BA7517"))
                    Spacer()
                    Text("\(vm.ratedCount)/\(vm.areas.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#BA7517"))
                            .frame(width: geo.size.width * vm.progress, height: 3)
                            .animation(.easeInOut, value: vm.progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                if let area = vm.currentArea {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {

                            // Area header
                            VStack(alignment: .leading, spacing: 10) {
                                Text(area.emoji)
                                    .font(.system(size: 44))
                                Text(area.name)
                                    .font(.custom("Georgia", size: 28))
                                    .foregroundColor(Color(hex: "#FAC775"))
                                Text("How did this area feel this month?")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            // Vision reminder
                            if !area.vision.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("YOUR VISION")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(Color(hex: "#BA7517"))
                                    Text(area.vision)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineSpacing(4)
                                        .lineLimit(3)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                            }

                            // Task progress
                            let completed = area.tasks.filter { $0.isDone }.count
                            let total = area.tasks.count
                            if total > 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TASK PROGRESS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(Color(hex: "#BA7517"))
                                    HStack {
                                        Text("\(completed) of \(total) tasks completed")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                        Spacer()
                                        Text("\(Int(Double(completed) / Double(total) * 100))%")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: "#FAC775"))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.white.opacity(0.08))
                                                .frame(height: 6)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: "#1D9E75"))
                                                .frame(width: geo.size.width * (Double(completed) / Double(total)), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                            }

                            // Rating options
                            VStack(spacing: 10) {
                                CheckInOption(
                                    emoji: "🔥",
                                    title: "Showed up strong",
                                    subtitle: "I lived this area with intention",
                                    rating: .yes,
                                    selected: vm.currentRating() == .yes
                                ) { vm.rate(.yes) }

                                CheckInOption(
                                    emoji: "🌱",
                                    title: "Made some progress",
                                    subtitle: "Good moments but room to grow",
                                    rating: .partly,
                                    selected: vm.currentRating() == .partly
                                ) { vm.rate(.partly) }

                                CheckInOption(
                                    emoji: "💤",
                                    title: "Needs more attention",
                                    subtitle: "This area drifted this month",
                                    rating: .notReally,
                                    selected: vm.currentRating() == .notReally
                                ) { vm.rate(.notReally) }
                            }

                            // Reflection note
                            if vm.currentRating() != .notRated {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ADD A NOTE (optional)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(Color(hex: "#BA7517"))

                                    TextField(
                                        reflectionPlaceholder(for: vm.currentRating()),
                                        text: vm.currentReflection(),
                                        axis: .vertical
                                    )
                                    .lineLimit(2...4)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                    .tint(Color(hex: "#BA7517"))
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))

                                Button {
                                    vm.advance()
                                } label: {
                                    HStack {
                                        Text(vm.isLastArea ? "Complete check-in" : "Next area")
                                            .font(.system(size: 16, weight: .medium))
                                        if !vm.isLastArea {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 14, weight: .medium))
                                        } else {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(hex: "#BA7517"))
                                    .foregroundColor(Color(hex: "#1A1208"))
                                    .cornerRadius(14)
                                }
                                .transition(.opacity)
                            }

                            if vm.currentIndex > 0 {
                                Button("← Previous area") { vm.goBack() }
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 24)
                        .animation(.easeInOut(duration: 0.3), value: vm.currentRating())
                    }
                }
            }
        }
    }

    // MARK: - Complete view
    private var completeView: some View {
        ZStack {
            Color(hex: "#1A1208").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#BA7517").opacity(0.15))
                            .frame(width: 100, height: 100)
                        Circle()
                            .stroke(Color(hex: "#BA7517").opacity(0.3), lineWidth: 1)
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(Color(hex: "#FAC775"))
                    }

                    VStack(spacing: 10) {
                        Text("Check-in complete")
                            .font(.custom("Georgia", size: 28))
                            .foregroundColor(Color(hex: "#FAC775"))
                        Text("Your \(vm.monthLabel) growth story is ready.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Stats
                    if let report = vm.realReport {
                        HStack(spacing: 0) {
                            CompleteStat(
                                value: "\(report.completedActions)",
                                label: "tasks done",
                                icon: "checkmark.circle.fill"
                            )
                            CompleteStat(
                                value: "\(report.canvasChanges.reduce(0) { $0 + $1.delta })",
                                label: "growth pts",
                                icon: "arrow.up.circle.fill"
                            )
                            CompleteStat(
                                value: "\(vm.areas.filter { (vm.ratings[$0.name] ?? .notRated) == .yes }.count)",
                                label: "areas 🔥",
                                icon: "flame.fill"
                            )
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                    }

                    // Area summary
                    VStack(spacing: 10) {
                        ForEach(vm.areas) { area in
                            HStack(spacing: 10) {
                                Text(area.emoji)
                                    .font(.system(size: 16))
                                Text(area.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                let rating = vm.ratings[area.name] ?? .notRated
                                Text(ratingEmoji(rating))
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 12) {
                    if vm.isLoadingStory {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(Color(hex: "#BA7517"))
                            Text("Claude is writing your growth story...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 8)
                    }

                    Button {
                        navigateToStory = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("See my growth story")
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            vm.isLoadingStory || vm.aiStory == nil
                                ? Color.white.opacity(0.1)
                                : Color(hex: "#BA7517")
                        )
                        .foregroundColor(
                            vm.isLoadingStory || vm.aiStory == nil
                                ? .white.opacity(0.3)
                                : Color(hex: "#1A1208")
                        )
                        .cornerRadius(14)
                    }
                    .disabled(vm.isLoadingStory || vm.aiStory == nil)

                    Button("Close") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private func reflectionPlaceholder(for rating: CheckInRating) -> String {
        switch rating {
        case .yes:       return "What made this area shine this month?"
        case .partly:    return "What held you back from going all in?"
        case .notReally: return "What got in the way? What will you do differently?"
        case .notRated:  return ""
        }
    }

    private func ratingEmoji(_ rating: CheckInRating) -> String {
        switch rating {
        case .yes:       return "🔥"
        case .partly:    return "🌱"
        case .notReally: return "💤"
        case .notRated:  return "—"
        }
    }
}

// MARK: - Check-in option card
private struct CheckInOption: View {
    let emoji: String
    let title: String
    let subtitle: String
    let rating: CheckInRating
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selected ? Color(hex: "#1A1208") : .white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(selected ? Color(hex: "#412402").opacity(0.7) : .white.opacity(0.4))
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#412402"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? Color(hex: "#FAC775") : Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selected ? Color(hex: "#BA7517") : Color.white.opacity(0.08),
                        lineWidth: selected ? 1.5 : 0.5
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

// MARK: - Complete stat
private struct CompleteStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#BA7517"))
            Text(value)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "#FAC775"))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}
