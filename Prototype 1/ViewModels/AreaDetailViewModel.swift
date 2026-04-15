import SwiftUI
import SwiftData
import Combine

final class AreaDetailViewModel: ObservableObject {

    @Published var area: LifeArea
    @Published var vision: String
    @Published var currentReality: String
    @Published var blockers: [Blocker] = []
    @Published var actions: [AreaAction] = []
    @Published var isEditingVision = false
    @Published var isLoadingActions = false
    @Published var isLoadingBlockers = false

    private let modelContext: ModelContext

    init(area: LifeArea, modelContext: ModelContext) {
        self.area = area
        self.vision = area.vision
        self.currentReality = area.currentReality
        self.modelContext = modelContext
        self.blockers = []
        self.actions = []
    }

    // MARK: - Save
    func saveVision() {
        area.vision = vision
        area.updatedAt = .now
        try? modelContext.save()
        isEditingVision = false
    }

    func saveReality() {
        area.currentReality = currentReality
        area.updatedAt = .now
        try? modelContext.save()
    }
    
    func loadAIActions() async {
        guard !Task.isCancelled else { return }
        let currentMonth = MonthlyRecord.currentMonthKey()
        let storedMonth = area.actionsMonthKey

        if !area.aiActionTitles.isEmpty && storedMonth == currentMonth {
            // Use cached AI actions from this month
            var cached = area.aiActionTitles.map {
                AreaAction(title: $0, areaType: area.type)
            }
            for i in cached.indices {
                if area.completedActionTitles.contains(cached[i].title) {
                    cached[i].isDone = true
                }
            }
            await MainActor.run { self.actions = cached }
            return
        }

        await MainActor.run { isLoadingActions = true }

        do {
            let context = AreaContext(
                areaType: area.type.displayName,
                vision: area.vision,
                currentReality: area.currentReality
            )
            let aiActions = try await AIService.shared.generateAreaActions(for: context)
            let newActions = aiActions.map { AreaAction(title: $0.title, areaType: area.type) }

            area.aiActionTitles = aiActions.map { $0.title }
            area.actionsMonthKey = currentMonth
            try? modelContext.save()

            await MainActor.run {
                self.actions = newActions
                self.isLoadingActions = false
            }
        } catch {
            await MainActor.run { isLoadingActions = false }
        }
    }
    
    func loadAIBlockers() async {
        guard !Task.isCancelled else { return }

        let currentMonth = MonthlyRecord.currentMonthKey()

        if !area.aiBlockerTypes.isEmpty && area.blockersMonthKey == currentMonth {
            let cached = zip(area.aiBlockerTypes, area.aiBlockerTexts).map { type, text in
                Blocker(
                    type: BlockerType(rawValue: type) ?? .decision,
                    text: text
                )
            }
            await MainActor.run { self.blockers = cached }
            return
        }

        await MainActor.run { isLoadingBlockers = true }

        do {
            let context = AreaContext(
                areaType: area.type.displayName,
                vision: area.vision,
                currentReality: area.currentReality
            )
            let aiBlockers = try await AIService.shared.generateBlockers(for: context)

            area.aiBlockerTypes = aiBlockers.map { $0.type }
            area.aiBlockerTexts = aiBlockers.map { $0.text }
            area.blockersMonthKey = currentMonth
            try? modelContext.save()

            await MainActor.run {
                self.blockers = aiBlockers.map {
                    Blocker(type: $0.blockerType, text: $0.text)
                }
                self.isLoadingBlockers = false
            }
        } catch {
            print("❌ Blocker AI error: \(error)")
            await MainActor.run {
                self.blockers = Self.generateBlockers(for: area)
                self.isLoadingBlockers = false
            }
        }
    }

