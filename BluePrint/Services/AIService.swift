import Foundation
import SwiftUI

// MARK: - AIService
final class AIService {

    static let shared = AIService()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-5"

    // MARK: - NEW: Generate photo questions
    func generatePhotoQuestions(photoDescription: String, isLiked: Bool) async throws -> [String] {
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

    // MARK: - NEW: Generate life areas from interactions
    func generateLifeAreas(
        interactions: [PhotoInteraction],
        answers: [OnboardingAnswer]
    ) async throws -> [GeneratedLifeArea] {
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
        // Parse a single object (not an array)
        guard let data = response.data(using: .utf8) else { throw AIError.parseError }
        // Try direct object parse
        if let area = try? JSONDecoder().decode(GeneratedLifeArea.self, from: data) {
            return area
        }
        // Fallback: strip to first {...} block
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

    // MARK: - NEW: Generate 20 tasks for an area
    func generateAreaTasks(
        areaName: String,
        vision: String,
        currentReality: String,
        emoji: String
    ) async throws -> [GeneratedTask] {
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

    // MARK: - NEW: Update current reality based on completed tasks
    func updateCurrentReality(
        areaName: String,
        vision: String,
        originalReality: String,
        completedTasks: [String]
    ) async throws -> String {
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

    // MARK: - Generate Weekly Actions (updated for dynamic areas)
    func generateWeeklyActions(for canvas: CanvasContext) async throws -> [GeneratedAction] {
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

    // MARK: - Generate Swap Options (updated for dynamic areas)
    func generateSwapOptions(for task: WeeklyTaskItem, canvas: CanvasContext) async throws -> [GeneratedAction] {
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

    // MARK: - Multi-turn API call (for conversational features)
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
        // Extract JSON array if wrapped in text
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
    let rationale: String?   // nil-safe: AI may not always return this field
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
