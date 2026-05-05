import SwiftUI

struct SplashView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var logoOpacity:   Double = 0
    @State private var taglineOffset: Double = 20
    @State private var guideOpacity:  Double = 0
    @State private var ctaOpacity:    Double = 0

    var body: some View {
        ZStack {
            BPColor.amber900.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Logo ─────────────────────────────────────────────────
                    Spacer().frame(height: 64)

                    Text("BLUePRiNT")
                        .font(BPFont.display(38, weight: .light))
                        .tracking(5)
                        .foregroundColor(BPColor.amber100)
                        .opacity(logoOpacity)

                    Spacer().frame(height: 14)

                    Text("\"I don't wait for opportunities.\nI manifest them into existence.\"")
                        .font(BPFont.body(14, weight: .light))
                        .italic()
                        .foregroundColor(BPColor.amber400)
                        .lineSpacing(5)
                        .offset(y: taglineOffset)
                        .opacity(logoOpacity)

                    // ── How it works ─────────────────────────────────────────
                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(text: "HOW IT WORKS")

                        TabView {
                            ForEach(AppGuideStep.allSteps) { step in
                                GuideStepCard(step: step)
                                    .padding(.horizontal, 2)
                                    .padding(.bottom, 28)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 170)
                        .onAppear {
                            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(BPColor.amber200)
                            UIPageControl.appearance().pageIndicatorTintColor        = UIColor(BPColor.amber800)
                        }
                    }
                    .opacity(guideOpacity)

                    // ── What you'll get ───────────────────────────────────────
                    Spacer().frame(height: 28)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "WHAT YOU GET")

                        VStack(spacing: 10) {
                            FeaturePill(icon: "map.fill",         color: BPColor.amber200,  text: "5 personalised life areas built by Claude")
                            FeaturePill(icon: "checklist",        color: BPColor.teal400,   text: "20 growth tasks per area, tailored to you")
                            FeaturePill(icon: "photo.stack.fill", color: Color(hex: "#7F77DD"), text: "A vision board built from your photo choices")
                            FeaturePill(icon: "bubble.left.fill", color: BPColor.amber100,  text: "Monthly Claude check-ins to keep you on track")
                        }
                    }
                    .opacity(guideOpacity)

                    // ── CTA ───────────────────────────────────────────────────
                    Spacer().frame(height: 36)

                    VStack(spacing: 10) {
                        BPPrimaryButton("Start my canvas") { vm.advance() }

                        Text("No account needed · Takes about 5 minutes")
                            .font(BPFont.caption)
                            .foregroundColor(BPColor.amber800)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .opacity(ctaOpacity)

                    Spacer().frame(height: 52)
                }
                .padding(.horizontal, 28)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7))             { logoOpacity   = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { taglineOffset  = 0 }
            withAnimation(.easeOut(duration: 0.6).delay(0.4))  { guideOpacity   = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.75)) { ctaOpacity     = 1 }
        }
    }
}

// MARK: - Section Label

private struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(BPColor.amber400)
                .frame(width: 18, height: 1)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(BPColor.amber400)
        }
    }
}

// MARK: - App Guide Step Model

struct AppGuideStep: Identifiable {
    let id = UUID()
    let number:      String
    let icon:        String
    let iconColor:   Color
    let title:       String
    let description: String

    static let allSteps: [AppGuideStep] = [
        AppGuideStep(
            number: "01",
            icon: "photo.stack.fill",
            iconColor: BPColor.amber200,
            title: "Swipe through photos",
            description: "Like or skip curated photos. What you're drawn to reveals what you truly want from life — more honestly than any questionnaire."
        ),
        AppGuideStep(
            number: "02",
            icon: "bubble.left.and.bubble.right.fill",
            iconColor: BPColor.teal400,
            title: "Answer two questions",
            description: "For each photo you interact with, Claude asks two short follow-up questions to understand the values and desires behind your choices."
        ),
        AppGuideStep(
            number: "03",
            icon: "sparkles",
            iconColor: Color(hex: "#7F77DD"),
            title: "Claude builds your Blueprint",
            description: "Claude analyses your signals and generates 5 personalised life areas — each with a vision, your current reality, and 20 growth tasks built just for you."
        ),
        AppGuideStep(
            number: "04",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: BPColor.teal400,
            title: "Grow every day",
            description: "Complete tasks, check in monthly with Claude, and watch your life take shape. Your Blueprint evolves as you do."
        )
    ]
}

// MARK: - Guide Step Card

private struct GuideStepCard: View {
    let step: AppGuideStep

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Icon
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(step.iconColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(step.number)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(step.iconColor.opacity(0.75))
                    Text(step.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BPColor.amber100)
                }
                Text(step.description)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(BPColor.amber400)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(BPColor.amber800.opacity(0.7), lineWidth: 1)
        )
    }
}

// MARK: - Feature Pill

private struct FeaturePill: View {
    let icon:  String
    let color: Color
    let text:  String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(BPColor.amber100.opacity(0.75))
        }
    }
}
