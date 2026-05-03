import SwiftUI

struct ProofOfGrowthView: View {
    @StateObject private var vm: ProofOfGrowthViewModel
    @Environment(\.dismiss) private var dismiss

    init(narrative: StoryNarrative, report: MonthlyReport) {
        _vm = StateObject(wrappedValue: ProofOfGrowthViewModel(narrative: narrative, report: report))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#1A1208").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<vm.totalSlides, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i <= vm.currentSlide
                                      ? Color(hex: "#BA7517")
                                      : Color.white.opacity(0.15))
                                .frame(width: i == vm.currentSlide ? 28 : 6, height: 4)
                                .animation(.easeInOut(duration: 0.25), value: vm.currentSlide)
                        }
                    }
                    Spacer()
                    Image(systemName: "xmark").opacity(0).font(.system(size: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Slide
                ZStack {
                    switch vm.currentSlide {
                    case 0: Slide1_Opening(report: vm.report)
                    case 1: Slide2_Tasks(report: vm.report)
                    case 2: Slide3_Areas(report: vm.report, narrative: vm.narrative)
                    case 3: Slide4_Gap(report: vm.report, narrative: vm.narrative)
                    case 4: Slide5_Final(card: vm.shareCard, narrative: vm.narrative)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.35), value: vm.currentSlide)

                // Navigation
                HStack(spacing: 12) {
                    if vm.currentSlide > 0 {
                        Button { vm.previousSlide() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#BA7517").opacity(0.7))
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(24)
                        }
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }
                    Spacer()
                    Button {
                        if vm.isLastSlide { vm.prepareShare() }
                        else { vm.nextSlide() }
                    } label: {
                        HStack(spacing: 8) {
                            Text(vm.isLastSlide ? "Share my story" : "Continue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#1A1208"))
                            Image(systemName: vm.isLastSlide ? "square.and.arrow.up" : "arrow.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#1A1208"))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#BA7517"))
                        .cornerRadius(24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.showShareSheet) {
            ShareCardSheet(card: vm.shareCard)
        }
    }
}

// MARK: - Slide 1: Opening
private struct Slide1_Opening: View {
    let report: MonthlyReport
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(report.month.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)

            Text("Here's what you\nactually built.")
                .font(.custom("Georgia", size: 36))
                .foregroundColor(Color(hex: "#FAC775"))
                .lineSpacing(6)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            Spacer().frame(height: 32)

            Text("Every task ticked. Every step forward.\nEvery gap that got a little smaller.")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(6)
                .opacity(appeared ? 1 : 0)

            Spacer()

            // Teaser stats
            HStack(spacing: 0) {
                TeaserStat(value: "\(report.completedActions)", label: "tasks done")
                TeaserStat(value: "\(report.areaProgress.filter { $0.rating == .yes }.count)🔥", label: "areas on fire")
                TeaserStat(value: "\(Int(report.completionRate * 100))%", label: "completion")
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }
}

private struct TeaserStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "#FAC775"))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Slide 2: Tasks
private struct Slide2_Tasks: View {
    let report: MonthlyReport
    @State private var appeared = false
    @State private var barFilled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GROWTH TASKS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(report.completedActions)")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundColor(Color(hex: "#FAC775"))
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.7, anchor: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("of \(report.totalActions)")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    Text("tasks done")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
            }
            .padding(.bottom, 24)

            // Big progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#BA7517"), Color(hex: "#FAC775")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: barFilled ? geo.size.width * report.completionRate : 0, height: 12)
                            .animation(.easeOut(duration: 1.0).delay(0.3), value: barFilled)
                    }
                }
                .frame(height: 12)
                Text("\(Int(report.completionRate * 100))% completion rate this month")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 32)

            // Per area breakdown
            VStack(spacing: 12) {
                ForEach(Array(report.areaProgress.enumerated()), id: \.offset) { i, area in
                    HStack(spacing: 10) {
                        Text(area.emoji).font(.system(size: 16))
                        Text(area.name)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(area.completed)/\(area.total)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BA7517"))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#BA7517").opacity(0.7))
                                    .frame(width: barFilled ? geo.size.width * area.progress : 0, height: 4)
                                    .animation(.easeOut(duration: 0.6).delay(0.2 + Double(i) * 0.08), value: barFilled)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.07), value: appeared)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
            barFilled = true
        }
    }
}

// MARK: - Slide 3: Areas check-in
private struct Slide3_Areas: View {
    let report: MonthlyReport
    let narrative: StoryNarrative
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOW YOU SHOWED UP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 20)

            Text("Area by area.")
                .font(.custom("Georgia", size: 28))
                .foregroundColor(Color(hex: "#FAC775"))
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                ForEach(Array(report.areaProgress.enumerated()), id: \.offset) { i, area in
                    HStack(spacing: 12) {
                        Text(area.emoji)
                            .font(.system(size: 22))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(area.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                            Text("\(area.completed) of \(area.total) tasks")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }

                        Spacer()

                        // Rating badge
                        ratingBadge(for: area.rating)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.08), value: appeared)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    @ViewBuilder
    private func ratingBadge(for rating: CheckInRating) -> some View {
        switch rating {
        case .yes:
            Text("🔥 Strong")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#1D9E75"))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(hex: "#1D9E75").opacity(0.15))
                .cornerRadius(20)
        case .partly:
            Text("🌱 Growing")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(hex: "#BA7517").opacity(0.15))
                .cornerRadius(20)
        case .notReally:
            Text("💤 Drifted")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
        case .notRated:
            Text("— Not rated")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        }
    }
}

