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

    // MARK: - Sync check-in ratings
    func syncCheckInRatings(ratings: [String: CheckInRating], into context: ModelContext) {
        let record = currentRecord(in: context)
        for (areaName, rating) in ratings {
            record.areaRatings[areaName] = rating.rawValue
            let delta: Int
            switch rating {
            case .yes: delta = 2
            case .partly: delta = 1
            case .notReally: delta = 0
            case .notRated: delta = 0
            }
            if delta > 0 { record.canvasDeltas[areaName] = delta }
        }
        // Only update status — NOT progress score
        let canvasDescriptor = FetchDescriptor<Canvas>()
        if let canvas = try? context.fetch(canvasDescriptor).first {
            for area in canvas.lifeAreas {
                if let rating = ratings[area.name] {
                    switch rating {
                    case .yes: area.statusEnum = .onTrack
                    case .partly: area.statusEnum = .onTrack
                    case .notReally: area.statusEnum = .drifting
                    case .notRated: break
                    }
                    area.updatedAt = .now
                }
            }
        }
        try? context.save()
    }

    // MARK: - Build report from real AreaTask data
    func buildReport(in context: ModelContext) -> MonthlyReport {
        let record = currentRecord(in: context)
        let canvasDescriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? context.fetch(canvasDescriptor).first else {
            return record.toMonthlyReport
        }

        let lifeAreas = canvas.lifeAreas

        // Count all completed tasks across all areas
        let allTasks = lifeAreas.flatMap { $0.tasks }
        let completedTasks = allTasks.filter { $0.isDone }
        let totalTasks = allTasks.count

        // Area progress data
        let areaProgress: [(name: String, emoji: String, completed: Int, total: Int, progress: Double, rating: CheckInRating)] = lifeAreas.map { area in
            let completed = area.tasks.filter { $0.isDone }.count
            let total = area.tasks.count
            let progress = total > 0 ? Double(completed) / Double(total) : 0
            let rating = CheckInRating(rawValue: record.areaRatings[area.name] ?? "notRated") ?? .notRated
            return (name: area.name, emoji: area.emoji, completed: completed, total: total, progress: progress, rating: rating)
        }

        // Best area = most tasks completed
        let bestArea = areaProgress.max { $0.completed < $1.completed }

        // Areas that showed up strong
        let strongAreas = areaProgress.filter { $0.rating == .yes }.map { "\($0.emoji) \($0.name)" }

        return MonthlyReport(
            month: record.monthLabel,
            savedAmount: 0,
            completedActions: completedTasks.count,
            totalActions: totalTasks,
            canvasChanges: record.canvasDeltas.map { (area: $0.key, delta: $0.value) }.sorted { $0.delta > $1.delta },
            highlights: strongAreas.isEmpty ? [bestArea.map { "\($0.emoji) \($0.name)" } ?? ""] : strongAreas,
            areaProgress: areaProgress
        )
    }
}
