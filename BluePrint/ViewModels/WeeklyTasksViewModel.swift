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

    @MainActor
    func generateAITasks() async {
        guard let modelContext else { return }
        isLoadingAI = true
        aiError = nil

        do {
            let context = buildCanvasContext(modelContext: modelContext)
            let aiTasks = try await AIService.shared.generateWeeklyActions(for: context)
            let generated = aiTasks.map {
                WeeklyTaskItem(title: $0.title, areaName: $0.areaName, note: $0.note)
            }
            for task in generated { modelContext.insert(task) }
            try? modelContext.save()
            tasks = generated
        } catch {
            aiError = "Using default actions."
            let fallback = staticFallback(modelContext: modelContext)
            for task in fallback { modelContext.insert(task) }
            try? modelContext.save()
            tasks = fallback
        }
        isLoadingAI = false
    }

    func toggleTask(_ task: WeeklyTaskItem) {
        task.isDone.toggle()
        save()
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
                WeeklyTaskItem(title: $0.title, areaName: $0.areaName, note: $0.note)
            }
        } catch {
            swapOptions = staticFallback(modelContext: modelContext)
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

    var completedCount: Int { tasks.filter { $0.isDone }.count }
    var totalCount: Int { tasks.count }

    var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
        let end = cal.date(byAdding: .day, value: 6, to: start)!
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func save() {
        try? modelContext?.save()
    }

    private func buildCanvasContext(modelContext: ModelContext) -> CanvasContext {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else {
            return CanvasContext(lifeAreas: [], reflections: [])
        }
        let answers = canvas.onboardingAnswers
            .filter { !$0.answer.isEmpty }
            .map { (question: $0.question, answer: $0.answer) }

        return CanvasContext(
            lifeAreas: canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }.map {
                (name: $0.name, emoji: $0.emoji, vision: $0.vision, currentReality: $0.currentReality, status: $0.statusEnum, progressScore: $0.progressScore, priorityRank: $0.priorityRank)
            },
            reflections: answers
        )
    }

    private func staticFallback(modelContext: ModelContext) -> [WeeklyTaskItem] {
        let canvasDescriptor = FetchDescriptor<Canvas>()
        let firstName = (try? modelContext.fetch(canvasDescriptor).first)?.lifeAreas.first?.name ?? "Growth"
        return [
            WeeklyTaskItem(title: "Review your top priority this week", areaName: firstName),
            WeeklyTaskItem(title: "30 min workout", areaName: firstName),
            WeeklyTaskItem(title: "Research one new experience", areaName: firstName),
            WeeklyTaskItem(title: "Connect with someone you admire", areaName: firstName),
            WeeklyTaskItem(title: "Spend 20 mins on your vision", areaName: firstName),
            WeeklyTaskItem(title: "Do one thing that scares you", areaName: firstName)
        ]
    }
}
