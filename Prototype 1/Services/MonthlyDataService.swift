import SwiftData
import Foundation

final class MonthlyDataService {

    static let shared = MonthlyDataService()
    private init() {}

    // MARK: - Current record
    func currentRecord(in context: ModelContext) -> MonthlyRecord {
        let key = MonthlyRecord.currentMonthKey()
        let descriptor = FetchDescriptor<MonthlyRecord>(
            predicate: #Predicate { $0.monthKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let record = MonthlyRecord(monthKey: key, monthLabel: MonthlyRecord.currentMonthLabel())
        context.insert(record)
        try? context.save()
        return record
    }

    // MARK: - Sync income
    func syncIncomeIntent(monthlyIncome: Double, allocations: [IncomeAllocation], into context: ModelContext) {
        let record = currentRecord(in: context)
        record.incomeAmount = monthlyIncome
        let savingsAreas: [LifeAreaType] = [.experiences, .identity, .finance]
        record.savedAmount = allocations
            .filter { savingsAreas.contains($0.areaType) }
            .reduce(0.0) { $0 + (monthlyIncome * $1.percentage / 100) }
        try? context.save()
    }

    // MARK: - Sync tasks (now uses WeeklyTaskItem directly)
    func syncCompletedTaskItems(_ tasks: [WeeklyTaskItem], into context: ModelContext) {
        let record = currentRecord(in: context)
        let completed = tasks.filter { $0.isDone }.map { $0.title }
        var existing = Set(record.completedActionTitles)
        existing.formUnion(completed)
        record.completedActionTitles = Array(existing)
        record.totalActionCount = max(record.totalActionCount, tasks.count)
        try? context.save()
    }

    // MARK: - Sync check-in ratings
    func syncCheckInRatings(ratings: [LifeAreaType: CheckInRating], into context: ModelContext) {
        let record = currentRecord(in: context)
        for (area, rating) in ratings {
            record.areaRatings[area.rawValue] = rating.rawValue
        }
        for (area, rating) in ratings {
            let delta: Int
            switch rating {
            case .yes:       delta = 2
            case .partly:    delta = 1
            case .notReally: delta = 0
            case .notRated:  delta = 0
            }
            if delta > 0 { record.canvasDeltas[area.rawValue] = delta }
        }
        let canvasDescriptor = FetchDescriptor<Canvas>()
        if let canvas = try? context.fetch(canvasDescriptor).first {
            for area in canvas.lifeAreas {
                if let rating = ratings[area.type] {
                    switch rating {
                    case .yes:       area.progressScore = min(area.progressScore + 0.15, 1.0); area.statusEnum = .onTrack
                    case .partly:    area.progressScore = min(area.progressScore + 0.05, 1.0); area.statusEnum = .onTrack
                    case .notReally: area.statusEnum = .drifting
                    case .notRated:  break
                    }
                    area.updatedAt = .now
                }
            }
        }
        try? context.save()
    }

    // MARK: - Build report
    func buildReport(in context: ModelContext) -> MonthlyReport {
        currentRecord(in: context).toMonthlyReport
    }
}
