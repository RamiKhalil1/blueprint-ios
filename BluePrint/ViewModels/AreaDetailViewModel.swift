import SwiftUI
import SwiftData
import Combine

final class AreaDetailViewModel: ObservableObject {

    @Published var area: LifeArea
    @Published var blockers: [Blocker] = []
    @Published var isLoadingBlockers = false
    @Published var isUpdatingReality = false

    private let modelContext: ModelContext

    init(area: LifeArea, modelContext: ModelContext) {
        self.area = area
        self.modelContext = modelContext
    }

    /// Sync progress score from task completion state.
    /// Called from the view's .task modifier so it runs after the context is ready.
    func syncProgress() {
        let completed = area.tasks.filter { $0.isDone }.count
        let total = area.tasks.count
        guard total > 0 else { return }
        let calculated = Double(completed) / Double(total)
        if area.progressScore != calculated {
            area.progressScore = calculated
            try? modelContext.save()
        }
    }

    // MARK: - Toggle Task
    func toggleTask(_ task: AreaTask) {
        task.isDone.toggle()
        task.completedAt = task.isDone ? .now : nil

        // Progress = completed tasks / total tasks
        let completed = area.tasks.filter { $0.isDone }.count
        let total = area.tasks.count
        area.progressScore = total > 0 ? Double(completed) / Double(total) : 0.0

        area.updatedAt = .now
        updateStatus()
        try? modelContext.save()

        // Update current reality every time a task is completed
        if task.isDone {
            let completedTasks = area.tasks.filter { $0.isDone }.map { $0.title }
            Task { await updateCurrentReality(completedTasks: completedTasks) }
        }
    }

    // MARK: - AI: Update current reality
    @MainActor
    func updateCurrentReality(completedTasks: [String]) async {
        isUpdatingReality = true
        do {
            let updated = try await AIService.shared.updateCurrentReality(
                areaName: area.name,
                vision: area.vision,
                originalReality: area.currentReality,
                completedTasks: completedTasks
            )
            area.currentReality = updated
            area.updatedAt = .now
            try? modelContext.save()
        } catch {
            print("❌ Reality update failed: \(error)")
        }
        isUpdatingReality = false
    }

    // MARK: - AI: Load blockers
    func loadAIBlockers() async {
        guard !Task.isCancelled else { return }
        let currentMonth = MonthlyRecord.currentMonthKey()

        if !area.aiBlockerTypes.isEmpty && area.blockersMonthKey == currentMonth {
            let cached = zip(area.aiBlockerTypes, area.aiBlockerTexts).map { type, text in
                Blocker(type: BlockerType(rawValue: type) ?? .decision, text: text)
            }
            await MainActor.run { self.blockers = cached }
            return
        }

        await MainActor.run { isLoadingBlockers = true }

        do {
            let context = AreaContext(
                areaType: area.name,
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
            await MainActor.run { isLoadingBlockers = false }
        }
    }

    // MARK: - Status
    private func updateStatus() {
        switch area.progressScore {
        case 0.30...: area.statusEnum = .onTrack
        case 0.01..<0.30: area.statusEnum = .drifting
        default: area.statusEnum = .notStarted
        }
        try? modelContext.save()
    }

    // MARK: - Computed
    var statusColor: Color {
        area.statusEnum == .onTrack ? Color(hex: "#1D9E75") : Color(hex: "#7F77DD")
    }

    var progressPercent: Int { Int(area.progressScore * 100) }
    var completedTaskCount: Int { area.tasks.filter { $0.isDone }.count }
    var totalTaskCount: Int { area.tasks.count }

    var tasks: [AreaTask] {
        area.tasks.sorted { $0.sortIndex < $1.sortIndex }
    }
}

// MARK: - Supporting types
struct Blocker: Identifiable {
    let id = UUID()
    let type: BlockerType
    let text: String
}

enum BlockerType: String {
    case money, time, decision, mindset, skill, resource, habit

    var label: String {
        switch self {
        case .money: return "Money"
        case .time: return "Time"
        case .decision: return "Decision"
        case .mindset:  return "Mindset"
        case .skill: return "Skill"
        case .resource: return "Resource"
        case .habit: return "Habit"
        }
    }

    var color: Color {
        switch self {
        case .money, .resource: return Color(hex: "#FAEEDA")
        case .time, .skill: return Color(hex: "#E1F5EE")
        case .decision, .mindset, .habit: return Color(hex: "#EEEDFE")
        }
    }

    var textColor: Color {
        switch self {
        case .money, .resource: return Color(hex: "#633806")
        case .time, .skill: return Color(hex: "#085041")
        case .decision, .mindset, .habit: return Color(hex: "#3C3489")
        }
    }
}
