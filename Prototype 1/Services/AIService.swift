import Foundation

// MARK: - AIService

final class AIService {

    static let shared = AIService()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-5"

    // MARK: - Generate Weekly Actions
    func generateWeeklyActions(for canvas: CanvasContext) async throws -> [GeneratedAction] {
        let prompt = """
            You are Blueprint, a life design assistant. Based on this user's canvas, generate exactly 6 weekly actions.

            Canvas and user context (ordered by priority):
            \(canvas.formatted)

            Rules:
            - Generate exactly 6 actions total
            - Use the user's reflections to make actions deeply personal to their mindset and goals
            - Each action must be small, specific, and completable in under 2 hours
            - Prioritise areas marked as "drifting" first
            - Prioritise higher priority areas (Priority #1 is most important)
            - Base actions on the gap between their vision and current reality
            - If current reality is not set, use the vision to guide the action
            - Use AUD ($) for any currency references
            - Tone: warm, direct, non-preachy, like a smart friend

            Respond ONLY with a JSON array with exactly 6 items, no markdown, no explanation:
            [
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "optional short tip"},
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "..."},
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "..."},
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "..."},
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "..."},
                {"title": "action text", "areaType": "experiences|place|workTime|identity|finance", "note": "..."}
            ]
            """

        let response = try await call(prompt: prompt)
        return try parseActions(from: response)
    }

    // MARK: - Generate Monthly Story
    func generateMonthlyStory(for report: MonthlyReport) async throws -> StoryNarrative {
        let prompt = """
        You are Blueprint, a life design assistant. Generate a monthly story narrative for this user.

        Monthly data:
        \(report.formatted)

        Generate a warm, honest, 2-3 sentence narrative that:
        - Celebrates real progress without being sycophantic
        - Names one specific thing they did
        - Points to one area to focus on next month
        - Feels like a thoughtful friend, not a productivity app

        Respond ONLY with JSON, no markdown:
        {
          "headline": "short punchy headline under 8 words",
          "narrative": "2-3 sentence story",
          "nextFocus": "one life area to focus on next month (area name only)"
        }
        """

        let response = try await call(prompt: prompt)
        return try parseStory(from: response)
    }
    
    // MARK: - Generate Swap Options
    func generateSwapOptions(for task: WeeklyTaskItem, canvas: CanvasContext) async throws -> [GeneratedAction] {
        let prompt = """
        You are Blueprint. A user wants to swap a weekly task. Generate exactly 3 alternative tasks for the same life area.

        Original task: \(task.title)
        Life area: \(task.areaType.displayName)

        Canvas context:
        \(canvas.formatted)

        Rules:
        - All 3 alternatives must be for the \(task.areaType.displayName) area
        - Must be different from the original task
        - Small, specific, completable in under 2 hours
        - Personalised to their vision for that area
        - Tone: warm, direct

        Respond ONLY with a JSON array, no markdown:
        [
          {"title": "action text", "areaType": "\(task.areaType.rawValue)", "note": "optional short tip"},
          {"title": "action text", "areaType": "\(task.areaType.rawValue)", "note": "..."},
          {"title": "action text", "areaType": "\(task.areaType.rawValue)", "note": "..."}
        ]
        """

        let response = try await call(prompt: prompt)
        return try parseActions(from: response)
    }
    
    // MARK: - Generate Area Actions
    func generateAreaActions(for area: AreaContext) async throws -> [GeneratedAreaAction] {
        let prompt = """
        You are Blueprint, a life design assistant. Generate exactly 5-6 personalised actions for this user in one life area.

        Area: \(area.areaType)
        Vision: \(area.vision.isEmpty ? "not set" : area.vision)
        Current reality: \(area.currentReality.isEmpty ? "not set" : area.currentReality)

        Rules:
        - Actions must be specific to their vision and current reality
        - Mix of small (30 min), medium (2-3 hours), and ongoing actions
        - Practical and achievable, not generic
        - Tone: warm, direct, like a smart friend giving advice

        Respond ONLY with a JSON array, no markdown, no explanation:
        [
          {"title": "action text", "note": "optional short tip under 10 words"},
          {"title": "action text", "note": "..."}
        ]
        """

        let response = try await call(prompt: prompt)
        return try parseAreaActions(from: response)
    }

