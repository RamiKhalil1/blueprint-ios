import SwiftUI

// MARK: - Blueprint Design Tokens
// Single source of truth — import this everywhere instead of hardcoding hex strings

enum BPColor {
    // MARK: Amber ramp (primary brand)
    static let amber50  = Color(hex: "#FAEEDA")
    static let amber100 = Color(hex: "#FAC775")
    static let amber200 = Color(hex: "#EF9F27")
    static let amber400 = Color(hex: "#BA7517")
    static let amber600 = Color(hex: "#854F0B")
    static let amber800 = Color(hex: "#633806")
    static let amber900 = Color(hex: "#412402")

    // MARK: Teal (on-track)
    static let teal50   = Color(hex: "#E1F5EE")
    static let teal400  = Color(hex: "#1D9E75")
    static let teal600  = Color(hex: "#0F6E56")
    static let teal800  = Color(hex: "#085041")

    // MARK: Purple (drifting / work)
    static let purple50  = Color(hex: "#EEEDFE")
    static let purple400 = Color(hex: "#7F77DD")
    static let purple800 = Color(hex: "#3C3489")

    // MARK: Gray (neutral)
    static let gray50  = Color(hex: "#F1EFE8")
    static let gray200 = Color(hex: "#B4B2A9")
    static let gray400 = Color(hex: "#888780")
    static let gray800 = Color(hex: "#444441")

    // MARK: Green (completed)
    static let green50  = Color(hex: "#EAF3DE")
    static let green400 = Color(hex: "#639922")
    static let green800 = Color(hex: "#27500A")

    // MARK: Semantic
    static let onTrackBg   = green50
    static let onTrackText = Color(hex: "#27500A")
    static let driftingBg   = gray50
    static let driftingText = Color(hex: "#5F5E5A")
}

enum BPFont {
    // MARK: Display (logo / hero numbers)
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom("Georgia", size: size).weight(weight)
    }

    // MARK: Body (all UI text)
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Presets
    static let heroNumber  = display(40)
    static let title = body(22, weight: .medium)
    static let sectionHead = body(11, weight: .medium)
    static let cardTitle = body(15, weight: .medium)
    static let cardBody = body(14)
    static let caption = body(12)
    static let micro = body(11)
    static let tag = body(10, weight: .medium)
}

enum BPSpacing {
    static let screenH: CGFloat = 24
    static let sectionV: CGFloat = 20
    static let cardPad: CGFloat = 16
    static let itemGap: CGFloat = 12
    static let tinyGap: CGFloat = 6
}

enum BPRadius {
    static let card: CGFloat = 14
    static let button: CGFloat  = 12
    static let pill: CGFloat = 20
    static let tag: CGFloat = 8
}

// MARK: - Reusable view modifiers
extension View {
    func bpCard() -> some View {
        self
            .padding(BPSpacing.cardPad)
            .background(Color(.systemBackground))
            .cornerRadius(BPRadius.card)
    }

    func bpScreenPadding() -> some View {
        self.padding(.horizontal, BPSpacing.screenH)
    }

    func bpSectionLabel() -> some View {
        self
            .font(BPFont.sectionHead)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Shared UI components
struct BPPrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(BPColor.amber50)
                        .scaleEffect(0.8)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 14)) }
                    Text(title).font(BPFont.body(16, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isDisabled || isLoading ? Color.secondary : BPColor.amber900)
            .foregroundColor(BPColor.amber50)
            .cornerRadius(BPRadius.button)
        }
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

struct BPSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BPFont.body(15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BPColor.amber50)
                .foregroundColor(BPColor.amber800)
                .cornerRadius(BPRadius.button)
        }
    }
}

struct BPStatusPill: View {
    let status: LifeAreaStatus
    var body: some View {
        Text(status.displayName)
            .font(BPFont.tag)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(status == .onTrack ? BPColor.onTrackBg : BPColor.driftingBg)
            .foregroundColor(status == .onTrack ? BPColor.onTrackText : BPColor.driftingText)
            .cornerRadius(BPRadius.pill)
    }
}

struct BPProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * max(value, 0.03), height: 5)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 5)
    }
}

struct BPDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, BPSpacing.screenH)
            .padding(.vertical, BPSpacing.sectionV)
    }
}

struct BPSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .bpSectionLabel()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}
