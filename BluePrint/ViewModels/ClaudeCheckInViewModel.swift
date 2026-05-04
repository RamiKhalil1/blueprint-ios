import SwiftUI
import SwiftData
import Combine

// MARK: - Message model

struct CheckInMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    /// Welcome messages are shown in the UI but excluded from the API history.
    var isWelcome: Bool = false

    enum MessageRole {
        case user, assistant
        var apiString: String { self == .user ? "user" : "assistant" }
    }
}

// MARK: - ViewModel

final class ClaudeCheckInViewModel: ObservableObject {

    @Published var messages:   [CheckInMessage] = []
    @Published var inputText:  String = ""
    @Published var isLoading:  Bool   = false
    @Published var errorMessage: String? = nil
    @Published var lifeAreas:  [LifeArea] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadLifeAreas()
        addWelcomeMessage()
    }

    // MARK: - Setup

    private func loadLifeAreas() {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else { return }
        lifeAreas = canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }
    }

    private func addWelcomeMessage() {
        let areas = lifeAreas.prefix(3).map { $0.name }.joined(separator: ", ")
        let areaHint = areas.isEmpty ? "your canvas" : areas
        messages.append(CheckInMessage(
            role: .assistant,
            content: "Hey! What's on your mind this week? Tell me what you're working through — I can give you a specific nudge based on your Blueprint (\(areaHint)…).",
            timestamp: .now,
            isWelcome: true
        ))
    }

    // MARK: - Computed

    // True when the user can send a new message.
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
            && !isAtLimit
    }

    // Limit to 6 user exchanges per session.
    var isAtLimit: Bool {
        messages.filter { $0.role == .user }.count >= 6
    }

    // MARK: - Send

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading, !isAtLimit else { return }

        messages.append(CheckInMessage(role: .user, content: text, timestamp: .now))
        inputText = ""
        errorMessage = nil

        Task { await generateResponse(to: text) }
    }

    // MARK: - AI response

    @MainActor
    private func generateResponse(to message: String) async {
        isLoading = true

        // History = all messages except the welcome and the just-added user message.
        let history: [(role: String, content: String)] = messages
            .filter { !$0.isWelcome }
            .dropLast()                         // exclude the user message we pass separately
            .map { (role: $0.role.apiString, content: $0.content) }

        let canvas = buildCanvasContext()

        do {
            let response = try await AIService.shared.checkInWithClaude(
                userMessage: message,
                conversationHistory: history,
                canvas: canvas
            )
            messages.append(CheckInMessage(role: .assistant, content: response, timestamp: .now))
        } catch {
            errorMessage = "Couldn't reach Claude. Check your connection and try again."
            print("❌ Check-in error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Canvas context

    private func buildCanvasContext() -> CanvasContext {
        let descriptor = FetchDescriptor<Canvas>()
        guard let canvas = try? modelContext.fetch(descriptor).first else {
            return CanvasContext(lifeAreas: [], reflections: [])
        }
        let answers = canvas.onboardingAnswers
            .filter { !$0.answer.isEmpty }
            .map { (question: $0.question, answer: $0.answer) }

        return CanvasContext(
            lifeAreas: canvas.lifeAreas.sorted { $0.priorityRank < $1.priorityRank }.map {
                (name: $0.name, emoji: $0.emoji, vision: $0.vision,
                 currentReality: $0.currentReality, status: $0.statusEnum,
                 progressScore: $0.progressScore, priorityRank: $0.priorityRank)
            },
            reflections: answers
        )
    }
}
