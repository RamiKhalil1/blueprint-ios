import SwiftData
import Foundation
import SwiftUI

// MARK: - Canvas (root user model)
@Model
final class Canvas {
    var createdAt: Date
    var updatedAt: Date
    var onboardingComplete: Bool

    @Relationship(deleteRule: .cascade) var photoInteractions: [PhotoInteraction]
    @Relationship(deleteRule: .cascade) var onboardingAnswers: [OnboardingAnswer]
    @Relationship(deleteRule: .cascade) var lifeAreas: [LifeArea]

    init() {
        self.createdAt = .now
        self.updatedAt = .now
        self.onboardingComplete = false
        self.photoInteractions = []
        self.onboardingAnswers = []
        self.lifeAreas = []
    }
}

// MARK: - Photo Interaction (swipe like/dislike)
@Model
final class PhotoInteraction {
    var id: UUID
    var photoName: String           // asset name in app bundle e.g. "onboarding_1"
    var photoDescription: String    // hidden description sent to AI
    var isLiked: Bool
    var isCustom: Bool              // true if user added their own photo
    var userCaption: String?        // caption for custom photos
    var imageData: Data?            // data for custom photos
    var sortIndex: Int
    var createdAt: Date

    init(
        photoName: String,
        photoDescription: String,
        isLiked: Bool,
        isCustom: Bool = false,
        userCaption: String? = nil,
        imageData: Data? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.photoName = photoName
        self.photoDescription = photoDescription
        self.isLiked = isLiked
        self.isCustom = isCustom
        self.userCaption = userCaption
        self.imageData = imageData
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

// MARK: - Onboarding Answer (AI question + user answer)
@Model
final class OnboardingAnswer {
    var id: UUID
    var photoName: String       // which photo triggered this question
    var question: String        // AI generated question
    var answer: String          // user's answer
    var createdAt: Date

    init(photoName: String, question: String, answer: String = "") {
        self.id = UUID()
        self.photoName = photoName
        self.question = question
        self.answer = answer
        self.createdAt = .now
    }
}

// MARK: - Life Area (now AI generated, not fixed)
@Model
final class LifeArea {
    var id: UUID
    var name: String            // AI generated e.g. "Creative Freedom"
    var areaDescription: String // AI generated description
    var emoji: String           // AI generated emoji
    var vision: String          // AI pre-filled, user can edit
    var currentReality: String  // AI pre-filled, updates as tasks done
    var priorityRank: Int
    var progressScore: Double   // 0.0 – 1.0
    var status: String
    var createdAt: Date
    var updatedAt: Date

    // AI cache
    var aiActionTitles: [String]
    var actionsMonthKey: String
    var aiBlockerTypes: [String]
    var aiBlockerTexts: [String]
    var blockersMonthKey: String

    // Tasks
    @Relationship(deleteRule: .cascade) var tasks: [AreaTask]

    var statusEnum: LifeAreaStatus {
        get { LifeAreaStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }

    var displayName: String { name }

    var completedTaskCount: Int { tasks.filter { $0.isDone }.count }
    var totalTaskCount: Int { tasks.count }

    init(
        name: String,
        areaDescription: String,
        emoji: String,
        vision: String = "",
        currentReality: String = "",
        priorityRank: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.areaDescription = areaDescription
        self.emoji = emoji
        self.vision = vision
        self.currentReality = currentReality
        self.priorityRank = priorityRank
        self.progressScore = 0.0
        self.status = LifeAreaStatus.notStarted.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.aiActionTitles = []
        self.actionsMonthKey = ""
        self.aiBlockerTypes = []
        self.aiBlockerTexts = []
        self.blockersMonthKey = ""
        self.tasks = []
    }
}

// MARK: - Area Task (replaces AreaAction — 20 tasks per area)
@Model
final class AreaTask {
    var id: UUID
    var title: String
    var note: String?
    var blockerType: String     // "mindset" | "skill" | "resource" | "habit"
    var isDone: Bool
    var sortIndex: Int
    var completedAt: Date?
    var createdAt: Date

    var blockerTypeEnum: TaskBlockerType {
        get { TaskBlockerType(rawValue: blockerType) ?? .habit }
        set { blockerType = newValue.rawValue }
    }

    init(title: String, note: String? = nil, blockerType: TaskBlockerType = .habit, sortIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.blockerType = blockerType.rawValue
        self.isDone = false
        self.sortIndex = sortIndex
        self.completedAt = nil
        self.createdAt = .now
    }
}

// MARK: - Monthly Record
@Model
final class MonthlyRecord {
    var monthKey: String
    var monthLabel: String
    var savedAmount: Double
    var completedActionTitles: [String]
    var totalActionCount: Int
    var areaRatings: [String: String]
    var canvasDeltas: [String: Int]
    var createdAt: Date

    init(monthKey: String, monthLabel: String) {
        self.monthKey = monthKey
        self.monthLabel = monthLabel
        self.savedAmount = 0
        self.completedActionTitles = []
        self.totalActionCount = 0
        self.areaRatings = [:]
        self.canvasDeltas = [:]
        self.createdAt = .now
    }

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

    var toMonthlyReport: MonthlyReport {
        MonthlyReport(
            month: monthLabel,
            savedAmount: savedAmount,
            completedActions: completedActionTitles.count,
            totalActions: totalActionCount,
            canvasChanges: canvasDeltas.map { (area: $0.key, delta: $0.value) },
            highlights: completedActionTitles
        )
    }
}

// MARK: - Weekly Task Item
@Model
final class WeeklyTaskItem {
    var id: UUID
    var title: String
    var areaName: String        // now uses area name not fixed type
    var note: String?
    var isDone: Bool
    var isSkipped: Bool
    var weekKey: String
    var createdAt: Date

    init(title: String, areaName: String, note: String? = nil) {
        self.id = UUID()
        self.title = title
        self.areaName = areaName
        self.note = note
        self.isDone = false
        self.isSkipped = false
        self.weekKey = WeeklyTaskItem.currentWeekKey()
        self.createdAt = .now
    }

    static func currentWeekKey() -> String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: .now)
        let year = cal.component(.yearForWeekOfYear, from: .now)
        return "\(year)-W\(week)"
    }
}

// MARK: - Enums

enum LifeAreaStatus: String, Codable {
    case onTrack    = "onTrack"
    case drifting   = "drifting"
    case notStarted = "notStarted"

    var displayName: String {
        switch self {
        case .onTrack:    return "Growing"
        case .drifting:   return "Needs attention"
        case .notStarted: return "Not started"
        }
    }
}

enum TaskBlockerType: String, Codable, CaseIterable {
    case mindset  = "mindset"
    case skill    = "skill"
    case resource = "resource"
    case habit    = "habit"

    var label: String {
        switch self {
        case .mindset:  return "Mindset"
        case .skill:    return "Skill"
        case .resource: return "Resource"
        case .habit:    return "Habit"
        }
    }

    var color: Color {
        switch self {
        case .mindset:  return Color(hex: "#EEEDFE")
        case .skill:    return Color(hex: "#E1F5EE")
        case .resource: return Color(hex: "#FAEEDA")
        case .habit:    return Color(hex: "#F1EFE8")
        }
    }

    var textColor: Color {
        switch self {
        case .mindset:  return Color(hex: "#3C3489")
        case .skill:    return Color(hex: "#085041")
        case .resource: return Color(hex: "#633806")
        case .habit:    return Color(hex: "#5F5E5A")
        }
    }
}
