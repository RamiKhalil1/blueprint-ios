import SwiftUI
import SwiftData
import Combine

final class DashboardViewModel: ObservableObject {

    @Published var lifeAreas: [LifeArea] = []
    @Published var greetingName: String = ""

    private var modelContext: ModelContext?

    init() {}

    func load(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAreas(modelContext: modelContext)
    }

    private func loadAreas(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else { return }
        lifeAreas = canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }
    }

    var overallGrowthScore: Int {
        guard !lifeAreas.isEmpty else { return 0 }
        let total = lifeAreas.reduce(0.0) { $0 + $1.progressScore }
        return Int((total / Double(lifeAreas.count)) * 100)
    }

    var journeyWeeks: Int {
        guard let area = lifeAreas.first else { return 1 }
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: area.createdAt, to: .now).weekOfYear ?? 0
        return max(weeks + 1, 1)
    }

    var allAreasComplete: Bool {
        lifeAreas.allSatisfy { !$0.vision.isEmpty && !$0.currentReality.isEmpty }
    }

    var incompleteAreas: [String] {
        lifeAreas
            .filter { $0.vision.isEmpty || $0.currentReality.isEmpty }
            .map { $0.name }
    }

    func toggleTask(_ task: WeeklyTaskItem) {
        task.isDone.toggle()
        try? modelContext?.save()
    }

}
