import SwiftUI
import SwiftData
import Combine

final class IncomeIntentViewModel: ObservableObject {

    @Published var monthlyIncome: Double = 3200
    @Published var allocations: [IncomeAllocation] = []
    @Published var incomeInput: String = "3200"
    @Published var isSaved: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAllocations()
    }

    // MARK: - Load
    func loadAllocations() {
        let record = MonthlyDataService.shared.currentRecord(in: modelContext)
        if record.incomeAmount > 0 {
            monthlyIncome = record.incomeAmount
            incomeInput = String(Int(record.incomeAmount))
        }

        allocations = LifeAreaType.allCases.map { type in
            IncomeAllocation(areaType: type, percentage: defaultPercentage(for: type))
        }
    }

    // MARK: - Computed
    var totalAllocated: Double {
        allocations.reduce(0) { $0 + $1.percentage }
    }

    var unallocatedPercentage: Double {
        max(0, 100 - totalAllocated)
    }

    var unallocatedAmount: Double {
        monthlyIncome * unallocatedPercentage / 100
    }

    var isOverAllocated: Bool {
        totalAllocated > 100
    }

    func amount(for allocation: IncomeAllocation) -> Double {
        monthlyIncome * allocation.percentage / 100
    }

    // MARK: - Actions
    func updatePercentage(for id: UUID, to value: Double) {
        guard let index = allocations.firstIndex(where: { $0.id == id }) else { return }
        allocations[index].percentage = min(value, 100)
    }

    func updateIncome() {
        if let value = Double(incomeInput.filter { $0.isNumber || $0 == "." }) {
            monthlyIncome = value
        }
    }

    func save() {
        MonthlyDataService.shared.syncIncomeIntent(
            monthlyIncome: monthlyIncome,
            allocations: allocations,
            into: modelContext
        )

        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isSaved = false
        }
    }

    // MARK: - Defaults
    private func defaultPercentage(for type: LifeAreaType) -> Double {
        switch type {
        case .experiences: return 10
        case .place:       return 30
        case .workTime:    return 10
        case .identity:    return 15
        case .finance:     return 15
        }
    }
}

// MARK: - Model
struct IncomeAllocation: Identifiable {
    let id = UUID()
    let areaType: LifeAreaType
    var percentage: Double
}
