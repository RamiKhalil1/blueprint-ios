import Foundation
import SwiftUI

// MARK: - AIService
final class AIService {

    static let shared = AIService()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-5"

    // Returns true only when a real API key is present
    private var isAPIAvailable: Bool {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return !key.isEmpty
    }

    // MARK: - Generate photo questions
    func generatePhotoQuestions(photoDescription: String, isLiked: Bool) async throws -> [String] {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 800_000_000)
            return MockData.photoQuestions(isLiked: isLiked)
        }

        let sentiment = isLiked ? "liked" : "disliked"
        let prompt = """
        You are Blueprint, a life design assistant learning about a user's personality and desires.

        The user \(sentiment) a photo described as: \(photoDescription)

        Generate exactly 2 short follow-up questions to understand why they \(sentiment) it.
        Questions should reveal their values and desires.
        Keep questions warm and conversational.

        Respond ONLY with a valid JSON array containing exactly 2 strings. Example:
        ["First question here?", "Second question here?"]
        """
        let response = try await call(prompt: prompt, maxTokens: 200)
        print("📥 Raw response: \(response)")
        return try parseStringArray(from: response)
    }

    // MARK: - Generate life areas from interactions
    func generateLifeAreas(
        interactions: [PhotoInteraction],
        answers: [OnboardingAnswer]
    ) async throws -> [GeneratedLifeArea] {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return MockData.lifeAreas
        }

        let likedPhotos = interactions.filter { $0.isLiked }
            .map { "- \($0.photoDescription)" }
            .joined(separator: "\n")

        let dislikedPhotos = interactions.filter { !$0.isLiked }
            .map { "- \($0.photoDescription)" }
            .joined(separator: "\n")

        let qaContext = answers
            .filter { !$0.answer.isEmpty }
            .map { "Q: \($0.question)\nA: \($0.answer)" }
            .joined(separator: "\n\n")

        let prompt = """
        You are Blueprint, a life design assistant. Based on a user's photo preferences and answers, generate exactly 5 personalised life areas for their Blueprint canvas.

        Photos they LIKED:
        \(likedPhotos.isEmpty ? "none" : likedPhotos)

        Photos they DISLIKED:
        \(dislikedPhotos.isEmpty ? "none" : dislikedPhotos)

        Their answers to follow-up questions:
        \(qaContext.isEmpty ? "none" : qaContext)

        Rules:
        - Generate exactly 5 life areas that reflect THIS specific person's desires and values
        - Each area should be unique and meaningful to them personally
        - Area names should be evocative, not generic (e.g. "Creative Freedom" not just "Career")
        - Base areas on patterns you see in what they liked/disliked and their answers
        - Use Australian context where relevant

        Respond ONLY with a JSON array, no markdown:
        [
          {
            "name": "area name (2-3 words)",
            "emoji": "single relevant emoji",
            "description": "one sentence describing what this area means for them personally",
            "vision": "an inspiring 1-2 sentence vision statement for this area based on what they liked",
            "currentReality": "an honest 1-2 sentence current reality statement based on their answers",
            "rationale": "1-2 sentences explaining exactly which photos or answers led to this specific area being chosen"
          }
        ]
        """
        let response = try await call(prompt: prompt, maxTokens: 2500)
        print("📥 Life areas response: \(response.prefix(200))")
        return try parseLifeAreas(from: response)
    }

    // MARK: - Regenerate a single life area
    func regenerateSingleLifeArea(
        interactions: [PhotoInteraction],
        answers: [OnboardingAnswer],
        existingAreaNames: [String]
    ) async throws -> GeneratedLifeArea {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            return MockData.singleArea(avoiding: existingAreaNames)
        }

        let likedPhotos = interactions.filter { $0.isLiked }
            .map { "- \($0.photoDescription)" }
            .joined(separator: "\n")

        let dislikedPhotos = interactions.filter { !$0.isLiked }
            .map { "- \($0.photoDescription)" }
            .joined(separator: "\n")

        let qaContext = answers
            .filter { !$0.answer.isEmpty }
            .map { "Q: \($0.question)\nA: \($0.answer)" }
            .joined(separator: "\n\n")

        let existingList = existingAreaNames.map { "- \($0)" }.joined(separator: "\n")

        let prompt = """
        You are Blueprint, a life design assistant. The user already has these life areas and wants a fresh one to replace one:

        EXISTING AREAS (do NOT duplicate these):
        \(existingList.isEmpty ? "none" : existingList)

        Photos they LIKED:
        \(likedPhotos.isEmpty ? "none" : likedPhotos)

        Photos they DISLIKED:
        \(dislikedPhotos.isEmpty ? "none" : dislikedPhotos)

        Their answers to follow-up questions:
        \(qaContext.isEmpty ? "none" : qaContext)

        Generate exactly ONE new life area that:
        - Is meaningfully different from the existing areas above
        - Still reflects this person's actual desires and values
        - Has an evocative, personal name (e.g. "Wild Freedom" not just "Travel")

        Respond ONLY with a single JSON object, no array, no markdown:
        {
          "name": "area name (2-3 words)",
          "emoji": "single relevant emoji",
          "description": "one sentence describing what this area means for them personally",
          "vision": "an inspiring 1-2 sentence vision statement based on what they liked",
          "currentReality": "an honest 1-2 sentence current reality statement based on their answers",
          "rationale": "1-2 sentences explaining exactly which photos or answers led to this specific area"
        }
        """
        let response = try await call(prompt: prompt, maxTokens: 600)
        print("📥 Single area response: \(response.prefix(300))")
        guard let data = response.data(using: .utf8) else { throw AIError.parseError }
        if let area = try? JSONDecoder().decode(GeneratedLifeArea.self, from: data) {
            return area
        }
        if let start = response.firstIndex(of: "{"),
           let end = response.lastIndex(of: "}") {
            let json = String(response[start...end])
            if let d = json.data(using: .utf8),
               let area = try? JSONDecoder().decode(GeneratedLifeArea.self, from: d) {
                return area
            }
        }
        throw AIError.parseError
    }

    // MARK: - Generate 20 tasks for an area
    func generateAreaTasks(
        areaName: String,
        vision: String,
        currentReality: String,
        emoji: String
    ) async throws -> [GeneratedTask] {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 900_000_000)
            return MockData.tasks(for: areaName, emoji: emoji)
        }

        let prompt = """
        You are Blueprint. Generate exactly 20 tasks that bridge the gap between where this user IS and where they want to BE in one life area.

        Life area: \(emoji) \(areaName)
        Vision (where they want to be): \(vision)
        Current reality (where they are now): \(currentReality)

        Rules:
        - Tasks must specifically address what's BLOCKING the user from reaching their vision
        - Order tasks from easiest/quickest to hardest/longest
        - Mix of mindset shifts, skill building, resource gathering, and habit formation
        - Each task should move them measurably closer to the vision
        - Be specific and actionable, not generic
        - Use Australian context and AUD ($) where relevant
        - Tone: warm, direct, like a smart friend

        Blocker types:
        - "mindset": beliefs or fears holding them back
        - "skill": capabilities they need to develop
        - "resource": tools, money, or connections they need
        - "habit": routines they need to build or break

        Respond ONLY with a JSON array of exactly 20 items, no markdown:
        [
          {
            "title": "specific task title",
            "note": "short helpful tip under 10 words",
            "blockerType": "mindset|skill|resource|habit",
            "sortIndex": 0
          }
        ]
        """
        let response = try await call(prompt: prompt, maxTokens: 3000)
        return try parseTasks(from: response)
    }

    // MARK: - Update current reality based on completed tasks
    func updateCurrentReality(
        areaName: String,
        vision: String,
        originalReality: String,
        completedTasks: [String]
    ) async throws -> String {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 600_000_000)
            return "You've started taking real steps in \(areaName). The gap between where you are and your vision is closing — keep the momentum going."
        }

        let prompt = """
        You are Blueprint. A user has completed some tasks in their "\(areaName)" life area.

        Their vision: \(vision)
        Their original current reality: \(originalReality)

        Tasks they have completed:
        \(completedTasks.map { "- \($0)" }.joined(separator: "\n"))

        Write an updated current reality statement that:
        - Reflects the progress they've made through completing these tasks
        - Is honest but shows movement toward the vision
        - Is 1-2 sentences, warm and encouraging
        - Shows the gap is closing

        Respond ONLY with the updated current reality text, no JSON, no explanation.
        """
        return try await call(prompt: prompt)
    }

    // MARK: - Generate Weekly Actions
    func generateWeeklyActions(for canvas: CanvasContext) async throws -> [GeneratedAction] {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return MockData.weeklyActions(from: canvas)
        }

        let prompt = """
        You are Blueprint, a life design assistant. Based on this user's canvas, generate exactly 6 weekly actions.

        Canvas and user context (ordered by priority):
        \(canvas.formatted)

        Rules:
        - Generate exactly 6 actions total
        - Cover all life areas — give the highest priority or drifting area 2 actions
        - Each action must be small, specific, and completable in under 2 hours
        - Prioritise areas marked as "Needs attention" first
        - Base actions on the gap between their vision and current reality
        - Use AUD ($) for any currency references
        - Tone: warm, direct, non-preachy, like a smart friend

        Respond ONLY with a JSON array with exactly 6 items, no markdown:
        [
          {"title": "action text", "areaName": "exact area name from canvas", "note": "optional short tip"},
          {"title": "action text", "areaName": "exact area name", "note": "..."},
          {"title": "action text", "areaName": "exact area name", "note": "..."},
          {"title": "action text", "areaName": "exact area name", "note": "..."},
          {"title": "action text", "areaName": "exact area name", "note": "..."},
          {"title": "action text", "areaName": "exact area name", "note": "..."}
        ]
        """
        let response = try await call(prompt: prompt)
        return try parseActions(from: response)
    }

    // MARK: - Generate Monthly Story
    func generateMonthlyStory(for report: MonthlyReport) async throws -> StoryNarrative {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            return MockData.monthlyStory
        }

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
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 800_000_000)
            return MockData.swapOptions(for: task)
        }

        let prompt = """
        You are Blueprint. A user wants to swap a weekly task. Generate exactly 3 alternative tasks for the same life area.

        Original task: \(task.title)
        Life area: \(task.areaName)

        Canvas context:
        \(canvas.formatted)

        Rules:
        - All 3 alternatives must be for the \(task.areaName) area
        - Must be different from the original task
        - Small, specific, completable in under 2 hours
        - Tone: warm, direct

        Respond ONLY with a JSON array, no markdown:
        [
          {"title": "action text", "areaName": "\(task.areaName)", "note": "optional short tip"},
          {"title": "action text", "areaName": "\(task.areaName)", "note": "..."},
          {"title": "action text", "areaName": "\(task.areaName)", "note": "..."}
        ]
        """
        let response = try await call(prompt: prompt)
        return try parseActions(from: response)
    }

    // MARK: - Generate Blockers
    func generateBlockers(for area: AreaContext) async throws -> [GeneratedBlocker] {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 700_000_000)
            return MockData.blockers(for: area)
        }

        let prompt = """
        You are Blueprint. Analyse what's blocking this user in one life area.

        Area: \(area.areaType)
        Vision: \(area.vision)
        Current reality: \(area.currentReality)

        Identify 1-2 blockers. Each blocker is one of: mindset, skill, resource, habit.

        Respond ONLY with JSON array, no markdown:
        [
          {"type": "mindset|skill|resource|habit", "text": "specific blocker description under 10 words"}
        ]
        """
        let response = try await call(prompt: prompt)
        return try parseBlockers(from: response)
    }

    // MARK: - Check in with Claude (multi-turn conversational)
    func checkInWithClaude(
        userMessage: String,
        conversationHistory: [(role: String, content: String)],
        canvas: CanvasContext
    ) async throws -> String {
        if !isAPIAvailable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return MockData.checkInResponse(userMessage: userMessage, canvas: canvas)
        }

        let systemPrompt = """
        You are Blueprint, a life design assistant who knows this user's full canvas inside and out.

        Their Blueprint:
        \(canvas.formatted)

        You're having a brief, personal check-in conversation. Rules:
        - Always reference their specific area names, visions, or task progress — never be generic
        - Respond in 2–3 sentences maximum. No lists, no headers, no bullet points.
        - Give exactly one concrete, actionable nudge per message
        - Tone: warm and direct, like a smart friend who genuinely knows their life
        - If they're struggling, validate in one sentence then redirect to one specific action
        - Reference their actual numbers (tasks done, progress %) when it adds weight
        - Use Australian spelling
        """

        var apiMessages: [[String: Any]] = conversationHistory.map {
            ["role": $0.role, "content": $0.content]
        }
        apiMessages.append(["role": "user", "content": userMessage])

        return try await callMultiTurn(system: systemPrompt, messages: apiMessages, maxTokens: 300)
    }

    // MARK: - Core API call
    private func call(prompt: String, maxTokens: Int = 1024) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": "You are Blueprint, a life design assistant. The user is based in Australia. Always use AUD ($) for any currency references. Use Australian spelling and context.",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ API Error \(statusCode): \(responseBody)")
            throw AIError.apiError(statusCode)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Multi-turn API call
    private func callMultiTurn(system: String, messages: [[String: Any]], maxTokens: Int = 400) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ Multi-turn API Error \(statusCode): \(responseBody)")
            throw AIError.apiError(statusCode)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Parsers
    private func clean(_ json: String) -> String {
        json
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseActions(from json: String) throws -> [GeneratedAction] {
        guard let data = clean(json).data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedAction].self, from: data)
    }

    private func parseStory(from json: String) throws -> StoryNarrative {
        guard let data = clean(json).data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode(StoryNarrative.self, from: data)
    }

    private func parseBlockers(from json: String) throws -> [GeneratedBlocker] {
        guard let data = clean(json).data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedBlocker].self, from: data)
    }

    private func parseStringArray(from json: String) throws -> [String] {
        let cleaned = clean(json)
        print("📋 Cleaned response: \(cleaned)")
        guard let data = cleaned.data(using: .utf8) else { throw AIError.parseError }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("❌ Parse error: \(error)")
            throw AIError.parseError
        }
    }

    private func parseLifeAreas(from json: String) throws -> [GeneratedLifeArea] {
        let cleaned = clean(json)
        let extracted: String
        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]") {
            extracted = String(cleaned[start...end])
        } else {
            extracted = cleaned
        }
        print("📋 Extracted life areas JSON: \(extracted.prefix(200))")
        guard let data = extracted.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedLifeArea].self, from: data)
    }

    private func parseTasks(from json: String) throws -> [GeneratedTask] {
        let cleaned = clean(json)
        let extracted: String
        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]") {
            extracted = String(cleaned[start...end])
        } else {
            extracted = cleaned
        }
        guard let data = extracted.data(using: .utf8) else { throw AIError.parseError }
        return try JSONDecoder().decode([GeneratedTask].self, from: data)
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
    let areaName: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case title, areaName, note
    }
}

