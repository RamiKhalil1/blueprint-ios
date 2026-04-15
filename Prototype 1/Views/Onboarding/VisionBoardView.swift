import SwiftUI
import PhotosUI

struct VisionBoardView: View {
    @ObservedObject var vm: OnboardingViewModel

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showCaptionSheet = false
    @State private var pendingImageData: Data? = nil
    @State private var captionText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            Color(hex: "#FAEEDA").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add what inspires you.")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#854F0B"))

                    Text("Photos, places, people, quotes. Anything.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#BA7517"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 24)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(vm.visionItems) { item in
                            VisionCellView(item: item)
                        }

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                            AddCellView()
                        }

                        Button {
                            pendingImageData = nil
                            showCaptionSheet = true
                        } label: {
                            AddCellView(label: "Add text")
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button { vm.advance() } label: {
                        Text("Done, ask me about this")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#412402"))
                            .foregroundColor(Color(hex: "#FAEEDA"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onChange(of: selectedItems) { _, items in
            Task {
                if let item = items.first,
                   let data = try? await item.loadTransferable(type: Data.self) {
                    pendingImageData = data
                    showCaptionSheet = true
                }
                selectedItems = []
            }
        }
        .sheet(isPresented: $showCaptionSheet) {
            CaptionSheet(captionText: $captionText) { caption in
                vm.addVisionItem(caption: caption, imageData: pendingImageData)
                captionText = ""
                pendingImageData = nil
            }
        }
    }
}

// MARK: - Vision Cell
private struct VisionCellView: View {
    let item: VisionItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(hex: "#FAC775")
                }
            }
            .frame(height: 110)
            .clipped()
            .cornerRadius(10)

            if !item.caption.isEmpty {
                Text(item.caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#633806"))
                    .padding(6)
            }
        }
    }
}

// MARK: - Add Cell
private struct AddCellView: View {
    var label: String = "Add photo"

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Color(hex: "#BA7517").opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(Color.black.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Caption Sheet
private struct CaptionSheet: View {
    @Binding var captionText: String
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a caption")
                    .font(.system(size: 18, weight: .medium))

                TextField("What does this mean to you?", text: $captionText, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color(hex: "#FAEEDA"))
                    .cornerRadius(10)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(captionText)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
