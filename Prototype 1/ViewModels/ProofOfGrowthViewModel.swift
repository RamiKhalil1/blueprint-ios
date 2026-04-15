import SwiftUI
import SwiftData
import Combine

final class ProofOfGrowthViewModel: ObservableObject {

    @Published var currentSlide: Int = 0
    @Published var slides: [GrowthSlide] = []
    @Published var shareCard: ShareCard? = nil
    @Published var showShareSheet: Bool = false
    @Published var shareImage: UIImage? = nil

    let narrative: StoryNarrative
    let report: MonthlyReport
    let totalSlides = 5

    init(narrative: StoryNarrative, report: MonthlyReport) {
        self.narrative = narrative
        self.report = report
        buildSlides()
    }

    // MARK: - Build slides
    private func buildSlides() {
        slides = [
            GrowthSlide(
                type: .opening,
                title: report.month,
                body: "Here's what you actually built this month.",
                detail: nil
            ),
            GrowthSlide(
                type: .savings,
                title: "$\(Int(report.savedAmount))",
                body: "saved with intention",
                detail: nil
            ),
            GrowthSlide(
                type: .actions,
                title: "\(report.completedActions) of \(report.totalActions)",
                body: "actions completed",
                detail: report.highlights.joined(separator: "\n")
            ),
            GrowthSlide(
                type: .gap,
                title: "Your canvas moved.",
                body: narrative.narrative,
                detail: nil
            ),
            GrowthSlide(
                type: .shareCard,
                title: narrative.headline,
                body: "Next focus: \(narrative.nextFocus)",
                detail: nil
            )
        ]

        shareCard = ShareCard(
            month: report.month,
            savedAmount: report.savedAmount,
            actionsCompleted: report.completedActions,
            totalActions: report.totalActions,
            canvasPoints: report.canvasChanges.reduce(0) { $0 + $1.delta },
            highlight: report.highlights.first ?? ""
        )
    }

    // MARK: - Navigation
    func nextSlide() {
        if currentSlide < totalSlides - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { currentSlide += 1 }
        }
    }

    func previousSlide() {
        if currentSlide > 0 {
            withAnimation(.easeInOut(duration: 0.3)) { currentSlide -= 1 }
        }
    }

    var isLastSlide: Bool { currentSlide == totalSlides - 1 }

    // MARK: - Share
    func prepareShare() {
        showShareSheet = true
    }

    @MainActor
    func renderShareImage(view: some View) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
    }
}

// MARK: - Models
struct GrowthSlide: Identifiable {
    let id = UUID()
    let type: SlideType
    let title: String
    let body: String
    let detail: String?

    enum SlideType {
        case opening, savings, actions, gap, shareCard
    }
}

struct ShareCard {
    let month: String
    let savedAmount: Double
    let actionsCompleted: Int
    let totalActions: Int
    let canvasPoints: Int
    let highlight: String
}