struct GeneratedLifeArea: Codable {
    let name: String
    let emoji: String
    let description: String
    let vision: String
    let currentReality: String
    let rationale: String?
}

struct GeneratedTask: Codable {
    let title: String
    let note: String?
    let blockerType: String
    let sortIndex: Int
}

struct StoryNarrative: Codable {
    let headline: String
    let narrative: String
    let nextFocus: String
}

struct GeneratedBlocker: Codable, Identifiable {
    var id = UUID()
    let type: String
    let text: String

    var blockerType: BlockerType {
        switch type {
        case "mindset":  return .mindset
        case "skill":    return .skill
        case "resource": return .resource
        case "habit":    return .habit
        default:         return .decision
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text
    }
}

// MARK: - Context types
struct CanvasContext {
    let lifeAreas: [(name: String, emoji: String, vision: String, currentReality: String, status: LifeAreaStatus, progressScore: Double, priorityRank: Int)]
    let reflections: [(question: String, answer: String)]

    var formatted: String {
        var result = lifeAreas.map { area in
            """
            - \(area.emoji) \(area.name) (Priority #\(area.priorityRank)): \(area.status.displayName) (\(Int(area.progressScore * 100))%)
              Vision: \(area.vision.isEmpty ? "not set" : area.vision)
              Current reality: \(area.currentReality.isEmpty ? "not set" : area.currentReality)
            """
        }.joined(separator: "\n")

        if !reflections.isEmpty {
            result += "\n\nUser context:\n"
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
    var areaProgress: [(name: String, emoji: String, completed: Int, total: Int, progress: Double, rating: CheckInRating)] = []

    var completionRate: Double {
        totalActions > 0 ? Double(completedActions) / Double(totalActions) : 0
    }

    var formatted: String {
        """
        Month: \(month)
        Tasks: \(completedActions) of \(totalActions) completed (\(Int(completionRate * 100))%)
        Canvas changes: \(canvasChanges.map { "\($0.area) +\($0.delta)" }.joined(separator: ", "))
        Areas that showed up: \(highlights.joined(separator: ", "))
        Area progress: \(areaProgress.map { "\($0.emoji) \($0.name): \($0.completed)/\($0.total) tasks" }.joined(separator: ", "))
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

// MARK: - Mock Data (used when API key is not configured)

private enum MockData {

    // MARK: Photo questions
    static func photoQuestions(isLiked: Bool) -> [String] {
        if isLiked {
            return [
                "What feeling does this image give you — freedom, calm, or excitement?",
                "If this were part of your everyday life, what would be different about your routine?"
            ]
        } else {
            return [
                "What specifically didn't appeal to you about this?",
                "What would need to change about it for it to feel right for you?"
            ]
        }
    }

    // MARK: Life areas
    static let lifeAreas: [GeneratedLifeArea] = [
        GeneratedLifeArea(
            name: "Wild Exploration",
            emoji: "🌏",
            description: "Experiencing the world beyond your comfort zone through travel and new environments.",
            vision: "You move through the world with curiosity and ease, taking at least two meaningful trips a year and saying yes to experiences that genuinely stretch you.",
            currentReality: "Travel feels like something for later — too expensive, too complicated, always bumped by other priorities.",
            rationale: "You were drawn to the travel and adventure photos, particularly the mountain backpacker and remote cabin images, which suggests a strong desire for freedom and escape from the everyday."
        ),
        GeneratedLifeArea(
            name: "Purposeful Work",
            emoji: "💼",
            description: "Building a career that pays well and feels meaningful, not just a job you tolerate.",
            vision: "Your work energises you more days than it drains you. You're building something that matters and earning enough to have real choices about how you spend your time.",
            currentReality: "Work gets done but rarely feels aligned. You're capable of more than your current role shows, and somewhere inside you already know it.",
            rationale: "Your interest in the remote work café photo and your answers suggest you value autonomy and purpose at work more than a traditional office setting."
        ),
        GeneratedLifeArea(
            name: "Physical Vitality",
            emoji: "🏃",
            description: "Having a body and mind that feel strong, clear, and consistent — not just for aesthetics.",
            vision: "Movement is part of your identity. You train regularly, sleep well, and feel genuinely good in your body on most days of the week.",
            currentReality: "Your routine is inconsistent — good patches followed by weeks of nothing. You know what to do, but follow-through is the real gap.",
            rationale: "Your response to the yoga and fitness photos, combined with your answers about wanting more energy and discipline, points strongly to physical wellbeing as a key priority area."
        ),
        GeneratedLifeArea(
            name: "Creative Flow",
            emoji: "🎨",
            description: "Making things — with your hands, your words, your ideas — as a regular part of life, not a guilty hobby.",
            vision: "You have a dedicated creative practice that produces real work. It might be photography, writing, or something you're still discovering, but it's authentically yours.",
            currentReality: "Creative energy gets absorbed by the day-to-day. There's a project in your head that hasn't started and a skill you keep meaning to develop.",
            rationale: "You were drawn to the artist's studio photo, and your answers revealed a desire to express yourself beyond your current routine. This points to creativity as an unfulfilled core area."
        ),
        GeneratedLifeArea(
            name: "Financial Freedom",
            emoji: "💰",
            description: "Building financial security so money expands your choices instead of quietly limiting them.",
            vision: "You have savings, you understand your money, and you make financial decisions from a place of confidence — not low-grade anxiety.",
            currentReality: "Money comes in and goes out. There's awareness that something should change, but no consistent system in place yet.",
            rationale: "Your reaction to the luxury and career photos, along with answers about wanting more independence, suggests financial autonomy is a driver underneath several of your other desires."
        )
    ]

    // MARK: Tasks per area
    static func tasks(for areaName: String, emoji: String) -> [GeneratedTask] {
        let lower = areaName.lowercased()
        if lower.contains("explor") || lower.contains("travel") || lower.contains("wild") || lower.contains("adventure") {
            return travelTasks
        } else if lower.contains("work") || lower.contains("career") || lower.contains("purpose") || lower.contains("profession") {
            return workTasks
        } else if lower.contains("vital") || lower.contains("physi") || lower.contains("fit") || lower.contains("health") || lower.contains("body") {
            return fitnessTasks
        } else if lower.contains("creat") || lower.contains("art") || lower.contains("flow") || lower.contains("express") {
            return creativeTasks
        } else if lower.contains("financ") || lower.contains("money") || lower.contains("wealth") || lower.contains("freedom") {
            return financeTasks
        } else {
            return genericTasks(for: areaName)
        }
    }

    private static let travelTasks: [GeneratedTask] = [
        GeneratedTask(title: "List 3 places you genuinely want to visit and write one sentence on why each one matters", note: "Be honest, not aspirational", blockerType: "mindset", sortIndex: 0),
        GeneratedTask(title: "Check your annual leave balance today and write it down", note: "Know your starting point", blockerType: "resource", sortIndex: 1),
        GeneratedTask(title: "Open a dedicated travel savings account separate from your spending money", note: "Separation makes it real", blockerType: "habit", sortIndex: 2),
        GeneratedTask(title: "Set up a $50/week automatic transfer to your travel fund on payday", note: "Automate it so you never decide", blockerType: "habit", sortIndex: 3),
        GeneratedTask(title: "Download Google Flights and save price alerts for your top destination", note: "Track for 2 weeks before booking", blockerType: "skill", sortIndex: 4),
        GeneratedTask(title: "Sign up for flight deal alerts from Skyscanner or Hopper", note: "Deals move fast — be ready", blockerType: "resource", sortIndex: 5),
        GeneratedTask(title: "Book a local day trip or overnight stay this month", note: "Build the habit small first", blockerType: "mindset", sortIndex: 6),
        GeneratedTask(title: "Research visa requirements for your number one destination", note: "Remove the uncertainty", blockerType: "skill", sortIndex: 7),
        GeneratedTask(title: "Start 10 minutes of language learning daily on Duolingo", note: "Any language is better than none", blockerType: "habit", sortIndex: 8),
        GeneratedTask(title: "Watch one travel documentary about your target country this week", note: "Make it feel real and close", blockerType: "mindset", sortIndex: 9),
        GeneratedTask(title: "Research travel credit cards and apply for one with points rewards", note: "Qantas or Velocity are solid starts", blockerType: "resource", sortIndex: 10),
        GeneratedTask(title: "Tell one specific person your travel goal and a target date", note: "Accountability changes behaviour", blockerType: "mindset", sortIndex: 11),
        GeneratedTask(title: "Build a reusable packing list so travel friction is lower every time", note: "One list, reused forever", blockerType: "skill", sortIndex: 12),
        GeneratedTask(title: "Research house-sitting or Airbnb alternatives to cut accommodation costs", note: "Trusted Housesitters is worth checking", blockerType: "resource", sortIndex: 13),
        GeneratedTask(title: "Get travel insurance quotes and compare at least 3 providers", note: "Budget $80–150 per trip", blockerType: "resource", sortIndex: 14),
        GeneratedTask(title: "Join one online travel community and share your destination goal", note: "Reddit r/solotravel is active and helpful", blockerType: "mindset", sortIndex: 15),
        GeneratedTask(title: "Block your next 12 months of annual leave in your work calendar before work fills it", note: "Time blocked is time protected", blockerType: "habit", sortIndex: 16),
        GeneratedTask(title: "Build a $500 emergency buffer in your travel fund", note: "Covers most unexpected trip costs", blockerType: "resource", sortIndex: 17),
        GeneratedTask(title: "Say yes to the next invitation that feels uncomfortable in a good way", note: "Confidence is built by doing, not planning", blockerType: "mindset", sortIndex: 18),
        GeneratedTask(title: "Book your next trip — dates, destination, first booking done", note: "A booking beats a plan every time", blockerType: "mindset", sortIndex: 19)
    ]

    private static let workTasks: [GeneratedTask] = [
        GeneratedTask(title: "Write in one sentence exactly what meaningful work looks like for you", note: "Clarity first, then action", blockerType: "mindset", sortIndex: 0),
        GeneratedTask(title: "Rate every task in your current role 1–10 for energy — notice what drains vs. excites", note: "The pattern is the signal", blockerType: "mindset", sortIndex: 1),
        GeneratedTask(title: "Update your LinkedIn profile with your current role and a clear goal statement", note: "Make yourself findable", blockerType: "skill", sortIndex: 2),
        GeneratedTask(title: "Name one specific skill gap between where you are and where you want to be", note: "Specific gaps have specific solutions", blockerType: "skill", sortIndex: 3),
        GeneratedTask(title: "Spend 30 minutes researching roles on SEEK or LinkedIn you'd actually want", note: "Know the benchmark", blockerType: "skill", sortIndex: 4),
        GeneratedTask(title: "Ask one person whose career you admire for a 20-minute conversation", note: "Most people say yes to a specific ask", blockerType: "mindset", sortIndex: 5),
        GeneratedTask(title: "Enrol in one free online course in your target skill area this week", note: "Coursera and edX have thousands of free options", blockerType: "resource", sortIndex: 6),
        GeneratedTask(title: "Block 2 hours per week in your calendar for deliberate skill development", note: "Do it right now before the week fills up", blockerType: "habit", sortIndex: 7),
        GeneratedTask(title: "Save 3 job postings you'd apply for today if you felt ready", note: "The bar you aim for shapes what you build", blockerType: "skill", sortIndex: 8),
        GeneratedTask(title: "Get one honest piece of feedback on your work from someone you trust", note: "External perspective beats internal loops", blockerType: "mindset", sortIndex: 9),
        GeneratedTask(title: "Negotiate one thing at work this week — a deadline, a project, or a meeting", note: "Practice changes your self-image", blockerType: "mindset", sortIndex: 10),
        GeneratedTask(title: "Look up the salary range for your target role on Glassdoor or SEEK", note: "Know your number before any conversation", blockerType: "resource", sortIndex: 11),
        GeneratedTask(title: "Build or update a simple portfolio page with your best work", note: "Notion or a basic website works fine", blockerType: "skill", sortIndex: 12),
        GeneratedTask(title: "Attend one professional event, webinar, or meetup this month", note: "One real connection beats 100 LinkedIn requests", blockerType: "habit", sortIndex: 13),
        GeneratedTask(title: "Write what your ideal work week looks like — times, tasks, and how you feel", note: "Design before you build", blockerType: "mindset", sortIndex: 14),
        GeneratedTask(title: "List your top 3 transferable skills from your current role", note: "You have more leverage than you realise", blockerType: "mindset", sortIndex: 15),
        GeneratedTask(title: "Set one professional goal with a 90-day deadline and write it somewhere visible", note: "Short horizons create real urgency", blockerType: "habit", sortIndex: 16),
        GeneratedTask(title: "Have the work conversation you've been avoiding", note: "Most things get worse when you wait", blockerType: "mindset", sortIndex: 17),
        GeneratedTask(title: "Apply for one role even if you're only 70% qualified", note: "Requirements are a wish list, not a checklist", blockerType: "mindset", sortIndex: 18),
        GeneratedTask(title: "Define what success looks like in 2 years and share it with one person", note: "Saying it out loud changes your decisions", blockerType: "mindset", sortIndex: 19)
    ]

    private static let fitnessTasks: [GeneratedTask] = [
        GeneratedTask(title: "Write your honest current baseline — energy, movement frequency, and sleep quality", note: "No judgment, just truth", blockerType: "mindset", sortIndex: 0),
        GeneratedTask(title: "Set one specific, measurable fitness goal with a 12-week deadline", note: "'Get fit' doesn't work. '5km in 30 mins by August' does.", blockerType: "mindset", sortIndex: 1),
        GeneratedTask(title: "Schedule 3 workouts per week in your calendar for the next 4 weeks right now", note: "Scheduled beats spontaneous every time", blockerType: "habit", sortIndex: 2),
        GeneratedTask(title: "Go for a 20-minute walk today — no gear, no prep, just go", note: "Start before you feel ready", blockerType: "mindset", sortIndex: 3),
        GeneratedTask(title: "Track your sleep for 7 consecutive days using your phone or a free app", note: "Sleep is where fitness actually happens", blockerType: "habit", sortIndex: 4),
        GeneratedTask(title: "Drink 2L of water daily for one full week with phone reminders to help", note: "Set reminders at 9am, 12pm, and 3pm", blockerType: "habit", sortIndex: 5),
        GeneratedTask(title: "Pick one training style and commit to it for 4 consecutive weeks", note: "Consistency beats variety at this stage", blockerType: "mindset", sortIndex: 6),
        GeneratedTask(title: "Find one training partner or accountability buddy", note: "You cancel on yourself. You rarely cancel on someone else.", blockerType: "resource", sortIndex: 7),
        GeneratedTask(title: "Prep 3 meals in advance on Sunday to reduce weekday food decisions", note: "Nutrition decisions made when hungry are always worse", blockerType: "habit", sortIndex: 8),
        GeneratedTask(title: "Learn to do 10 proper push-ups with correct form", note: "Search 'perfect push-up form' on YouTube and practise daily", blockerType: "skill", sortIndex: 9),
        GeneratedTask(title: "Take a progress photo and save it privately — you'll be glad you have it in 12 weeks", note: "The visual record matters", blockerType: "habit", sortIndex: 10),
        GeneratedTask(title: "Reduce your biggest dietary blocker for two weeks and notice the impact", note: "Alcohol, sugar, and takeaway are usually the culprits", blockerType: "habit", sortIndex: 11),
        GeneratedTask(title: "Book one fitness class you've never tried before this week", note: "New stimulus creates new motivation", blockerType: "mindset", sortIndex: 12),
        GeneratedTask(title: "Set a consistent bedtime and protect it for 2 weeks straight", note: "10:30pm changes more than any supplement", blockerType: "habit", sortIndex: 13),
        GeneratedTask(title: "Stretch for 10 minutes every morning for 14 days in a row", note: "Flexibility is the most underrated training investment", blockerType: "habit", sortIndex: 14),
        GeneratedTask(title: "Run or walk 5km without stopping at least once this month", note: "Pick a flat route and just start", blockerType: "mindset", sortIndex: 15),
        GeneratedTask(title: "Book a health check or blood test if you haven't had one in the past 12 months", note: "Know your numbers", blockerType: "resource", sortIndex: 16),
        GeneratedTask(title: "Delete or mute your biggest time-wasting app for 30 days", note: "That time goes somewhere — make it movement", blockerType: "habit", sortIndex: 17),
        GeneratedTask(title: "Train on a day when you least feel like it — just once", note: "That one session changes your self-image permanently", blockerType: "mindset", sortIndex: 18),
        GeneratedTask(title: "Sign up for a fitness event 3 months away — run, cycle, or swim", note: "A race entry changes your training overnight", blockerType: "mindset", sortIndex: 19)
    ]

    private static let creativeTasks: [GeneratedTask] = [
        GeneratedTask(title: "Name the one creative medium you most want to explore right now", note: "Pick one. Just one.", blockerType: "mindset", sortIndex: 0),
        GeneratedTask(title: "Spend 30 minutes on a creative practice today — no output required", note: "Permission to be bad is the starting condition", blockerType: "mindset", sortIndex: 1),
        GeneratedTask(title: "Block a weekly creative session in your calendar at the same time every week", note: "Treat it like a meeting you cannot cancel", blockerType: "habit", sortIndex: 2),
        GeneratedTask(title: "Study 3 creators you admire in your chosen medium and note what you respond to", note: "See what's possible before judging your own output", blockerType: "mindset", sortIndex: 3),
        GeneratedTask(title: "Gather or buy the basic tools you need for your creative practice", note: "Barrier removal is half the work", blockerType: "resource", sortIndex: 4),
        GeneratedTask(title: "Create one small finished thing and show it to one person this week", note: "Shipping is a skill — practise it early", blockerType: "mindset", sortIndex: 5),
        GeneratedTask(title: "Keep a daily ideas list — 3 ideas minimum, no editing or judging", note: "Quantity trains the creative muscle", blockerType: "habit", sortIndex: 6),
        GeneratedTask(title: "Find one community of people working in your creative field and join it", note: "Isolation kills creative momentum", blockerType: "resource", sortIndex: 7),
        GeneratedTask(title: "Take a beginner class in your medium — online or in person", note: "Structure accelerates learning faster than solo exploration", blockerType: "skill", sortIndex: 8),
        GeneratedTask(title: "Dedicate one weekend morning per month to unstructured creative time with no goals", note: "Play is part of the process", blockerType: "habit", sortIndex: 9),
        GeneratedTask(title: "Read one book on technique in your chosen creative medium", note: "Understanding structure makes you freer, not more rigid", blockerType: "skill", sortIndex: 10),
        GeneratedTask(title: "Build a swipe file — save everything that inspires you in one dedicated folder", note: "Notion, Pinterest, or a simple folder works", blockerType: "habit", sortIndex: 11),
        GeneratedTask(title: "Name the one fear you have about sharing creative work publicly", note: "Named fears are smaller than unnamed ones", blockerType: "mindset", sortIndex: 12),
        GeneratedTask(title: "Collaborate on one small creative project with another person this month", note: "Collaboration changes how you see your own work", blockerType: "resource", sortIndex: 13),
        GeneratedTask(title: "Start a 30-day creative challenge with a daily minimum of 5 minutes", note: "Streaks build identity faster than goals", blockerType: "habit", sortIndex: 14),
        GeneratedTask(title: "Submit one piece of work somewhere — a group, a platform, or a competition", note: "External feedback accelerates growth faster than internal critique", blockerType: "mindset", sortIndex: 15),
        GeneratedTask(title: "Create a dedicated physical space for your creative work", note: "Context cues reduce the activation energy to start", blockerType: "resource", sortIndex: 16),
        GeneratedTask(title: "Spend one hour recreating something you admire as closely as you can", note: "Copying to learn is how every master started", blockerType: "skill", sortIndex: 17),
        GeneratedTask(title: "Block your biggest distraction during your creative hours every session", note: "Notifications off. Door closed. Start.", blockerType: "habit", sortIndex: 18),
        GeneratedTask(title: "Start the project you've been putting off — just the first 10 minutes", note: "Starting is the hardest part. Everything else follows.", blockerType: "mindset", sortIndex: 19)
    ]

    private static let financeTasks: [GeneratedTask] = [
        GeneratedTask(title: "Calculate your exact monthly take-home income after tax", note: "Know your real number, not your salary", blockerType: "skill", sortIndex: 0),
        GeneratedTask(title: "List every subscription you're paying and cancel at least one today", note: "Average Australian wastes $600/year on unused subscriptions", blockerType: "habit", sortIndex: 1),
        GeneratedTask(title: "Open a high-interest savings account separate from your everyday transaction account", note: "UBank, ING, and Macquarie have competitive rates", blockerType: "resource", sortIndex: 2),
        GeneratedTask(title: "Set an automatic transfer on payday — even $50 is a start", note: "Pay yourself first. Everything else is an expense.", blockerType: "habit", sortIndex: 3),
        GeneratedTask(title: "Track every dollar you spend for 2 weeks using an app or spreadsheet", note: "Awareness is the first and most powerful intervention", blockerType: "skill", sortIndex: 4),
        GeneratedTask(title: "Set a specific savings goal with a dollar amount and a clear date", note: "'Save more' doesn't work. '$5,000 by December' does.", blockerType: "mindset", sortIndex: 5),
        GeneratedTask(title: "Build a simple monthly budget with 3 categories: needs, wants, and savings", note: "Start rough — you can refine it next month", blockerType: "skill", sortIndex: 6),
        GeneratedTask(title: "Check your superannuation balance and confirm it's invested in the right option for your age", note: "Most people are on the default, which is often not optimal", blockerType: "resource", sortIndex: 7),
        GeneratedTask(title: "Read one personal finance book this month — The Barefoot Investor is a strong start for Australians", note: "Australian context makes it immediately actionable", blockerType: "skill", sortIndex: 8),
        GeneratedTask(title: "Call one existing provider — internet, phone, or insurance — and negotiate a better rate", note: "Saying 'I'm considering switching' works about 60% of the time", blockerType: "mindset", sortIndex: 9),
        GeneratedTask(title: "Identify your single biggest unnecessary spending category without judging yourself", note: "Awareness before behaviour change", blockerType: "mindset", sortIndex: 10),
        GeneratedTask(title: "Check your tax return options — are you claiming every deduction you're entitled to?", note: "ATO's myTax is free and takes about 30 minutes", blockerType: "resource", sortIndex: 11),
        GeneratedTask(title: "Set a 90-day no-unnecessary-spending challenge in one specific category", note: "Dining out, clothes, or online shopping — pick the one that stings most", blockerType: "habit", sortIndex: 12),
        GeneratedTask(title: "Spend one hour learning the basics of index funds and ETFs", note: "Passive investing beats most active strategies over 10 years", blockerType: "skill", sortIndex: 13),
        GeneratedTask(title: "Calculate how many months you could live on your current savings if your income stopped", note: "Emergency fund maths changes your relationship with money", blockerType: "mindset", sortIndex: 14),
        GeneratedTask(title: "Set a specific income target for 12 months from now and write down the path to get there", note: "Raise, side income, or new role — pick a path", blockerType: "mindset", sortIndex: 15),
        GeneratedTask(title: "Build a 1-month emergency fund before you invest anything else", note: "Security first. Growth second.", blockerType: "habit", sortIndex: 16),
        GeneratedTask(title: "Open a brokerage account and make one small investment this month to start the habit", note: "Stake and Superhero are good entry points in Australia", blockerType: "resource", sortIndex: 17),
        GeneratedTask(title: "Share your financial goal with one person who will hold you to it", note: "Private goals stay private. Shared goals get pressure-tested.", blockerType: "mindset", sortIndex: 18),
        GeneratedTask(title: "Calculate your net worth today — total assets minus total liabilities", note: "Track it monthly. Direction matters more than the number.", blockerType: "skill", sortIndex: 19)
    ]

    private static func genericTasks(for areaName: String) -> [GeneratedTask] {
        [
            GeneratedTask(title: "Write in one sentence exactly what success looks like in \(areaName)", note: "Clarity before action", blockerType: "mindset", sortIndex: 0),
            GeneratedTask(title: "Identify the single biggest thing blocking you in this area right now", note: "Name it specifically", blockerType: "mindset", sortIndex: 1),
            GeneratedTask(title: "Find one person who has what you want in \(areaName) and study how they got there", note: "Find a model, not an idol", blockerType: "mindset", sortIndex: 2),
            GeneratedTask(title: "Block 1 hour per week in your calendar specifically for this area", note: "Scheduled time becomes real progress", blockerType: "habit", sortIndex: 3),
            GeneratedTask(title: "Read one book, article, or resource about \(areaName) this month", note: "Knowledge reduces friction", blockerType: "skill", sortIndex: 4),
            GeneratedTask(title: "Take one concrete first step in the next 48 hours", note: "Action beats perfect planning", blockerType: "mindset", sortIndex: 5),
            GeneratedTask(title: "Find one community, group, or mentor in this area", note: "You don't have to figure it out alone", blockerType: "resource", sortIndex: 6),
            GeneratedTask(title: "Define what 'good enough' looks like versus 'excellent' in \(areaName)", note: "Perfection is often the enemy of progress", blockerType: "mindset", sortIndex: 7),
            GeneratedTask(title: "Track your effort in this area every day for 30 days", note: "What gets measured gets managed", blockerType: "habit", sortIndex: 8),
            GeneratedTask(title: "Tell one person your goal in \(areaName) and a specific timeline", note: "Accountability changes outcomes", blockerType: "mindset", sortIndex: 9),
            GeneratedTask(title: "Remove one thing from your life that actively works against this area", note: "Subtraction is as powerful as addition", blockerType: "habit", sortIndex: 10),
            GeneratedTask(title: "Identify one skill to develop in \(areaName) and start learning it this week", note: "One hour a week compounds fast over 6 months", blockerType: "skill", sortIndex: 11),
            GeneratedTask(title: "Set a 90-day milestone that represents meaningful progress in this area", note: "Short enough to feel urgent, long enough to matter", blockerType: "mindset", sortIndex: 12),
            GeneratedTask(title: "Have one honest conversation about your biggest challenge in this area", note: "Saying it out loud reduces its power", blockerType: "mindset", sortIndex: 13),
            GeneratedTask(title: "Spend 15 minutes imagining what your life looks like when this area is thriving", note: "Emotional connection drives follow-through", blockerType: "mindset", sortIndex: 14),
            GeneratedTask(title: "Build the daily habit that would move this area most consistently", note: "Systems outlast motivation", blockerType: "habit", sortIndex: 15),
            GeneratedTask(title: "Invest in one resource that will meaningfully accelerate your progress here", note: "Paying for speed is often worth it", blockerType: "resource", sortIndex: 16),
            GeneratedTask(title: "Do a 5-minute weekly review of your progress in \(areaName) every Sunday", note: "Weekly reviews build compounding momentum", blockerType: "habit", sortIndex: 17),
            GeneratedTask(title: "Do the thing in this area you've been avoiding the most", note: "The avoided thing is almost always the most important", blockerType: "mindset", sortIndex: 18),
            GeneratedTask(title: "Celebrate one win in \(areaName) this month, no matter how small", note: "Recognising progress fuels more progress", blockerType: "mindset", sortIndex: 19)
        ]
    }

    // MARK: Single area regeneration
    static func singleArea(avoiding existingNames: [String]) -> GeneratedLifeArea {
        let candidates: [GeneratedLifeArea] = [
            GeneratedLifeArea(
                name: "Social Connection",
                emoji: "🤝",
                description: "Building relationships that energise you and genuinely match who you're becoming.",
                vision: "You have a small, honest network of people who know the real you — people you can call at any hour and laugh with at any time.",
                currentReality: "Some friendships feel more like maintenance than joy right now. There are people to add and some to let drift.",
                rationale: "Your answers suggest a desire for connection that feels more intentional than your current social landscape."
            ),
            GeneratedLifeArea(
                name: "Mindful Living",
                emoji: "🧘",
                description: "Developing a calm, present relationship with your own mind and daily pace.",
                vision: "You move through your days with intention, not reaction. You have practices that help you reset and think clearly.",
                currentReality: "Life moves fast and your mind often races with it. There's rarely a moment that feels truly yours.",
                rationale: "Your response to the calm and nature images suggests a deep need for stillness that your current routine isn't meeting."
            ),
            GeneratedLifeArea(
                name: "Home & Space",
                emoji: "🏠",
                description: "Creating a living environment that reflects who you are and supports how you want to live.",
                vision: "Your home feels intentional and calm. It's a place that recharges you rather than just storing your things.",
                currentReality: "Your space is functional but doesn't quite feel like yours yet. It's a background, not a sanctuary.",
                rationale: "Your attraction to the minimalist apartment and cabin images suggests environment and space matter more to you than you've acted on."
            )
        ]
        return candidates.first { !existingNames.contains($0.name) } ?? candidates[0]
    }

    // MARK: Weekly actions
    static func weeklyActions(from canvas: CanvasContext) -> [GeneratedAction] {
        let areas = canvas.lifeAreas
        let names = areas.map { $0.name }
        guard !names.isEmpty else {
            return [GeneratedAction(title: "Spend 30 minutes on your top life area today", areaName: "Growth", note: "Progress compounds when it's consistent")]
        }
        return [
            GeneratedAction(title: "Spend 30 minutes on your highest-priority area today", areaName: names[0], note: "Consistent effort compounds over time"),
            GeneratedAction(title: "Write down one thing you're proud of in this area this week", areaName: names[0], note: "Reflection builds momentum"),
            GeneratedAction(title: "Do one small action you've been putting off in this area", areaName: names.count > 1 ? names[1] : names[0], note: "The avoided task is usually the most valuable"),
            GeneratedAction(title: "Reach out to one person who could help you move forward here", areaName: names.count > 2 ? names[2] : names[0], note: "Connection accelerates progress"),
            GeneratedAction(title: "Block 2 hours this weekend for something in this area you genuinely enjoy", areaName: names.count > 3 ? names[3] : names[0], note: "Enjoyment sustains long-term effort"),
            GeneratedAction(title: "Review your Blueprint and update anything that feels out of date", areaName: names.count > 4 ? names[4] : names[0], note: "Your canvas should evolve as you do")
        ]
    }

    // MARK: Monthly story
    static let monthlyStory = StoryNarrative(
        headline: "A month of real movement",
        narrative: "This month you moved the needle on what matters most to you. Even when progress felt invisible in the moment, the consistency was building something real. One area still needs more of your attention next month — and you already know which one.",
        nextFocus: "your most important area"
    )

    // MARK: Swap options
    static func swapOptions(for task: WeeklyTaskItem) -> [GeneratedAction] {
        [
            GeneratedAction(title: "Spend 20 minutes researching one specific aspect of \(task.areaName)", areaName: task.areaName, note: "Knowledge is a form of forward movement"),
            GeneratedAction(title: "Write 3 sentences about what progress in \(task.areaName) would feel like", areaName: task.areaName, note: "Clarity is the first real step"),
            GeneratedAction(title: "Take one small, concrete action toward your \(task.areaName) vision today", areaName: task.areaName, note: "Small is still movement")
        ]
    }

    // MARK: Blockers
    static func blockers(for area: AreaContext) -> [GeneratedBlocker] {
        [
            GeneratedBlocker(type: "mindset", text: "Believing change needs to be dramatic to matter"),
            GeneratedBlocker(type: "habit", text: "No consistent routine dedicated to this area yet")
        ]
    }

    // MARK: Check-in response
    static func checkInResponse(userMessage: String, canvas: CanvasContext) -> String {
        let areaName = canvas.lifeAreas.first?.name ?? "your Blueprint"
        let responses = [
            "That's worth sitting with. The fact you're noticing it means you're already closer to changing it than you think. What's one thing you could do differently in \(areaName) in the next 24 hours?",
            "The gap between where you are and where you want to be in \(areaName) is clear — that's actually useful information. Pick the smallest possible step and do it today.",
            "Progress in this area rarely feels dramatic in the moment. What would 'good enough for this week' actually look like for you?",
            "The pattern you're describing is common, but it's not fixed. What's one belief you hold about yourself in \(areaName) that you could challenge this week?",
            "You know more than you're giving yourself credit for. What would you tell a close friend who came to you with exactly this situation?"
        ]
        return responses[abs(userMessage.hashValue) % responses.count]
    }
}