    // MARK: - Generate Blockers
    func generateBlockers(for area: AreaContext) async throws -> [GeneratedBlocker] {
        let prompt = """
        You are Blueprint. Analyse what's blocking this user in one life area.

        Area: \(area.areaType)
        Vision: \(area.vision)
        Current reality: \(area.currentReality)

        Identify 1-2 blockers. Each blocker is one of: money, time, decision.

        Respond ONLY with JSON array, no markdown:
        [
          {"type": "money|time|decision", "text": "specific blocker description under 10 words"}
        ]
        """

        let response = try await call(prompt: prompt)
        return try parseBlockers(from: response)
    }

    // MARK: - Core API call
    private func call(prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // API key — set via Config.xcconfig or environment
        // NEVER hardcode your API key here
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You are Blueprint, a life design assistant. The user is based in Australia. Always use AUD ($) for any currency references. Use Australian spelling and context.",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Parsers
    private func parseActions(from json: String) throws -> [GeneratedAction] {
        guard let data = json.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedAction].self, from: data)
    }

    private func parseStory(from json: String) throws -> StoryNarrative {
        guard let data = json.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode(StoryNarrative.self, from: data)
    }
    
    private func parseAreaActions(from json: String) throws -> [GeneratedAreaAction] {
        let clean = json
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let data = clean.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedAreaAction].self, from: data)
    }

    private func parseBlockers(from json: String) throws -> [GeneratedBlocker] {
        let clean = json
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedBlocker].self, from: data)
    }
}

// MARK: - Request / Response types
private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}

// MARK: - Output types
struct GeneratedAction: Codable, Identifiable {
    var id = UUID()
    let title: String
    let areaType: String
    let note: String?

    var lifeAreaType: LifeAreaType {
        LifeAreaType(rawValue: areaType) ?? .experiences
    }

    enum CodingKeys: String, CodingKey {
        case title, areaType, note
    }
}

struct StoryNarrative: Codable {
    let headline: String
    let narrative: String
    let nextFocus: String
}

struct GeneratedAreaAction: Codable, Identifiable {
    var id = UUID()
    let title: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case title, note
    }
}

struct GeneratedBlocker: Codable, Identifiable {
    var id = UUID()
    let type: String
    let text: String

    var blockerType: BlockerType {
        switch type {
        case "money":    return .money
        case "time":     return .time
        case "decision": return .decision
        default:         return .decision
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text
    }
}

// MARK: - Context types (feed into prompts)
struct CanvasContext {
    let lifeAreas: [(type: LifeAreaType, vision: String, currentReality: String, status: LifeAreaStatus, progressScore: Double, priorityRank: Int)]
    let reflections: [(question: String, answer: String)]

    var formatted: String {
        var result = lifeAreas.map { area in
            """
            - \(area.type.displayName) (Priority #\(area.priorityRank)): \(area.status.displayName) (\(Int(area.progressScore * 100))%)
              Vision: \(area.vision.isEmpty ? "not set" : area.vision)
              Current reality: \(area.currentReality.isEmpty ? "not set" : area.currentReality)
            """
        }.joined(separator: "\n")

        if !reflections.isEmpty {
            result += "\n\nUser reflections:\n"
            result += reflections.map { "- \($0.question): \($0.answer)" }.joined(separator: "\n")
        }

        return result
    }
}

struct AreaContext {
    let areaType: String
    let vision: String
    let currentReality: String
}

struct MonthlyReport {
    let month: String
    let savedAmount: Double
    let completedActions: Int
    let totalActions: Int
    let canvasChanges: [(area: String, delta: Int)]
    let highlights: [String]

    var formatted: String {
        """
        Month: \(month)
        Saved: $\(Int(savedAmount))
        Actions: \(completedActions) of \(totalActions) completed
        Canvas changes: \(canvasChanges.map { "\($0.area) +\($0.delta)" }.joined(separator: ", "))
        Highlights: \(highlights.joined(separator: ", "))
        """
    }
}

// MARK: - Errors
enum AIError: LocalizedError {
    case apiError(Int)
    case parseError
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .apiError(let code): return "API error \(code)"
        case .parseError:         return "Could not parse AI response"
        case .missingAPIKey:      return "API key not configured"
        }
    }
}
