import SwiftUI
import SwiftData

struct EditCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: EditCanvasViewModel

    init(modelContext: ModelContext) {
        _vm = StateObject(wrappedValue: EditCanvasViewModel(modelContext: modelContext))
    }

    var body: some View {
        List {
            Section {
                ForEach(vm.lifeAreas) { area in
                    AreaEditRow(area: area) { vm.startEditing(area) }
                }
                .onMove { vm.moveArea(from: $0, to: $1) }
            } header: {
                Text("Drag to reprioritise")
                    .font(BPFont.caption)
                    .foregroundColor(.secondary)
            } footer: {
                Text("Update your canvas as your life evolves. There's no wrong answer.")
                    .font(BPFont.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Edit canvas")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $vm.editingArea) { area in
            EditVisionSheet(
                areaName: area.type.displayName,
                vision: $vm.draftVision,
                onSave: { vm.saveEdit() },
                onCancel: { vm.cancelEdit() }
            )
        }
        .onAppear { vm.load() }
    }
}

private struct AreaEditRow: View {
    let area: LifeArea
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(area.type.displayName)
                    .font(BPFont.body(15, weight: .medium))
                Spacer()
                Button("Edit →", action: onEdit)
                    .font(BPFont.caption)
                    .foregroundColor(BPColor.amber400)
            }
            Text(area.vision.isEmpty ? "No vision set yet." : area.vision)
                .font(BPFont.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct EditVisionSheet: View {
    let areaName: String
    @Binding var vision: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What does \(areaName.lowercased()) look like in your ideal life?")
                    .font(BPFont.cardBody)
                    .foregroundColor(.secondary)

                TextField("Write freely...", text: $vision, axis: .vertical)
                    .lineLimit(5...12)
                    .font(BPFont.body(16))
                    .padding(14)
                    .background(BPColor.amber50)
                    .cornerRadius(BPRadius.tag)
                    .focused($focused)

                Spacer()
            }
            .padding(24)
            .navigationTitle(areaName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .font(BPFont.body(15, weight: .medium))
                        .foregroundColor(BPColor.amber400)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
