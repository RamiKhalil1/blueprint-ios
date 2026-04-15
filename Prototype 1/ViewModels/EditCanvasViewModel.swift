import SwiftUI
import SwiftData
import Combine

final class EditCanvasViewModel: ObservableObject {

    @Published var lifeAreas: [LifeArea] = []
    @Published var editingArea: LifeArea? = nil
    @Published var draftVision: String = ""
    @Published var showAddArea: Bool = false
    @Published var newAreaName: String = ""

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
    }

    // MARK: - Load
    func load() {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else { return }
        lifeAreas = canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }
    }

    // MARK: - Edit
    func startEditing(_ area: LifeArea) {
        draftVision = area.vision
        editingArea = area
    }

    func saveEdit() {
        guard let area = editingArea else { return }
        area.vision = draftVision
        area.updatedAt = .now
        try? modelContext.save()
        editingArea = nil
        draftVision = ""
        load()
    }

    func cancelEdit() {
        editingArea = nil
        draftVision = ""
    }

    // MARK: - Reorder
    func moveArea(from source: IndexSet, to destination: Int) {
        lifeAreas.move(fromOffsets: source, toOffset: destination)
        for (index, area) in lifeAreas.enumerated() {
            area.priorityRank = index + 1
        }
        try? modelContext.save()
    }
}
