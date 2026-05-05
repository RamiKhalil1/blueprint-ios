import SwiftUI
import SwiftData

struct ReviewAreasView: View {
    @ObservedObject var vm: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var canvases: [Canvas]

    private var canvas: Canvas? { canvases.first }

    private var lifeAreas: [LifeArea] {
        canvas?.lifeAreas.sorted { $0.priorityRank < $1.priorityRank } ?? []
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Header ─────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Blueprint")
                                .font(.custom("Georgia", size: 30))
                                .foregroundColor(.primary)
                            Text("Claude identified 5 life areas from your photo choices and answers. See exactly why each was chosen below.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(.top, 56)

                        // ── Generation source summary ──────────────────────────
                        GenerationSourceView(canvas: canvas)

                        // ── Area cards ─────────────────────────────────────────
                        VStack(spacing: 16) {
                            ForEach(lifeAreas) { area in
                                AreaReviewCard(
                                    area: area,
                                    isRegenerating: vm.regeneratingAreaId == area.id,
                                    onRegenerate: { vm.regenerateArea(area) }
                                )
                            }
                        }

                        // ── Global regenerate (all 5) ──────────────────────────
                        Button {
                            vm.regenerateAreas()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                Text("Start over — regenerate all 5 areas")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 4)
                        .disabled(vm.regeneratingAreaId != nil)

                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                }

                // ── Bottom confirm button ──────────────────────────────────────
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 12) {
                        Button {
                            vm.confirmAreas()
                        } label: {
                            HStack(spacing: 10) {
                                if vm.regeneratingAreaId != nil {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color(hex: "#FAEEDA"))
                                        .scaleEffect(0.8)
                                    Text("Regenerating area...")
                                        .font(.system(size: 16, weight: .medium))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("This is my Blueprint — let's go")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(vm.regeneratingAreaId != nil
                                ? Color(hex: "#412402").opacity(0.5)
                                : Color(hex: "#412402"))
                            .foregroundColor(Color(hex: "#FAEEDA"))
                            .cornerRadius(12)
                        }
                        .disabled(vm.regeneratingAreaId != nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
    }
}

// MARK: - Generation Source Summary

private struct GenerationSourceView: View {
    let canvas: Canvas?
    @State private var expanded = false

    private var likedPhotos: [PhotoInteraction] {
        (canvas?.photoInteractions ?? []).filter { $0.isLiked }
    }
    private var answers: [OnboardingAnswer] {
        (canvas?.onboardingAnswers ?? []).filter { !$0.answer.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#BA7517"))
                    Text("How your Blueprint was built")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#412402"))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().padding(.horizontal, 14)

                    // Liked photos
                    if !likedPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Photos you liked", systemImage: "heart.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#BA7517"))

                            FlowLayout(spacing: 6) {
                                ForEach(likedPhotos, id: \.photoName) { photo in
                                    Text(photoLabel(photo))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#412402"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#FAEEDA"))
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    // Q&A answers
                    if !answers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your answers", systemImage: "text.bubble.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#1D9E75"))

                            ForEach(answers.prefix(4), id: \.id) { answer in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(answer.question)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    Text("\"\(answer.answer)\"")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    Spacer().frame(height: 4)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(hex: "#FAEEDA").opacity(0.5))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#EF9F27").opacity(0.3), lineWidth: 1)
        )
    }

    private func photoLabel(_ photo: PhotoInteraction) -> String {
        // Convert "photo_travel" → "Travel", "photo_city" → "City" etc.
        photo.photoName
            .replacingOccurrences(of: "photo_", with: "")
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Simple Flow Layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Area Review Card

struct AreaReviewCard: View {
    let area: LifeArea
    let isRegenerating: Bool
    let onRegenerate: () -> Void

    @State private var showRationale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Card header ────────────────────────────────────────────────
            HStack(spacing: 10) {
                if isRegenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 36, height: 36)
                } else {
                    Text(area.emoji)
                        .font(.system(size: 28))
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRegenerating ? "Regenerating…" : area.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(area.areaDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Regenerate this area button
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#BA7517"))
                        .padding(8)
                        .background(Color(hex: "#FAEEDA"))
                        .clipShape(Circle())
                }
                .disabled(isRegenerating)
                .opacity(isRegenerating ? 0.4 : 1)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            // ── Vision ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("VISION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#BA7517"))
                    .tracking(1)
                Text(area.vision.isEmpty ? "Being generated…" : area.vision)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // ── Current reality ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("WHERE YOU ARE NOW")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#1D9E75"))
                    .tracking(1)
                Text(area.currentReality.isEmpty ? "Being generated…" : area.currentReality)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // ── Task count ─────────────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(area.tasks.count) growth tasks generated")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // ── Why this area (rationale) ──────────────────────────────────
            if !area.generationRationale.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showRationale.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#BA7517"))
                        Text(showRationale ? "Hide reasoning" : "Why this area?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BA7517"))
                        Spacer()
                        Image(systemName: showRationale ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#BA7517").opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if showRationale {
                    Text(area.generationRationale)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                Spacer().frame(height: 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .opacity(isRegenerating ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }
}

