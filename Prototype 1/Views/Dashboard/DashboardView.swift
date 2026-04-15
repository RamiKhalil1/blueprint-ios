import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = DashboardViewModel()
    @Query private var allWeeklyTasks: [WeeklyTaskItem]
    @State private var showIncomeIntent = false
    @State private var showEditCanvas   = false
    @State private var showWeeklyTasks  = false
    @State private var showCheckIn      = false

    private var thisWeekTasks: [WeeklyTaskItem] {
        let weekKey = WeeklyTaskItem.currentWeekKey()
        return allWeeklyTasks
            .filter { $0.weekKey == weekKey }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingTime())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Your canvas.")
                            .font(.custom("Georgia", size: 28))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    MonthlyCheckInBanner { showCheckIn = true }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    VStack(spacing: 12) {
                        ForEach(vm.lifeAreas) { area in
                            NavigationLink(destination: AreaDetailView(area: area, modelContext: modelContext)) {
                                AreaRowView(area: area)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24).padding(.vertical, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("This week")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#BA7517"))
                            Spacer()
                            if vm.allAreasComplete {
                                Button("See all") { showWeeklyTasks = true }
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)

                        if !vm.allAreasComplete {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#BA7517"))
                                    Text("Weekly tasks locked")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "#633806"))
                                }
                                Text("Fill in your vision and current reality for all areas to unlock your weekly tasks.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#854F0B"))
                                if !vm.incompleteAreas.isEmpty {
                                    Text("Missing: \(vm.incompleteAreas.joined(separator: ", "))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color(hex: "#FAEEDA"))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        } else if thisWeekTasks.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.85)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generating your weekly tasks...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Claude is personalising these for you")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        }

                        ForEach(thisWeekTasks.prefix(3)) { action in
                            HStack(spacing: 14) {
                                Button { vm.toggleTask(action) } label: {
                                    Circle()
                                        .strokeBorder(action.isDone ? Color(hex: "#1D9E75") : Color.secondary.opacity(0.3), lineWidth: 1.5)
                                        .background(Circle().fill(action.isDone ? Color(hex: "#1D9E75") : Color.clear))
                                        .frame(width: 22, height: 22)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title).font(.system(size: 14))
                                        .foregroundColor(action.isDone ? .secondary : .primary)
                                        .strikethrough(action.isDone)
                                    Text(action.areaType.displayName).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 24).padding(.vertical, 4)
                        }
                    }

                    Divider().padding(.horizontal, 24).padding(.vertical, 20)

                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            QuickTile(title: "Income intent", icon: "dollarsign.circle") { showIncomeIntent = true }
                            QuickTile(title: "Edit canvas",   icon: "square.and.pencil") { showEditCanvas = true }
                        }
                        QuickTile(title: "Monthly check-in", icon: "calendar", full: true) { showCheckIn = true }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 48)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(isPresented: $showWeeklyTasks) { WeeklyTasksView() }
            .navigationDestination(isPresented: $showIncomeIntent) { IncomeIntentView(modelContext: modelContext) }
            .navigationDestination(isPresented: $showEditCanvas)   { EditCanvasView(modelContext: modelContext) }
            .sheet(isPresented: $showCheckIn) { MonthlyCheckInView(modelContext: modelContext) }
        }
        .onAppear {
            vm.load(modelContext: modelContext)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                vm.generateTasksIfNeeded(modelContext: modelContext)
            }
        }
        .onChange(of: showEditCanvas) { _, isShowing in
            if !isShowing { vm.load(modelContext: modelContext) }
        }
        .onChange(of: showWeeklyTasks) { _, isShowing in
            if !isShowing { vm.load(modelContext: modelContext) }
        }
    }

    private func greetingTime() -> String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }
}

// MARK: - Supporting views
struct AreaRowView: View {
    let area: LifeArea
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(area.type.displayName).font(.system(size: 14)).foregroundColor(.primary)
                Spacer()
                StatusPillView(status: area.statusEnum)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(progressColor)
                        .frame(width: geo.size.width * max(area.progressScore, 0.03), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
    private var progressColor: Color {
        switch area.type {
        case .workTime: return Color(hex: "#7F77DD")
        case .finance:  return Color(hex: "#1D9E75")
        default:        return Color(hex: "#BA7517")
        }
    }
}

struct StatusPillView: View {
    let status: LifeAreaStatus
    var body: some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(status == .onTrack ? Color(hex: "#EAF3DE") : Color(hex: "#F1EFE8"))
            .foregroundColor(status == .onTrack ? Color(hex: "#27500A") : Color(hex: "#5F5E5A"))
            .cornerRadius(20)
    }
}

private struct QuickTile: View {
    let title: String; let icon: String; var full: Bool = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .medium))
                if full { Spacer() }
            }
            .frame(maxWidth: full ? .infinity : nil)
            .padding(.vertical, 13).padding(.horizontal, 16)
            .background(Color(hex: "#FAEEDA")).foregroundColor(Color(hex: "#633806")).cornerRadius(10)
        }
        .frame(maxWidth: full ? .infinity : nil)
    }
}

struct MonthlyCheckInBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill").font(.system(size: 13)).foregroundColor(Color(hex: "#BA7517"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(currentMonth()) story ready").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#633806"))
                    Text("Se what you built this month").font(.system(size: 12)).foregroundColor(Color(hex: "#854F0B"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "#BA7517"))
            }
            .padding(16)
            .background(Color(hex: "#FAEEDA"))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#EF9F27").opacity(0.4), lineWidth: 0.5))
        }
    }
    private func currentMonth() -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: .now)
    }
}