// MARK: - Slide 4: The Gap
private struct Slide4_Gap: View {
    let report: MonthlyReport
    let narrative: StoryNarrative
    @State private var appeared = false
    @State private var barsAnimated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THE GAP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 20)

            Text("The gap is closing.")
                .font(.custom("Georgia", size: 28))
                .foregroundColor(Color(hex: "#FAC775"))
                .padding(.bottom, 14)

            Text(narrative.narrative)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(5)
                .padding(.bottom, 28)
                .opacity(appeared ? 1 : 0)

            // Visual gap bars per area
            VStack(spacing: 16) {
                ForEach(Array(report.areaProgress.enumerated()), id: \.offset) { i, area in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(area.emoji) \(area.name)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("\(Int(area.progress * 100))% to vision")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#BA7517"))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(area.progress > 0.6
                                          ? Color(hex: "#FAC775")
                                          : Color(hex: "#BA7517").opacity(0.7))
                                    .frame(
                                        width: barsAnimated ? geo.size.width * area.progress : 0,
                                        height: 6
                                    )
                                    .animation(.easeOut(duration: 0.7).delay(Double(i) * 0.1), value: barsAnimated)
                            }
                        }
                        .frame(height: 6)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.08), value: appeared)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#BA7517"))
                Text("Next month focus: \(narrative.nextFocus)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#BA7517"))
            }
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation { appeared = true }
            barsAnimated = true
        }
    }
}

// MARK: - Slide 5: Final share card
private struct Slide5_Final: View {
    let card: ShareCard
    let narrative: StoryNarrative
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Blueprint · \(card.month)")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(hex: "#BA7517"))
                .padding(.bottom, 20)

            Text(narrative.headline)
                .font(.custom("Georgia", size: 28))
                .foregroundColor(Color(hex: "#FAC775"))
                .lineSpacing(5)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.bottom, 20)

            HStack(spacing: 0) {
                FinalStat(value: "\(card.completedActions)/\(card.totalActions)", label: "tasks done", icon: "checkmark.circle.fill")
                FinalStat(value: "\(Int(card.completionRate * 100))%", label: "completion", icon: "chart.bar.fill")
                FinalStat(value: "+\(card.canvasPoints)", label: "growth pts", icon: "arrow.up.circle.fill")
            }
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)

            if !card.topArea.isEmpty {
                HStack(spacing: 8) {
                    Text("🔥")
                    Text(card.topArea)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FAC775").opacity(0.8))
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .padding(.bottom, 12)
                .opacity(appeared ? 1 : 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#BA7517"))
                Text("Next focus: \(card.nextFocus)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#BA7517"))
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }
}

private struct FinalStat: View {
    let value: String
    let label: String
    let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BA7517"))
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "#FAC775"))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
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
        ZStack {
            Color(hex: "#1A1208").ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ShareCardPreview(card: card)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
                    .padding(.horizontal, 32)

                Text("Screenshot or share your growth card")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                Button {
                    guard renderedImage != nil else { return }
                    showSystemShare = true
                } label: {
                    HStack(spacing: 8) {
                        if renderedImage == nil {
                            ProgressView().scaleEffect(0.8).tint(Color(hex: "#1A1208"))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Share my story")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(renderedImage == nil ? Color(hex: "#BA7517").opacity(0.5) : Color(hex: "#BA7517"))
                    .foregroundColor(Color(hex: "#1A1208"))
                    .cornerRadius(14)
                }
                .disabled(renderedImage == nil)
                .padding(.horizontal, 24)

                Button("Done") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSystemShare) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Preparing your image…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { renderImage() }
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
            HStack {
                Text("BLUEPRINT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#BA7517"))
                Spacer()
                Text(card.month.uppercased())
                    .font(.system(size: 9))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 16)

            Text(card.headline)
                .font(.custom("Georgia", size: 20))
                .foregroundColor(Color(hex: "#FAC775"))
                .lineSpacing(4)
                .padding(.bottom, 20)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.bottom, 16)

            HStack(spacing: 0) {
                MiniStat(value: "\(card.completedActions)/\(card.totalActions)", label: "tasks")
                MiniStat(value: "\(Int(card.completionRate * 100))%", label: "done")
                MiniStat(value: "+\(card.canvasPoints)", label: "growth pts")
            }
            .padding(.bottom, 14)

            if !card.nextFocus.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#BA7517"))
                    Text("Next: \(card.nextFocus)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
            }
        }
        .padding(24)
        .background(Color(hex: "#1A1208"))
        .cornerRadius(20)
    }
}

private struct MiniStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .medium)).foregroundColor(Color(hex: "#FAC775"))
            Text(label).font(.system(size: 9)).foregroundColor(Color(hex: "#BA7517"))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
