import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = DashboardViewModel()
    @State private var showEditCanvas    = false
    @State private var showCheckIn      = false

    @State private var showVisionBoard   = false
    @State private var showClaudeCheckIn = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Hero Header
                    HeroHeaderView(
                        greeting: greetingTime(),
                        growthScore: vm.overallGrowthScore,
                        weeks: vm.journeyWeeks,
                        areas: vm.lifeAreas
                    )
                    .padding(.bottom, 20)

                    // MARK: - Monthly Check-in Banner
                    MonthlyCheckInBanner { showCheckIn = true }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: - Overall Growth Ring
                    OverallGrowthRing(lifeAreas: vm.lifeAreas, growthScore: vm.overallGrowthScore)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: - Life Areas
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your life areas")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(vm.lifeAreas.filter { $0.statusEnum == .onTrack }.count) growing")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#1D9E75"))
                        }
                        .padding(.horizontal, 20)

                        ForEach(vm.lifeAreas) { area in
                            NavigationLink(destination: AreaDetailView(area: area, modelContext: modelContext)) {
                                RichAreaCard(area: area)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 24)

                    // MARK: - Quick Actions
                    HStack(spacing: 12) {
                        ActionTile(
                            title: "Edit canvas",
                            subtitle: "Update your areas",
                            icon: "square.and.pencil",
                            color: Color(hex: "#FAEEDA"),
                            textColor: Color(hex: "#633806")
                        ) { showEditCanvas = true }

                        ActionTile(
                            title: "Monthly check-in",
                            subtitle: "Reflect on this month",
                            icon: "calendar.badge.checkmark",
                            color: Color(hex: "#412402"),
                            textColor: Color(hex: "#FAC775")
                        ) { showCheckIn = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    HStack(spacing: 12) {
                        ActionTile(
                            title: "Vision board",
                            subtitle: "Your photos & visions",
                            icon: "photo.stack.fill",
                            color: Color(hex: "#EEEDFE"),
                            textColor: Color(hex: "#3C3489")
                        ) { showVisionBoard = true }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)  // extra room for the FAB
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showEditCanvas)   { EditCanvasView(modelContext: modelContext) }
            .navigationDestination(isPresented: $showVisionBoard)   { VisionBoardView() }
            .sheet(isPresented: $showCheckIn) { MonthlyCheckInView(modelContext: modelContext) }
            .sheet(isPresented: $showClaudeCheckIn) {
                ClaudeCheckInView(modelContext: modelContext)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ClaudeFAB { showClaudeCheckIn = true }
        }
        .onAppear { vm.load(modelContext: modelContext) }
        .onChange(of: showEditCanvas) { _, isShowing in
            if !isShowing { vm.load(modelContext: modelContext) }
        }
    }

    private func greetingTime() -> String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }
}

// MARK: - Hero Header
struct HeroHeaderView: View {
    let greeting: String
    let growthScore: Int
    let weeks: Int
    let areas: [LifeArea]
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#412402"), Color(hex: "#2A1701")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            // Decorative circles
            ZStack {
                Circle()
                    .fill(Color(hex: "#BA7517").opacity(0.08))
                    .frame(width: 200, height: 200)
                    .offset(x: 120, y: -40)
                Circle()
                    .fill(Color(hex: "#BA7517").opacity(0.05))
                    .frame(width: 120, height: 120)
                    .offset(x: 160, y: 20)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Greeting
                Text(greeting)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#BA7517"))
                    .padding(.bottom, 6)
                    .opacity(appeared ? 1 : 0)

                Text("Your canvas.")
                    .font(.custom("Georgia", size: 32))
                    .foregroundColor(Color(hex: "#FAC775"))
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                // Stats row
                HStack(spacing: 16) {
                    HeroStat(value: "\(growthScore)%", label: "overall growth")
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 28)
                    HeroStat(value: "Week \(weeks)", label: "of your journey")
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 28)
                    HeroStat(
                        value: "\(areas.filter { $0.statusEnum == .onTrack }.count)/\(areas.count)",
                        label: "areas growing"
                    )
                }
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }
}

private struct HeroStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#FAC775"))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#BA7517"))
        }
    }
}

// MARK: - Overall Growth Ring
struct OverallGrowthRing: View {
    let lifeAreas: [LifeArea]
    let growthScore: Int
    @State private var animated = false

