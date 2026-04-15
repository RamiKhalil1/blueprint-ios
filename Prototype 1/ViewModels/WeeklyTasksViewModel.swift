import SwiftUI
import SwiftData
import Combine

final class WeeklyTasksViewModel: ObservableObject {

    @Published var tasks: [WeeklyTaskItem] = []
    @Published var showSwapSheet = false
    @Published var taskToSwap: WeeklyTaskItem? = nil
    @Published var swapOptions: [WeeklyTaskItem] = []
    @Published var isLoadingAI = false
    @Published var isLoadingSwap = false
    @Published var aiError: String? = nil

    private var modelContext: ModelContext?

    init() {}

    // MARK: - Load (called from view with real context)
    func load(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPersistedTasks()
    }

    private func loadPersistedTasks() {
        guard let modelContext else { return }

        let canvasDescriptor = FetchDescriptor<Canvas>()
        if let canvas = try? modelContext.fetch(canvasDescriptor).first {
            let allComplete = canvas.lifeAreas.allSatisfy {
                !$0.vision.isEmpty && !$0.currentReality.isEmpty
            }
            guard allComplete else { return }
        }

        let weekKey = WeeklyTaskItem.currentWeekKey()

        let allDescriptor = FetchDescriptor<WeeklyTaskItem>()
        let allTasks = (try? modelContext.fetch(allDescriptor)) ?? []
        for task in allTasks where task.weekKey != weekKey {
            modelContext.delete(task)
        }
        try? modelContext.save()

        let descriptor = FetchDescriptor<WeeklyTaskItem>(
            predicate: #Predicate { $0.weekKey == weekKey }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        if existing.isEmpty || existing.count < 6 {
            for task in existing { modelContext.delete(task) }
            try? modelContext.save()
            Task { await generateAITasks() }
        } else {
            tasks = existing.sorted { $0.createdAt < $1.createdAt }
        }
    }

    // MARK: - AI generation
    @MainActor
    func generateAITasks() async {
        guard let modelContext else { return }
        isLoadingAI = true
        aiError = nil

        var generated: [WeeklyTaskItem] = []

        do {
            let context = buildCanvasContext(modelContext: modelContext)
            let aiTasks = try await AIService.shared.generateWeeklyActions(for: context)
            generated = aiTasks.map {
                WeeklyTaskItem(title: $0.title, areaType: $0.lifeAreaType, note: $0.note)
            }
        } catch {
            aiError = "Using default actions."
            generated = staticFallback()
        }

        for task in generated {
            modelContext.insert(task)
        }
        try? modelContext.save()

        tasks = generated
        swapOptions = buildSwapOptions()
        isLoadingAI = false
    }

    // MARK: - Toggle / Skip / Swap
    func toggleTask(_ task: WeeklyTaskItem) {
        task.isDone.toggle()
        save()
        MonthlyDataService.shared.syncCompletedTaskItems(tasks, into: modelContext!)
    }

    func skipTask(_ task: WeeklyTaskItem) {
        task.isSkipped = true
        save()
    }

    func requestSwap(for task: WeeklyTaskItem) {
        taskToSwap = task
        swapOptions = []
        showSwapSheet = true
        Task { await generateSwapOptions(for: task) }
    }

    @MainActor
    func generateSwapOptions(for task: WeeklyTaskItem) async {
        guard let modelContext else { return }
        isLoadingSwap = true
        do {
            let canvas = buildCanvasContext(modelContext: modelContext)
            let generated = try await AIService.shared.generateSwapOptions(for: task, canvas: canvas)
            swapOptions = generated.map {
                WeeklyTaskItem(title: $0.title, areaType: $0.lifeAreaType, note: $0.note)
            }
        } catch {
            swapOptions = buildSwapOptions()
        }
        isLoadingSwap = false
    }

    func confirmSwap(replacing old: WeeklyTaskItem, with option: WeeklyTaskItem) {
        guard let modelContext else { return }
        modelContext.delete(old)
        modelContext.insert(option)
        save()
        tasks = tasks.filter { $0.id != old.id } + [option]
        showSwapSheet = false
        taskToSwap = nil
    }

    func refreshWithAI() {
        guard let modelContext else { return }
        for task in tasks { modelContext.delete(task) }
        try? modelContext.save()
        tasks = []
        Task { await generateAITasks() }
    }

    // MARK: - Computed
    var completedCount: Int { tasks.filter { $0.isDone }.count }
    var totalCount: Int { tasks.count }

    var weekLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
        let end = cal.date(byAdding: .day, value: 6, to: start)!
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    // MARK: - Helpers
    private func save() {
        try? modelContext?.save()
    }

    private func buildCanvasContext(modelContext: ModelContext) -> CanvasContext {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else {
            return CanvasContext(lifeAreas: [], reflections: [])
        }
        let reflections = canvas.reflections
            .sorted { $0.questionIndex < $1.questionIndex }
            .filter { !$0.answer.isEmpty }
            .map { (question: $0.questionText, answer: $0.answer) }

        return CanvasContext(
            lifeAreas: canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }.map {
                (type: $0.type, vision: $0.vision, currentReality: $0.currentReality, status: $0.statusEnum, progressScore: $0.progressScore, priorityRank: $0.priorityRank)
            },
            reflections: reflections
        )
    }

    private func staticFallback() -> [WeeklyTaskItem] {[
        WeeklyTaskItem(title: "Review your weekly budget",        areaType: .finance,      note: "Even 10 min helps"),
        WeeklyTaskItem(title: "30 min workout",                   areaType: .identity,     note: "Any movement counts"),
        WeeklyTaskItem(title: "Research one creative course",     areaType: .workTime,     note: "Even 10 min of browsing"),
        WeeklyTaskItem(title: "Plan one experience this month",   areaType: .experiences,  note: "Big or small"),
        WeeklyTaskItem(title: "Visit one new neighbourhood",      areaType: .place,        note: "Take a different route"),
        WeeklyTaskItem(title: "Cut one unused subscription",      areaType: .finance,      note: "Check your bank app")
    ]}

    private func buildSwapOptions() -> [WeeklyTaskItem] {[
        WeeklyTaskItem(title: "Cook one new recipe",       areaType: .experiences),
        WeeklyTaskItem(title: "Call someone you've missed",areaType: .identity),
        WeeklyTaskItem(title: "Go for a walk somewhere new",areaType: .place),
        WeeklyTaskItem(title: "Review your monthly budget",areaType: .finance)
    ]}
}
