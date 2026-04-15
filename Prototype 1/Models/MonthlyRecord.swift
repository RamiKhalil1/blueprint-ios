import SwiftData
import Foundation

// MARK: - MonthlyRecord
// Persists one month's worth of real data for the growth story

@Model
final class MonthlyRecord {
    var id: UUID
    var monthKey: String
    var monthLabel: String
    var savedAmount: Double
    var incomeAmount: Double
    var completedActionTitles: [String]
    var totalActionCount: Int
    var areaRatings: [String: String]
    var canvasDeltas: [String: Int]
    var createdAt: Date

    init(monthKey: String, monthLabel: String) {
        self.id = UUID()
        self.monthKey = monthKey
        self.monthLabel = monthLabel
        self.savedAmount = 0
        self.incomeAmount = 0
        self.completedActionTitles = []
        self.totalActionCount = 0
        self.areaRatings = [:]
        self.canvasDeltas = [:]
        self.createdAt = .now
    }

    // MARK: - Computed
    var completedCount: Int { completedActionTitles.count }

    var highlights: [String] {
        areaRatings
            .filter { $0.value == CheckInRating.yes.rawValue }
            .compactMap { LifeAreaType(rawValue: $0.key)?.displayName }
    }

    var canvasChanges: [(area: String, delta: Int)] {
        canvasDeltas
            .compactMap { key, val -> (String, Int)? in
                guard let type = LifeAreaType(rawValue: key) else { return nil }
                return (type.displayName, val)
            }
            .sorted { $0.1 > $1.1 }
    }

    var toMonthlyReport: MonthlyReport {
        MonthlyReport(
            month: monthLabel,
            savedAmount: savedAmount,
            completedActions: completedCount,
            totalActions: totalActionCount,
            canvasChanges: canvasChanges,
            highlights: highlights
        )
    }
}

// MARK: - Helpers
extension MonthlyRecord {
    static func currentMonthKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: .now)
    }

    static func currentMonthLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: .now)
    }
}