    var body: some View {
        HStack(spacing: 20) {
            // Multi-ring chart
            ZStack {
                ForEach(Array(lifeAreas.prefix(5).enumerated()), id: \.offset) { i, area in
                    let size = CGFloat(90 - i * 16)
                    let progress = max(area.progressScore, 0.02)

                    Circle()
                        .stroke(Color(hex: "#BA7517").opacity(0.08), lineWidth: 5)
                        .frame(width: size, height: size)

                    Circle()
                        .trim(from: 0, to: animated ? progress : 0)
                        .stroke(
                            ringColor(for: i),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.1), value: animated)
                }

                Text("\(growthScore)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#412402"))
            }
            .frame(width: 100, height: 100)

            // Legend
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lifeAreas.prefix(5).enumerated()), id: \.offset) { i, area in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ringColor(for: i))
                            .frame(width: 8, height: 8)
                        Text(area.emoji + " " + area.name)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(area.progressScore * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .onAppear { animated = true }
    }

    private func ringColor(for index: Int) -> Color {
        let colors = ["#BA7517", "#1D9E75", "#7F77DD", "#E05C2A", "#2A7FAA"]
        return Color(hex: colors[index % colors.count])
    }
}

// MARK: - Rich Area Card
struct RichAreaCard: View {
    let area: LifeArea
    @State private var barAnimated = false

    var completedTasks: Int { area.tasks.filter { $0.isDone }.count }
    var totalTasks: Int { area.tasks.count }

    var body: some View {
        VStack(spacing: 0) {
            // Top section
            HStack(alignment: .top, spacing: 12) {
                // Emoji in circle
                ZStack {
                    Circle()
                        .fill(Color(hex: "#FAEEDA"))
                        .frame(width: 44, height: 44)
                    Text(area.emoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(area.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        StatusPillView(status: area.statusEnum)
                    }

                    Text(area.vision.isEmpty ? "Set your vision to get started" : area.vision)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            // Bottom section — progress
            HStack(spacing: 16) {
                // Progress bar
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#BA7517"), Color(hex: "#EF9F27")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: barAnimated
                                        ? geo.size.width * max(area.progressScore, 0.02)
                                        : 0,
                                    height: 8
                                )
                                .animation(.easeOut(duration: 0.7), value: barAnimated)
                        }
                    }
                    .frame(height: 8)

                    Text(growthLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Task count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completedTasks)/\(totalTasks)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#BA7517"))
                    Text("tasks")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .onAppear { barAnimated = true }
    }

    private var growthLabel: String {
        let percent = Int(area.progressScore * 100)
        if area.vision.isEmpty { return "Set your vision to start" }
        if percent == 0 { return "Ready to grow" }
        if percent < 25 { return "Just getting started · \(percent)%" }
        if percent < 50 { return "Building momentum · \(percent)%" }
        if percent < 75 { return "Making real progress · \(percent)%" }
        if percent < 100 { return "Almost there · \(percent)%" }
        return "Vision achieved 🎉"
    }
}

// MARK: - Action Tile
private struct ActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(textColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textColor)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.6))
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(14)
        }
    }
}

// MARK: - Monthly Check-in Banner
struct MonthlyCheckInBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BA7517").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(currentMonth()) story ready")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#412402"))
                    Text("Tap to see what you built this month")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#854F0B"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#BA7517"))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FAEEDA"), Color(hex: "#F5DDB8")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#EF9F27").opacity(0.3), lineWidth: 1)
            )
        }
    }
    private func currentMonth() -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: .now)
    }
}

// MARK: - Status Pill
struct StatusPillView: View {
    let status: LifeAreaStatus
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(status.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(bgColor)
        .cornerRadius(20)
    }
    private var dotColor: Color {
        switch status {
        case .onTrack:    return Color(hex: "#1D9E75")
        case .drifting:   return Color(hex: "#BA7517")
        case .notStarted: return Color.secondary
        }
    }
    private var textColor: Color {
        switch status {
        case .onTrack:    return Color(hex: "#27500A")
        case .drifting:   return Color(hex: "#633806")
        case .notStarted: return Color.secondary
        }
    }
    private var bgColor: Color {
        switch status {
        case .onTrack:    return Color(hex: "#EAF3DE")
        case .drifting:   return Color(hex: "#FAEEDA")
        case .notStarted: return Color(.systemGray6)
        }
    }
}

// MARK: - Claude Floating Action Button

private struct ClaudeFAB: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(Color(hex: "#BA7517").opacity(0.18))
                    .frame(width: 64, height: 64)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#BA7517"), Color(hex: "#E8950A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: Color(hex: "#BA7517").opacity(0.45), radius: 12, y: 4)

                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isPressed)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 24)
        .padding(.bottom, 36)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
