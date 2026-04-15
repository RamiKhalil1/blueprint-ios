import SwiftUI

struct ProofOfGrowthView: View {
    @StateObject private var vm: ProofOfGrowthViewModel
    @Environment(\.dismiss) private var dismiss

    init(narrative: StoryNarrative, report: MonthlyReport) {
        _vm = StateObject(wrappedValue: ProofOfGrowthViewModel(narrative: narrative, report: report))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#412402").ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#FAC775").opacity(0.6))
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(0..<vm.totalSlides, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i == vm.currentSlide
                                      ? Color(hex: "#FAC775")
                                      : Color.white.opacity(0.25))
                                .frame(width: i == vm.currentSlide ? 20 : 5, height: 4)
                                .animation(.easeInOut(duration: 0.25), value: vm.currentSlide)
                        }
                    }

                    Spacer()

                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 32)

                ZStack {
                    ForEach(Array(vm.slides.enumerated()), id: \.element.id) { index, slide in
                        if index == vm.currentSlide {
                            slideView(for: slide)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .id(index)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)

                HStack(spacing: 12) {
                    if vm.currentSlide > 0 {
                        Button {
                            vm.previousSlide()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#FAC775").opacity(0.6))
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(24)
                        }
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }

                    Spacer()

                    Button {
                        if vm.isLastSlide {
                            vm.prepareShare()
                        } else {
                            vm.nextSlide()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(vm.isLastSlide ? "Share my story" : "Continue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#412402"))
                            Image(systemName: vm.isLastSlide ? "square.and.arrow.up" : "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#412402"))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#FAC775"))
                        .cornerRadius(24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.showShareSheet) {
            if let card = vm.shareCard {
                ShareCardSheet(card: card)
            }
        }
    }

    // MARK: - Slide factory
    @ViewBuilder
    private func slideView(for slide: GrowthSlide) -> some View {
        switch slide.type {
        case .opening:   OpeningSlide(slide: slide, month: vm.report.month)
        case .savings:   SavingsSlide(slide: slide, report: vm.report)
        case .actions:   ActionsSlide(slide: slide, report: vm.report)
        case .gap:       GapSlide(slide: slide, changes: vm.report.canvasChanges)
        case .shareCard: FinalSlide(card: vm.shareCard!, narrative: vm.narrative) {
            vm.prepareShare()
        }
        }
    }
}

// MARK: - Slide 1: Opening
private struct OpeningSlide: View {
    let slide: GrowthSlide
    let month: String
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(month.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.1)
                .foregroundColor(Color(hex: "#BA7517"))
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 16)

            Text(slide.body)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(hex: "#FAC775"))
                .lineSpacing(6)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

// MARK: - Slide 2: Savings
private struct SavingsSlide: View {
    let slide: GrowthSlide
    let report: MonthlyReport
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your savings")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.1)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 12)

            Text("$\(Int(report.savedAmount))")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(Color(hex: "#FAC775"))
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85, anchor: .leading)

            Text("put aside this month")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#EF9F27"))
                .padding(.bottom, 28)

            Divider().background(Color.white.opacity(0.1)).padding(.bottom, 20)

            Text("Where it went")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 10)

            VStack(spacing: 10) {
                SavingsBarRow(label: "Experiences", amount: 140, total: Int(report.savedAmount))
                SavingsBarRow(label: "Place",       amount: 80,  total: Int(report.savedAmount))
                SavingsBarRow(label: "Identity",    amount: 60,  total: Int(report.savedAmount))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
        }
    }
}

private struct SavingsBarRow: View {
    let label: String; let amount: Int; let total: Int
    @State private var filled = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12)).foregroundColor(Color(hex: "#854F0B"))
                Spacer()
                Text("$\(amount)").font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "#FAC775"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.1)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#BA7517"))
                        .frame(width: filled ? geo.size.width * (Double(amount) / Double(max(total, 1))) : 0, height: 4)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: filled)
                }
            }
            .frame(height: 4)
        }
        .onAppear { filled = true }
    }
}

