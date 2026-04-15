import SwiftUI
import SwiftData
import Combine

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case splash        = 0
    case visionBoard   = 1
    case reflections   = 2
    case priorityRank  = 3
    case complete      = 4
}

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Navigation
    @Published var currentStep: OnboardingStep = .splash

    // MARK: - Vision Board
    @Published var visionItems: [VisionItem] = []
    @Published var showImagePicker = false
    @Published var pendingCaption = ""

    // MARK: - Reflections
    @Published var reflectionAnswers: [Int: String] = [:]
    @Published var currentQuestionIndex = 0

    // Hardcoded for Phase 1; Phase 2 can swap in AI-generated questions
    let reflectionQuestions: [String] = [
        "You added items to your vision board. What feeling are you chasing most?",
        "What does a perfect Tuesday look like for you?",
        "What would you stop doing tomorrow if money wasn't a constraint?",
        "Where do you feel most like yourself?",
        "What's one thing you keep saying you'll do 'someday'?"
    ]

    // MARK: - Priority Rank
    @Published var rankedAreas: [LifeAreaType] = LifeAreaType.allCases

    // MARK: - Private
    private var canvas: Canvas?
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadOrCreateCanvas()
    }

    // MARK: - Canvas bootstrap

    private func loadOrCreateCanvas() {
        let descriptor = FetchDescriptor<Canvas>()
        if let existing = try? modelContext.fetch(descriptor).first {
            canvas = existing
            if existing.onboardingComplete {
                currentStep = .complete
            }
            visionItems = existing.visionItems.sorted { $0.sortIndex < $1.sortIndex }
            rankedAreas = existing.lifeAreas
                .sorted { $0.priorityRank < $1.priorityRank }
                .map { $0.type }
            for r in existing.reflections {
                reflectionAnswers[r.questionIndex] = r.answer
            }
        } else {
            let newCanvas = Canvas()
            modelContext.insert(newCanvas)
            canvas = newCanvas
            try? modelContext.save()
        }
    }

    // MARK: - Navigation helpers
    func advance() {
        let next = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
        if next == .complete {
            finaliseOnboarding()
        }
    }

    func skipReflectionQuestion() {
        if currentQuestionIndex < reflectionQuestions.count - 1 {
            currentQuestionIndex += 1
        } else {
            advance()
        }
    }

    func submitReflectionAnswer(_ answer: String) {
        guard let canvas else { return }
        reflectionAnswers[currentQuestionIndex] = answer

        if let existing = canvas.reflections.first(where: { $0.questionIndex == currentQuestionIndex }) {
            existing.answer = answer
        } else {
            let r = Reflection(
                questionIndex: currentQuestionIndex,
                questionText: reflectionQuestions[currentQuestionIndex],
                answer: answer
            )
            canvas.reflections.append(r)
        }
        save()

        if currentQuestionIndex < reflectionQuestions.count - 1 {
            currentQuestionIndex += 1
        } else {
            advance()
        }
    }

    // MARK: - Vision Board
    func addVisionItem(caption: String, imageData: Data? = nil) {
        guard let canvas else { return }
        let item = VisionItem(
            caption: caption,
            imageData: imageData,
            sortIndex: visionItems.count
        )
        canvas.visionItems.append(item)
        visionItems.append(item)
        save()
    }

    func removeVisionItem(at offsets: IndexSet) {
        guard let canvas else { return }
        for index in offsets {
            let item = visionItems[index]
            canvas.visionItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }
        visionItems.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Priority Rank
    func moveArea(from source: IndexSet, to destination: Int) {
        rankedAreas.move(fromOffsets: source, toOffset: destination)
    }

    func saveRanking() {
        guard let canvas else { return }
        for (index, areaType) in rankedAreas.enumerated() {
            if let area = canvas.lifeAreas.first(where: { $0.type == areaType }) {
                area.priorityRank = index + 1
            }
        }
        save()
        advance()
    }

    // MARK: - Finalise
    private func finaliseOnboarding() {
        canvas?.onboardingComplete = true
        canvas?.updatedAt = .now
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
