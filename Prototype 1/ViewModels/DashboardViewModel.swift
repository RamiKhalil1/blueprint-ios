import SwiftUI
import SwiftData
import Combine

final class DashboardViewModel: ObservableObject {

    @Published var lifeAreas: [LifeArea] = []
    @Published var weeklyTasks: [WeeklyTaskItem] = []
    @Published var greetingName: String = ""

    private var modelContext: ModelContext?

    init() {}

    func load(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAreas(modelContext: modelContext)
        loadWeeklyTasks(modelContext: modelContext)
    }

    private func loadAreas(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else { return }
        lifeAreas = canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }
    }

    private func loadWeeklyTasks(modelContext: ModelContext, retryCount: Int = 0) {
        let weekKey = WeeklyTaskItem.currentWeekKey()
        let descriptor = FetchDescriptor<WeeklyTaskItem>(
            predicate: #Predicate { $0.weekKey == weekKey }
        )
        let fetched = (try? modelContext.fetch(descriptor))?.sorted { $0.createdAt < $1.createdAt } ?? []

        if fetched.isEmpty && retryCount < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.loadWeeklyTasks(modelContext: modelContext, retryCount: retryCount + 1)
            }
        } else {
            weeklyTasks = fetched
        }
    }
    
    var allAreasComplete: Bool {
        lifeAreas.allSatisfy { !$0.vision.isEmpty && !$0.currentReality.isEmpty }
    }

    var incompleteAreas: [String] {
        lifeAreas
            .filter { $0.vision.isEmpty || $0.currentReality.isEmpty }
            .map { $0.type.displayName }
    }

    func toggleTask(_ task: WeeklyTaskItem) {
        task.isDone.toggle()
        try? modelContext?.save()
    }
    
    func generateTasksIfNeeded(modelContext: ModelContext) {
        guard allAreasComplete else { return }
        let weekKey = WeeklyTaskItem.currentWeekKey()
        let descriptor = FetchDescriptor<WeeklyTaskItem>(
            predicate: #Predicate { $0.weekKey == weekKey }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let canvasDescriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(canvasDescriptor).first else { return }
        let reflections = canvas.reflections
            .sorted { $0.questionIndex < $1.questionIndex }
            .filter { !$0.answer.isEmpty }
            .map { (question: $0.questionText, answer: $0.answer) }

        let context = CanvasContext(
            lifeAreas: canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }.map {
                (type: $0.type, vision: $0.vision, currentReality: $0.currentReality, status: $0.statusEnum, progressScore: $0.progressScore, priorityRank: $0.priorityRank)
            },
            reflections: reflections
        )

        Task { @MainActor in
            do {
                let aiTasks = try await AIService.shared.generateWeeklyActions(for: context)
                for task in aiTasks.map({ WeeklyTaskItem(title: $0.title, areaType: $0.lifeAreaType, note: $0.note) }) {
                    modelContext.insert(task)
                }
                try? modelContext.save()
            } catch {
                let fallback = [
                    WeeklyTaskItem(title: "Review your top priority this week", areaType: .finance),
                    WeeklyTaskItem(title: "30 min workout", areaType: .identity),
                    WeeklyTaskItem(title: "Research one new experience", areaType: .experiences)
                ]
                for task in fallback { modelContext.insert(task) }
                try? modelContext.save()
            }
        }
    }
}