    func toggleAction(_ action: AreaAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index].isDone.toggle()
        let title = actions[index].title
        if actions[index].isDone {
            if !area.completedActionTitles.contains(title) {
                area.completedActionTitles.append(title)
            }
        } else {
            area.completedActionTitles.removeAll { $0 == title }
        }
        try? modelContext.save()
        syncActionsToMonthlyRecord()
    }

    private func syncActionsToMonthlyRecord() {
        let allCompleted = actions.filter { $0.isDone }.map { $0.title }
        let record = MonthlyDataService.shared.currentRecord(in: modelContext)
        var existing = Set(record.completedActionTitles)
        existing.formUnion(allCompleted)
        record.completedActionTitles = Array(existing)
        record.totalActionCount = max(record.totalActionCount, actions.count)
        try? modelContext.save()
    }

    // MARK: - Computed
    var statusColor: Color {
        area.statusEnum == .onTrack ? Color(hex: "#1D9E75") : Color(hex: "#7F77DD")
    }

    var progressPercent: Int {
        Int(area.progressScore * 100)
    }

    // MARK: - Stubs (Phase 3 replaces with AI)
    private static func generateBlockers(for area: LifeArea) -> [Blocker] {
        switch area.type {
        case .experiences:
            return [
                Blocker(type: .money, text: "Discretionary budget already used"),
                Blocker(type: .time,  text: "Weekends over-committed")
            ]
        case .finance:
            return [
                Blocker(type: .decision, text: "Haven't reviewed investment allocation"),
                Blocker(type: .money,    text: "Irregular income makes planning hard")
            ]
        case .workTime:
            return [
                Blocker(type: .time,     text: "Meeting load leaves little deep work"),
                Blocker(type: .decision, text: "Haven't set clear work boundaries")
            ]
        case .identity:
            return [
                Blocker(type: .time, text: "Self-care deprioritised under pressure")
            ]
        case .place:
            return [
                Blocker(type: .money,    text: "Rent constraints limit options"),
                Blocker(type: .decision, text: "Unclear on what 'right place' means")
            ]
        }
    }

    private static func generateActions(for area: LifeArea) -> [AreaAction] {
        switch area.type {
        case .experiences:
            return [
                AreaAction(title: "Book that next trip you've been putting off", areaType: area.type),
                AreaAction(title: "Go to one live event this month", areaType: area.type)
            ]
        case .finance:
            return [
                AreaAction(title: "Review investment allocation", areaType: area.type),
                AreaAction(title: "Cut one unused subscription", areaType: area.type)
            ]
        case .workTime:
            return [
                AreaAction(title: "Block two mornings for deep work", areaType: area.type),
                AreaAction(title: "Research one creative course", areaType: area.type)
            ]
        case .identity:
            return [
                AreaAction(title: "30 min workout this week", areaType: area.type),
                AreaAction(title: "One thing just for you this weekend", areaType: area.type)
            ]
        case .place:
            return [
                AreaAction(title: "Visit one new neighbourhood", areaType: area.type),
                AreaAction(title: "List what you love about where you live", areaType: area.type)
            ]
        }
    }
}

// MARK: - Supporting types
struct Blocker: Identifiable {
    let id = UUID()
    let type: BlockerType
    let text: String
}

enum BlockerType: String {
    case money, time, decision

    var label: String {
        switch self {
        case .money:    return "Money"
        case .time:     return "Time"
        case .decision: return "Decision"
        }
    }

    var color: Color {
        switch self {
        case .money:    return Color(hex: "#FAEEDA")
        case .time:     return Color(hex: "#E1F5EE")
        case .decision: return Color(hex: "#EEEDFE")
        }
    }

    var textColor: Color {
        switch self {
        case .money:    return Color(hex: "#633806")
        case .time:     return Color(hex: "#085041")
        case .decision: return Color(hex: "#3C3489")
        }
    }
}

struct AreaAction: Identifiable {
    let id = UUID()
    let title: String
    let areaType: LifeAreaType
    var isDone: Bool = false
    var monthKey: String = MonthlyRecord.currentMonthKey()
}
