import SwiftUI
import SwiftData
import Combine

final class ProofOfGrowthViewModel: ObservableObject {

    @Published var currentSlide: Int = 0
    @Published var showShareSheet: Bool = false

    let narrative: StoryNarrative
    let report: MonthlyReport
    let totalSlides = 5

    init(narrative: StoryNarrative, report: MonthlyReport) {
        self.narrative = narrative
        self.report = report
    }

    var shareCard: ShareCard {
        ShareCard(
            month: report.month,
            completedActions: report.completedActions,
            totalActions: report.totalActions,
            completionRate: report.completionRate,
            canvasPoints: report.canvasChanges.reduce(0) { $0 + $1.delta },
            topArea: report.highlights.first ?? "",
            nextFocus: narrative.nextFocus,
            headline: narrative.headline
        )
    }

    func nextSlide() {
        if currentSlide < totalSlides - 1 {
            withAnimation(.easeInOut(duration: 0.35)) { currentSlide += 1 }
        }
    }

    func previousSlide() {
        if currentSlide > 0 {
            withAnimation(.easeInOut(duration: 0.35)) { currentSlide -= 1 }
        }
    }

    var isLastSlide: Bool { currentSlide == totalSlides - 1 }
    func prepareShare() { showShareSheet = true }
}

struct ShareCard {
    let month: String
    let completedActions: Int
    let totalActions: Int
    let completionRate: Double
    let canvasPoints: Int
    let topArea: String
    let nextFocus: String
    let headline: String
}
