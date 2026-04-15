import SwiftUI
import SwiftData

struct AreaDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: AreaDetailViewModel

    init(area: LifeArea, modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: AreaDetailViewModel(area: area, modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

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

                DetailCard(title: "Vision") {
                    if vm.isEditingVision {
                        TextField("What does this look like for you?", text: $vm.vision, axis: .vertical)
                            .lineLimit(3...8)
                            .font(BPFont.cardBody)
                            .padding(12)
                            .background(BPColor.amber50)
                            .cornerRadius(BPRadius.tag)

                        HStack {
                            Button("Cancel") { vm.isEditingVision = false }
                                .font(BPFont.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Save") { vm.saveVision() }
                                .font(BPFont.body(13, weight: .medium))
                                .foregroundColor(BPColor.amber400)
                        }
                    } else {
                        Text(vm.vision.isEmpty
                             ? "Tap to set your vision for \(vm.area.type.displayName.lowercased())..."
                             : vm.vision)
                            .font(BPFont.cardBody)
                            .foregroundColor(vm.vision.isEmpty ? .secondary : .primary)
                            .lineSpacing(3)

                        Button("Edit vision →") { vm.isEditingVision = true }
                            .font(BPFont.caption)
                            .foregroundColor(BPColor.amber400)
                            .padding(.top, 4)
                    }
                }

                DetailCard(title: "Current reality") {
                    TextField("What's actually happening right now?", text: $vm.currentReality, axis: .vertical)
                        .lineLimit(3...8)
                        .font(BPFont.cardBody)
                        .onSubmit { vm.saveReality() }
                        .onChange(of: vm.currentReality) { _, _ in vm.saveReality() }

                    Text("Updated \(vm.area.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(BPFont.micro)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
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
                                    .foregroundColor(.primary)
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

                // Actions
                DetailCard(title: "Actions for this area") {
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
                    } else if vm.isLoadingActions {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.85)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generating your actions...")
                                    .font(BPFont.body(13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Claude is personalising these for you")
                                    .font(BPFont.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                    } else if vm.actions.isEmpty {
                        Text("No actions generated yet.")
                            .font(BPFont.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.actions) { action in
                            HStack(spacing: 12) {
                                Button { vm.toggleAction(action) } label: {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(
                                                action.isDone ? BPColor.teal400 : Color.secondary.opacity(0.3),
                                                lineWidth: 1.5
                                            )
                                        if action.isDone {
                                            Circle().fill(BPColor.teal400).padding(1.5)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                }

                                Text(action.title)
                                    .font(BPFont.cardBody)
                                    .foregroundColor(action.isDone ? .secondary : .primary)
                                    .strikethrough(action.isDone)

                                Spacer()
                            }
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vm.area.type.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !vm.area.vision.isEmpty && !vm.area.currentReality.isEmpty else { return }
            async let blockers: () = vm.loadAIBlockers()
            async let actions: () = vm.loadAIActions()
            await blockers
            await actions
        }
        .onChange(of: vm.area.vision) { _, _ in
            guard !vm.area.vision.isEmpty && !vm.area.currentReality.isEmpty else { return }
            guard vm.blockers.isEmpty && vm.actions.isEmpty else { return }
            Task {
                async let blockers: () = vm.loadAIBlockers()
                async let actions: () = vm.loadAIActions()
                await blockers
                await actions
            }
        }
        .onChange(of: vm.area.currentReality) { _, _ in
            guard !vm.area.vision.isEmpty && !vm.area.currentReality.isEmpty else { return }
            guard vm.blockers.isEmpty && vm.actions.isEmpty else { return }
            Task {
                async let blockers: () = vm.loadAIBlockers()
                async let actions: () = vm.loadAIActions()
                await blockers
                await actions
            }
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
