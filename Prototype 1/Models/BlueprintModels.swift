import SwiftData
import Foundation

// MARK: - Canvas (root user model)
@Model
final class Canvas {
    var createdAt: Date
    var updatedAt: Date
    var onboardingComplete: Bool

    @Relationship(deleteRule: .cascade) var visionItems: [VisionItem]
    @Relationship(deleteRule: .cascade) var lifeAreas: [LifeArea]
    @Relationship(deleteRule: .cascade) var reflections: [Reflection]

    init() {
        self.createdAt = .now
        self.updatedAt = .now
        self.onboardingComplete = false
        self.visionItems = []
        self.lifeAreas = LifeAreaType.allCases.map { LifeArea(type: $0) }
        self.reflections = []
    }
}

// MARK: - Vision Board Item
@Model
final class VisionItem {
    var id: UUID
    var caption: String
    var imageData: Data?
    var sortIndex: Int
    var createdAt: Date

    init(caption: String = "", imageData: Data? = nil, sortIndex: Int = 0) {
        self.id = UUID()
        self.caption = caption
        self.imageData = imageData
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

// MARK: - Life Area
@Model
final class LifeArea {
    var id: UUID
    var typeRaw: String
    var vision: String
    var currentReality: String
    var priorityRank: Int        // 1 = highest priority
    var progressScore: Double    // 0.0 – 1.0
    var status: String           // "onTrack" | "drifting"
    var createdAt: Date
    var updatedAt: Date
    var completedActionTitles: [String]
    var aiActionTitles: [String]
    var actionsMonthKey: String
    var aiBlockerTypes: [String]
    var aiBlockerTexts: [String]
    var blockersMonthKey: String

    var type: LifeAreaType {
        get { LifeAreaType(rawValue: typeRaw) ?? .experiences }
        set { typeRaw = newValue.rawValue }
    }

    var statusEnum: LifeAreaStatus {
        get { LifeAreaStatus(rawValue: status) ?? .onTrack }
        set { status = newValue.rawValue }
    }

    init(type: LifeAreaType) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.vision = ""
        self.currentReality = ""
        self.priorityRank = type.defaultRank
        self.progressScore = 0.0
        self.status = LifeAreaStatus.onTrack.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.completedActionTitles = []
        self.aiActionTitles = []
        self.actionsMonthKey = ""
        self.aiBlockerTypes = []
        self.aiBlockerTexts = []
        self.blockersMonthKey = ""
    }
}

// MARK: - Reflection Answer
@Model
final class Reflection {
    var id: UUID
    var questionIndex: Int
    var questionText: String
    var answer: String
    var createdAt: Date

    init(questionIndex: Int, questionText: String, answer: String = "") {
        self.id = UUID()
        self.questionIndex = questionIndex
        self.questionText = questionText
        self.answer = answer
        self.createdAt = .now
    }
}

// MARK: - Enums

enum LifeAreaType: String, CaseIterable, Codable {
    case experiences = "experiences"
    case place       = "place"
    case workTime    = "workTime"
    case identity    = "identity"
    case finance     = "finance"

    var displayName: String {
        switch self {
        case .experiences: return "Experiences"
        case .place:       return "Place"
        case .workTime:    return "Work & time"
        case .identity:    return "Identity"
        case .finance:     return "Finance"
        }
    }

    var defaultRank: Int {
        switch self {
        case .place:       return 1
        case .experiences: return 2
        case .workTime:    return 3
        case .identity:    return 4
        case .finance:     return 5
        }
    }
    
    var accentHex: String {
        switch self {
        case .experiences: return "#BA7517"
        case .place:       return "#1D9E75"
        case .workTime:    return "#7F77DD"
        case .identity:    return "#BA7517"
        case .finance:     return "#1D9E75"
        }
    }
}

enum LifeAreaStatus: String, Codable {
    case onTrack  = "onTrack"
    case drifting = "drifting"

    var displayName: String {
        switch self {
        case .onTrack:  return "On track"
        case .drifting: return "Drifting"
        }
    }
}
