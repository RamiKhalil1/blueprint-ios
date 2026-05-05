import SwiftUI
import SwiftData

struct AreaDetailView: View {
    @StateObject private var vm: AreaDetailViewModel

    init(area: LifeArea, modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: AreaDetailViewModel(area: area, modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        BPStatusPill(status: vm.area.statusEnum)
                        Spacer()
                        Text("\(vm.progressPercent)%")
                            .font(BPFont.body(13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    BPProgressBar(value: vm.area.progressScore, color: vm.statusColor)
                }
                .bpCard()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Vision
                DetailCard(title: "Where you're going") {
                    if vm.area.vision.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Your vision is being generated...")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vm.area.vision)
                                .font(BPFont.cardBody)
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#BA7517"))
                                Text("Your destination — complete tasks to get here")
                                    .font(BPFont.micro)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                // Current reality
                DetailCard(title: "Where you are now") {
                    if vm.area.currentReality.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Your current reality is being generated...")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vm.area.currentReality)
                                .font(BPFont.cardBody)
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#1D9E75"))
                                Text("Updated \(vm.area.updatedAt.formatted(.relative(presentation: .named))) — evolves as you complete tasks")
                                    .font(BPFont.micro)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                // Blockers
                DetailCard(title: "What's blocking you") {
                    if vm.area.vision.isEmpty || vm.area.currentReality.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Add your vision and current reality first.")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if vm.isLoadingBlockers {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.85)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analysing your blockers...")
                                    .font(BPFont.body(13, weight: .medium))
                                Text("Claude is reading your vision and reality")
                                    .font(BPFont.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                    } else if vm.blockers.isEmpty {
                        Text("No blockers identified yet.")
                            .font(BPFont.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.blockers) { blocker in
                            HStack(spacing: 8) {
                                Text(blocker.type.label)
                                    .font(BPFont.tag)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(blocker.type.color)
                                    .foregroundColor(blocker.type.textColor)
                                    .cornerRadius(BPRadius.pill)
                                Text(blocker.text)
                                    .font(BPFont.cardBody)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                // Tasks
                DetailCard(title: "Your growth tasks") {
                    if vm.area.vision.isEmpty || vm.area.currentReality.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Add your vision and current reality first.")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if vm.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No tasks yet")
                                .font(BPFont.body(13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Tasks are generated when your Blueprint is built. Try regenerating your areas in settings.")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(vm.completedTaskCount) of \(vm.totalTaskCount) completed")
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                            BPProgressBar(
                                value: vm.totalTaskCount > 0
                                    ? Double(vm.completedTaskCount) / Double(vm.totalTaskCount)
                                    : 0,
                                color: Color(hex: "#1D9E75")
                            )
                        }
                        .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(vm.tasks) { task in
                                HStack(spacing: 12) {
                                    Button { vm.toggleTask(task) } label: {
                                        ZStack {
                                            Circle()
                                                .strokeBorder(
                                                    task.isDone ? BPColor.teal400 : Color.secondary.opacity(0.3),
                                                    lineWidth: 1.5
                                                )
                                            if task.isDone {
                                                Circle().fill(BPColor.teal400).padding(1.5)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .frame(width: 24, height: 24)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title)
                                            .font(BPFont.cardBody)
                                            .foregroundColor(task.isDone ? .secondary : .primary)
                                            .strikethrough(task.isDone)
                                        if let note = task.note, !task.isDone {
                                            Text(note)
                                                .font(BPFont.micro)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(task.blockerTypeEnum.label)
                                            .font(BPFont.tag)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(task.blockerTypeEnum.color)
                                            .foregroundColor(task.blockerTypeEnum.textColor)
                                            .cornerRadius(BPRadius.pill)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(vm.area.emoji) \(vm.area.name)")
        .navigationBarTitleDisplayMode(.large)
        .task {
            vm.syncProgress()
            guard !vm.area.vision.isEmpty && !vm.area.currentReality.isEmpty else { return }
            await vm.loadAIBlockers()
        }
    }
}

// MARK: - Detail Card wrapper
private struct DetailCard<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BPSectionLabel(text: title)
            content()
        }
        .bpCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
