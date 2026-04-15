import SwiftData
import Foundation

@Model
final class WeeklyTaskItem {
    var id: UUID
    var title: String
    var areaTypeRaw: String
    var note: String?
    var isDone: Bool
    var isSkipped: Bool
    var weekKey: String
    var createdAt: Date

    var areaType: LifeAreaType {
        LifeAreaType(rawValue: areaTypeRaw) ?? .experiences
    }

    init(title: String, areaType: LifeAreaType, note: String? = nil) {
        self.id = UUID()
        self.title = title
        self.areaTypeRaw = areaType.rawValue
        self.note = note
        self.isDone = false
        self.isSkipped = false
        self.weekKey = WeeklyTaskItem.currentWeekKey()
        self.createdAt = .now
    }

//    static func currentWeekKey() -> String {
//        let cal = Calendar.current
//        let week = cal.component(.weekOfYear, from: .now)
//        let year = cal.component(.yearForWeekOfYear, from: .now)
//        return "\(year)-W\(week)"
//    }
    
    static func currentWeekKey() -> String {
        return "2026-W100"
    }
}