// MARK: - Slide 3: Actions
private struct ActionsSlide: View {
    let slide: GrowthSlide
    let report: MonthlyReport
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Actions completed")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.1)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 16)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(report.completedActions)")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(Color(hex: "#FAC775"))
                Text("/ \(report.totalActions)")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color(hex: "#633806"))
            }
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(report.highlights.enumerated()), id: \.offset) { i, highlight in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: "#1D9E75")).frame(width: 6, height: 6)
                        Text(highlight)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FAC775").opacity(0.85))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -10)
                    .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.1), value: appeared)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Slide 4: Gap movement
private struct GapSlide: View {
    let slide: GrowthSlide
    let changes: [(area: String, delta: Int)]
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your canvas moved.")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "#FAC775"))
                .padding(.bottom, 16)

            Text(slide.body)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(Color(hex: "#EF9F27"))
                .lineSpacing(4)
                .padding(.bottom, 28)

            VStack(spacing: 12) {
                ForEach(Array(changes.enumerated()), id: \.offset) { i, change in
                    HStack {
                        Text(change.area)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#BA7517"))
                        Spacer()
                        Text("+\(change.delta) pts")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#FAC775"))
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.1), value: appeared)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Slide 5: Final card
private struct FinalSlide: View {
    let card: ShareCard
    let narrative: StoryNarrative
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Blueprint · \(card.month)")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.08)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 12)

            Text(narrative.headline)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color(hex: "#FAC775"))
                .lineSpacing(3)
                .padding(.bottom, 20)

            Divider().background(Color.white.opacity(0.1)).padding(.bottom, 16)

            HStack(spacing: 0) {
                StatBlock(value: "$\(Int(card.savedAmount))", label: "saved")
                StatBlock(value: "\(card.actionsCompleted)/\(card.totalActions)", label: "actions")
                StatBlock(value: "+\(card.canvasPoints)", label: "canvas pts")
            }
            .padding(.bottom, 20)

            if !card.highlight.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#1D9E75")).frame(width: 6, height: 6)
                    Text(card.highlight)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#EF9F27"))
                }
                .padding(.bottom, 16)
            }

            Text("Next focus: \(narrative.nextFocus)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#BA7517"))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatBlock: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .medium)).foregroundColor(Color(hex: "#FAC775"))
            Text(label).font(.system(size: 10)).foregroundColor(Color(hex: "#BA7517"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share Card Sheet
struct ShareCardSheet: View {
    let card: ShareCard
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var renderedImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            ShareCardPreview(card: card)
                .cornerRadius(16)
                .padding(.horizontal, 32)
                .padding(.top, 32)

            Text("Screenshot this card or use the share button below.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showSystemShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#412402"))
                .foregroundColor(Color(hex: "#FAEEDA"))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Button("Done") { dismiss() }
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showSystemShare) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
        .onAppear { renderImage() }
        .presentationDetents([.large])
    }

    private func renderImage() {
        let renderer = ImageRenderer(content: ShareCardPreview(card: card).frame(width: 320))
        renderer.scale = 3
        renderedImage = renderer.uiImage
    }
}

struct ShareCardPreview: View {
    let card: ShareCard
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BLUEPRINT · \(card.month.uppercased())")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.1)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 12)

            Text("$\(Int(card.savedAmount))")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color(hex: "#FAC775"))
            Text("saved with intention")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#EF9F27"))
                .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.15)).padding(.bottom, 14)

            HStack {
                MiniStat(value: "\(card.actionsCompleted)/\(card.totalActions)", label: "actions done")
                MiniStat(value: "+\(card.canvasPoints)", label: "canvas pts")
                if !card.highlight.isEmpty {
                    MiniStat(value: card.highlight, label: "highlight")
                }
            }
        }
        .padding(24)
        .background(Color(hex: "#412402"))
        .cornerRadius(16)
    }
}

private struct MiniStat: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#FAC775"))
            Text(label).font(.system(size: 9)).foregroundColor(Color(hex: "#BA7517"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
