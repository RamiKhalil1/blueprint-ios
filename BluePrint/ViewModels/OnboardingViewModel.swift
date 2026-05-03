import SwiftUI
import SwiftData
import Combine

// MARK: - Onboarding Step
enum OnboardingStep: Int {
    case splash         = 0
    case photoSwipe     = 1
    case questions      = 2
    case addPhotoPrompt = 3
    case generating     = 4
    case reviewAreas    = 5
    case complete       = 6
}

// MARK: - Pre-loaded photo data
struct OnboardingPhoto: Identifiable {
    let id = UUID()
    let assetName: String
    let description: String
}

let onboardingPhotos: [OnboardingPhoto] = [
    OnboardingPhoto(assetName: "photo_travel",      description: "A person backpacking through a mountain trail at sunrise, looking free and adventurous"),
    OnboardingPhoto(assetName: "photo_city",        description: "A modern minimalist apartment in a vibrant city with floor to ceiling windows and city views"),
    OnboardingPhoto(assetName: "photo_creative",    description: "An artist's studio filled with paintings, natural light, and creative tools spread across a large desk"),
    OnboardingPhoto(assetName: "photo_fitness",     description: "A person doing yoga on a beach at dawn, looking calm, strong and centered"),
    OnboardingPhoto(assetName: "photo_social",      description: "A phone screen showing social media apps including Instagram, Pinterest and Twitter, representing digital connection and an active social life online"),
    OnboardingPhoto(assetName: "photo_nature",      description: "A remote cabin in the forest with no neighbours, surrounded by tall trees and total silence"),
    OnboardingPhoto(assetName: "photo_career",      description: "A person working on a laptop from a cafe in Bali, with a coffee and tropical surroundings"),
    OnboardingPhoto(assetName: "photo_luxury",      description: "A sleek luxury car parked outside a high-end restaurant in a busy city at night"),
    OnboardingPhoto(assetName: "photo_family",      description: "A family playing together in a large backyard of a beautiful home on a sunny afternoon"),
    OnboardingPhoto(assetName: "photo_learning",    description: "A person reading and studying surrounded by books, notes and a cup of tea in a cosy home library")
]

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Navigation
    @Published var currentStep: OnboardingStep = .splash

    // MARK: - Photo swipe
    @Published var currentPhotoIndex: Int = 0
    @Published var interactions: [PhotoInteraction] = []
    @Published var swipeOffset: CGFloat = 0
    @Published var swipeRotation: Double = 0

    // MARK: - Questions
    @Published var currentQuestions: [String] = []
    @Published var currentAnswers: [String] = ["", ""]
    @Published var currentQuestionPhotoIndex: Int = 0
    @Published var allAnswers: [OnboardingAnswer] = []
    @Published var isLoadingQuestions = false

    // MARK: - Custom photo
    @Published var showImagePicker = false
    @Published var pendingCustomImage: Data? = nil
    @Published var pendingCustomCaption: String = ""
    @Published var showCustomPhotoSheet = false

    // MARK: - Generating
    @Published var generatingMessage = "Learning about you..."
    @Published var generatedAreas: [GeneratedLifeArea] = []
    @Published var isGenerating = false

    // MARK: - Error
    @Published var errorMessage: String? = nil

    private var canvas: Canvas?
    private let modelContext: ModelContext

    var currentPhoto: OnboardingPhoto? {
        guard currentPhotoIndex < onboardingPhotos.count else { return nil }
        return onboardingPhotos[currentPhotoIndex]
    }

    var allPhotosSwiped: Bool {
        currentPhotoIndex >= onboardingPhotos.count
    }

    var likedCount: Int { interactions.filter { $0.isLiked }.count }
    var dislikedCount: Int { interactions.filter { !$0.isLiked }.count }

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
        } else {
            let newCanvas = Canvas()
            modelContext.insert(newCanvas)
            canvas = newCanvas
            try? modelContext.save()
        }
    }

    // MARK: - Photo swipe actions

    func likePhoto() {
        guard let photo = currentPhoto else { return }
        recordInteraction(photo: photo, isLiked: true)
    }

    func dislikePhoto() {
        guard let photo = currentPhoto else { return }
        recordInteraction(photo: photo, isLiked: false)
    }

    private func recordInteraction(photo: OnboardingPhoto, isLiked: Bool) {
        guard let canvas else { return }
        let interaction = PhotoInteraction(
            photoName: photo.assetName,
            photoDescription: photo.description,
            isLiked: isLiked,
            sortIndex: currentPhotoIndex
        )
        canvas.photoInteractions.append(interaction)
        interactions.append(interaction)
        try? modelContext.save()

        currentPhotoIndex += 1
        currentQuestions = []
        currentAnswers = ["", ""]
        isLoadingQuestions = true
        currentStep = .questions

        let description = interaction.photoDescription
        let liked = interaction.isLiked

        Task.detached { [weak self] in
            guard let self else { return }
            print("🔄 Generating questions for: \(description)")
            let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "MISSING"
            print("🔄 API Key present: \(apiKey != "MISSING")")
            do {
                let questions = try await AIService.shared.generatePhotoQuestions(
                    photoDescription: description,
                    isLiked: liked
                )
                print("✅ Got \(questions.count) questions: \(questions)")
                await MainActor.run {
                    self.currentQuestions = questions.isEmpty ? [
                        "What feeling did this photo give you?",
                        "How does this connect to where you want to be in life?"
                    ] : questions
                    self.currentAnswers = Array(repeating: "", count: self.currentQuestions.count)
                    self.isLoadingQuestions = false
                }
            } catch {
                print("❌ Question generation error: \(error)")
                await MainActor.run {
                    self.currentQuestions = [
                        "What feeling did this photo give you?",
                        "How does this connect to where you want to be in life?"
                    ]
                    self.currentAnswers = ["", ""]
                    self.isLoadingQuestions = false
                }
            }
        }
    }

    func addCustomPhoto(imageData: Data, caption: String) {
        guard let canvas else { return }
        let interaction = PhotoInteraction(
            photoName: "custom_\(UUID().uuidString)",
            photoDescription: caption,
            isLiked: true,
            isCustom: true,
            userCaption: caption,
            imageData: imageData,
            sortIndex: currentPhotoIndex
        )
        canvas.photoInteractions.append(interaction)
        interactions.append(interaction)
        try? modelContext.save()
        showCustomPhotoSheet = false

        // Ask questions about the custom photo
        currentQuestions = []
        currentAnswers = ["", ""]
        isLoadingQuestions = true
        currentStep = .questions

        Task {
            print("🔄 Generating questions for: \(interaction.photoDescription)")
            print("🔄 API Key: \(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "MISSING")")
            do {
                let questions = try await AIService.shared.generatePhotoQuestions(
                    photoDescription: interaction.photoDescription,
                    isLiked: interaction.isLiked
                )
                print("✅ Got questions: \(questions)")
                self.currentQuestions = questions.isEmpty ? [
                    "What feeling did this photo give you?",
                    "How does this connect to where you want to be in life?"
                ] : questions
                self.currentAnswers = Array(repeating: "", count: self.currentQuestions.count)
                self.isLoadingQuestions = false
            } catch {
                print("❌ Question generation error: \(error)")
                self.currentQuestions = [
                    "What feeling did this photo give you?",
                    "How does this connect to where you want to be in life?"
                ]
                self.currentAnswers = ["", ""]
                self.isLoadingQuestions = false
            }
        }
    }

    // MARK: - Questions

    func submitAnswers() {
        guard let canvas else { return }
        guard currentQuestionPhotoIndex < interactions.count else {
            // Index out of bounds — advance gracefully
            currentQuestionPhotoIndex += 1
            currentQuestions = []
            currentAnswers = ["", ""]
            currentStep = allPhotosSwiped ? .addPhotoPrompt : .photoSwipe
            return
        }
        let currentInteraction = interactions[currentQuestionPhotoIndex]

        for (index, question) in currentQuestions.enumerated() {
            let answer = index < currentAnswers.count ? currentAnswers[index] : ""
            if !answer.isEmpty {
                let onboardingAnswer = OnboardingAnswer(
                    photoName: currentInteraction.photoName,
                    question: question,
                    answer: answer
                )
                canvas.onboardingAnswers.append(onboardingAnswer)
                allAnswers.append(onboardingAnswer)
            }
        }
        try? modelContext.save()

        currentQuestionPhotoIndex += 1

        // Clear old questions immediately
        currentQuestions = []
        currentAnswers = ["", ""]

        currentStep = allPhotosSwiped ? .addPhotoPrompt : .photoSwipe
    }

    func skipQuestions() {
        currentQuestionPhotoIndex += 1
        currentQuestions = []
        currentAnswers = ["", ""]
        withAnimation { currentStep = allPhotosSwiped ? .addPhotoPrompt : .photoSwipe }
    }
    
    func proceedToGenerate() {
        currentStep = .generating
        Task { await generateCanvas() }
    }
    
    func confirmAreas() {
        guard let canvas else { return }
        canvas.onboardingComplete = true
        canvas.updatedAt = .now
        try? modelContext.save()
        withAnimation { currentStep = .complete }
    }

    func regenerateAreas() {
        guard let canvas else { return }
        // Clear existing areas and tasks
        for area in canvas.lifeAreas {
            modelContext.delete(area)
        }
        canvas.lifeAreas = []
        try? modelContext.save()
        withAnimation { currentStep = .generating }
        Task { await generateCanvas() }
    }

    // MARK: - Generate Canvas

    @MainActor
    func generateCanvas() async {
        guard let canvas else { return }
        isGenerating = true

        let messages = [
            "Learning about you...",
            "Identifying your life areas...",
            "Building your vision...",
            "Crafting your current reality...",
            "Almost ready..."
        ]

        // Cycle through messages
        Task {
            for message in messages {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                generatingMessage = message
            }
        }

        do {
            // Generate life areas
            generatingMessage = "Identifying your life areas..."
            let areas = try await AIService.shared.generateLifeAreas(
                interactions: canvas.photoInteractions,
                answers: canvas.onboardingAnswers
            )

            generatingMessage = "Building your canvas..."

            // Create LifeArea models and generate tasks for each
            for (index, area) in areas.enumerated() {
                let lifeArea = LifeArea(
                    name: area.name,
                    areaDescription: area.description,
                    emoji: area.emoji,
                    vision: area.vision,
                    currentReality: area.currentReality,
                    priorityRank: index + 1
                )
                canvas.lifeAreas.append(lifeArea)
                modelContext.insert(lifeArea)

                // Generate 20 tasks per area
                generatingMessage = "Creating tasks for \(area.emoji) \(area.name)..."
                do {
                    let tasks = try await AIService.shared.generateAreaTasks(
                        areaName: area.name,
                        vision: area.vision,
                        currentReality: area.currentReality,
                        emoji: area.emoji
                    )
                    for task in tasks {
                        let areaTask = AreaTask(
                            title: task.title,
                            note: task.note,
                            blockerType: TaskBlockerType(rawValue: task.blockerType) ?? .habit,
                            sortIndex: task.sortIndex
                        )
                        lifeArea.tasks.append(areaTask)
                        modelContext.insert(areaTask)
                    }
                } catch {
                    print("❌ Task generation failed for \(area.name): \(error)")
                }
            }

            try? modelContext.save()

            generatingMessage = "Your Blueprint is ready ✨"
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            isGenerating = false
            withAnimation { currentStep = .reviewAreas }

        } catch {
            isGenerating = false
            errorMessage = "Something went wrong. Please try again."
            print("❌ Canvas generation failed: \(error)")
        }
    }

    // MARK: - Navigation
    func advance() {
        let next = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }
}
