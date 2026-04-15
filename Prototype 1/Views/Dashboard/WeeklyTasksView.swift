import SwiftUI
import SwiftData

struct WeeklyTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = WeeklyTasksViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(vm.completedCount) of \(vm.totalCount) done")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        if vm.isLoadingAI {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Personalising...").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        } else {
                            Button { vm.refreshWithAI() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#BA7517"))
                            }
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#1D9E75"))
                                .frame(
                                    width: vm.totalCount > 0
                                        ? geo.size.width * Double(vm.completedCount) / Double(vm.totalCount)
                                        : 0,
                                    height: 5
                                )
                                .animation(.easeInOut, value: vm.completedCount)
                        }
                    }
                    .frame(height: 5)

                    Text("Week of \(vm.weekLabel)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

                if let error = vm.aiError {
                    Text(error).font(.system(size: 12)).foregroundColor(.secondary)
                        .padding(.horizontal, 24).padding(.bottom, 12)
                }

                VStack(spacing: 10) {
                    ForEach(vm.tasks) { task in
                        TaskCard(
                            task: task,
                            onToggle: { vm.toggleTask(task) },
                            onSwap:   { vm.requestSwap(for: task) },
                            onSkip:   { vm.skipTask(task) }
                        )
                    }
                }
                .padding(.horizontal, 16)

                Text("Swap or skip — the app adapts to you.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)

                Spacer().frame(height: 48)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly tasks")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.load(modelContext: modelContext) }
        .sheet(isPresented: $vm.showSwapSheet) {
            if let t = vm.taskToSwap {
                SwapSheet(
                    options: vm.swapOptions,
                    isLoading: vm.isLoadingSwap
                ) { vm.confirmSwap(replacing: t, with: $0) }
            }
        }
    }
}

private struct TaskCard: View {
    let task: WeeklyTaskItem
    let onToggle: () -> Void
    let onSwap: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isDone ? Color(hex: "#1D9E75") : Color.secondary.opacity(0.3), lineWidth: 1.5)
                    if task.isDone {
                        Circle().fill(Color(hex: "#1D9E75")).padding(1.5)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 15))
                    .foregroundColor(task.isDone || task.isSkipped ? .secondary : .primary)
                    .strikethrough(task.isDone)

                if let note = task.note, !task.isDone, !task.isSkipped {
                    Text(note).font(.system(size: 12)).foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Text(task.areaType.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color(hex: "#FAEEDA")).foregroundColor(Color(hex: "#633806"))
                        .cornerRadius(20)

                    if !task.isDone && !task.isSkipped {
                        Button("Swap") { onSwap() }.font(.system(size: 11)).foregroundColor(.secondary)
                        Button("Skip") { onSkip() }.font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if task.isSkipped {
                        Text("Skipped").font(.system(size: 11)).foregroundColor(.secondary).italic()
                    }
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .opacity(task.isSkipped ? 0.5 : 1)
    }
}

private struct SwapSheet: View {
    let options: [WeeklyTaskItem]
    let isLoading: Bool
    let onSelect: (WeeklyTaskItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.1)
                        Text("Finding better options for you...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Claude is generating personalised alternatives")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if options.isEmpty {
                    Text("No options available.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(options) { option in
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    if let note = option.note {
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Text(option.areaType.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Color(hex: "#FAEEDA"))
                                        .foregroundColor(Color(hex: "#633806"))
                                        .cornerRadius(20)
                                        .padding(.top, 2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                        }
                        Divider().padding(.leading, 20)
                    }
                }
                Spacer()
            }
            .navigationTitle("Swap task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
