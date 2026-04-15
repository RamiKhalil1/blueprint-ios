import SwiftUI
import SwiftData
import Combine

final class MonthlyCheckInViewModel: ObservableObject {

    @Published var ratings: [LifeAreaType: CheckInRating] = [:]
    @Published var reflections: [LifeAreaType: String] = [:]
    @Published var currentIndex: Int = 0
    @Published var isComplete: Bool = false
    @Published var isLoadingStory: Bool = false
    @Published var aiStory: StoryNarrative? = nil
    @Published var realReport: MonthlyReport? = nil

    let areas: [LifeAreaType] = LifeAreaType.allCases
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        for area in LifeAreaType.allCases {
            ratings[area] = .notRated
            reflections[area] = ""
        }
    }

    // MARK: - Computed
    var currentArea: LifeAreaType { areas[currentIndex] }
    var ratedCount: Int { ratings.values.filter { $0 != .notRated }.count }
    var progress: Double { Double(ratedCount) / Double(areas.count) }
    var isLastArea: Bool { currentIndex == areas.count - 1 }

    var monthLabel: String {
        MonthlyRecord.currentMonthLabel()
    }

    // MARK: - Rating
    func rate(_ rating: CheckInRating) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.ratings[self.currentArea] = rating
            }
        }
    }

    func advance() {
        guard ratings[currentArea] != .notRated else { return }
        if isLastArea {
            finalise()
        } else {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.currentIndex += 1
                }
            }
        }
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation { currentIndex -= 1 }
    }

    // MARK: - Finalise
    private func finalise() {
        MonthlyDataService.shared.syncCheckInRatings(ratings: ratings, into: modelContext)
        let report = MonthlyDataService.shared.buildReport(in: modelContext)
        realReport = report
        isComplete = true
        Task { await generateStory(for: report) }
    }

    var formattedReflections: String {
        reflections
            .filter { !$0.value.isEmpty }
            .map { "\($0.key.displayName): \($0.value)" }
            .joined(separator: "\n")
    }

    // MARK: - AI story
    @MainActor
    func generateStory(for report: MonthlyReport) async {
        isLoadingStory = true
        do {
            aiStory = try await AIService.shared.generateMonthlyStory(for: report)
        } catch {
            let bestArea = ratings
                .filter { $0.value == .yes }
                .map { $0.key.displayName }
                .first ?? "your canvas"

            let worstArea = ratings
                .filter { $0.value == .notReally }
                .map { $0.key.displayName }
                .first

            let narrative = worstArea != nil
                ? "You showed up for \(bestArea) this month. \(worstArea!) needs more attention next month — that's where your focus goes."
                : "You showed up across all your life areas this month. That consistency is what builds real momentum."

            aiStory = StoryNarrative(
                headline: "You showed up this month.",
                narrative: narrative,
                nextFocus: worstArea ?? bestArea
            )
        }
        isLoadingStory = false
    }
}

// MARK: - CheckInRating
enum CheckInRating: String, CaseIterable {
    case notRated  = "notRated"
    case yes       = "yes"
    case partly    = "partly"
    case notReally = "notReally"

    var label: String {
        switch self {
        case .notRated:  return "—"
        case .yes:       return "Yes"
        case .partly:    return "Partly"
        case .notReally: return "Not really"
        }
    }

    var color: Color {
        switch self {
        case .notRated:  return Color(.systemBackground)
        case .yes:       return Color(hex: "#EAF3DE")
        case .partly:    return Color(hex: "#FAEEDA")
        case .notReally: return Color(hex: "#F1EFE8")
        }
    }

    var textColor: Color {
        switch self {
        case .notRated:  return .secondary
        case .yes:       return Color(hex: "#27500A")
        case .partly:    return Color(hex: "#633806")
        case .notReally: return Color(hex: "#5F5E5A")
        }
    }
}
