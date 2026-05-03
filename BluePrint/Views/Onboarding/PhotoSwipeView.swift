import SwiftUI

struct PhotoSwipeView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var cardRotation: Double = 0

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: 6) {
                    Text("What draws you in?")
                        .font(.custom("Georgia", size: 26))
                        .foregroundColor(.primary)
                    Text("Swipe right to like, left to dislike")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 56)
                .padding(.bottom, 16)

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<onboardingPhotos.count, id: \.self) { i in
                        Circle()
                            .fill(i < vm.currentPhotoIndex
                                  ? Color(hex: "#BA7517")
                                  : Color.secondary.opacity(0.3))
                            .frame(
                                width: i == vm.currentPhotoIndex ? 8 : 5,
                                height: i == vm.currentPhotoIndex ? 8 : 5
                            )
                            .animation(.easeInOut, value: vm.currentPhotoIndex)
                    }
                }
                .padding(.bottom, 16)

                // Card stack
                ZStack {
                    // Next card preview
                    if vm.currentPhotoIndex + 1 < onboardingPhotos.count {
                        PhotoCard(photo: onboardingPhotos[vm.currentPhotoIndex + 1])
                            .scaleEffect(0.93)
                            .offset(y: 10)
                            .opacity(0.6)
                    }

                    // Current card
                    if let photo = vm.currentPhoto {
                        PhotoCard(photo: photo)
                            .offset(dragOffset)
                            .rotationEffect(.degrees(cardRotation))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                        cardRotation = Double(value.translation.width / 20)
                                    }
                                    .onEnded { value in
                                        let threshold: CGFloat = 100
                                        if value.translation.width > threshold {
                                            swipeRight()
                                        } else if value.translation.width < -threshold {
                                            swipeLeft()
                                        } else {
                                            withAnimation(.spring()) {
                                                dragOffset = .zero
                                                cardRotation = 0
                                            }
                                        }
                                    }
                            )
                            .overlay(
                                ZStack {
                                    // Like indicator
                                    if dragOffset.width > 30 {
                                        HStack {
                                            Text("❤️ Like")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Color.green.opacity(0.85))
                                                .cornerRadius(10)
                                                .opacity(Double(dragOffset.width - 30) / 70)
                                                .padding(20)
                                            Spacer()
                                        }
                                    }
                                    // Dislike indicator
                                    if dragOffset.width < -30 {
                                        HStack {
                                            Spacer()
                                            Text("✕ Dislike")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Color.red.opacity(0.85))
                                                .cornerRadius(10)
                                                .opacity(Double(-dragOffset.width - 30) / 70)
                                                .padding(20)
                                        }
                                    }
                                }
                            )
                    }

                    // All swiped
                    if vm.allPhotosSwiped {
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.1)
                            Text("Almost done...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .padding(.horizontal, 20)

                Spacer()

                // Action buttons
                if !vm.allPhotosSwiped {
                    VStack(spacing: 16) {
                        HStack(spacing: 48) {
                            // Dislike button
                            VStack(spacing: 6) {
                                Button { swipeLeft() } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemBackground))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: .black.opacity(0.1), radius: 8)
                                        Text("✕")
                                            .font(.system(size: 22))
                                    }
                                }
                                Text("Dislike")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            // Add custom photo
                            VStack(spacing: 6) {
                                Button { vm.showCustomPhotoSheet = true } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#FAEEDA"))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hex: "#BA7517"))
                                    }
                                }
                                Text("Add")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            // Like button
                            VStack(spacing: 6) {
                                Button { swipeRight() } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#BA7517"))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: Color(hex: "#BA7517").opacity(0.4), radius: 8)
                                        Text("❤️")
                                            .font(.system(size: 22))
                                    }
                                }
                                Text("Like")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .sheet(isPresented: $vm.showCustomPhotoSheet) {
            CustomPhotoSheet(vm: vm)
        }
    }

    private func swipeRight() {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: 500, height: 0)
            cardRotation = 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            vm.likePhoto()      // remove current card first
            dragOffset = .zero  // reset for the incoming card (no animation needed)
            cardRotation = 0
        }
    }

    private func swipeLeft() {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: -500, height: 0)
            cardRotation = -15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            vm.dislikePhoto()   // remove current card first
            dragOffset = .zero  // reset for the incoming card (no animation needed)
            cardRotation = 0
        }
    }
}

// MARK: - Photo Card
struct PhotoCard: View {
    let photo: OnboardingPhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let uiImage = UIImage(named: photo.assetName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 430)
                    .background(Color.black)
                    .clipped()
            } else {
                ZStack {
                    Color(hex: "#FAEEDA")
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#BA7517"))
                        Text(photo.assetName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 430)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 430)

            // Description at bottom
            Text(photo.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(3)
                .padding(16)
        }
        .frame(height: 430)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

// MARK: - Custom Photo Sheet
struct CustomPhotoSheet: View {
    @ObservedObject var vm: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var showPicker = false
    @State private var selectedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add your own photo")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Text("Add something that inspires you — a place, a person, a feeling.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                Button {
                    showPicker = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#FAEEDA"))
                            .frame(height: 200)

                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(16)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "#BA7517"))
                                Text("Tap to choose photo")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#BA7517"))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What does this mean to you?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Describe what this represents...", text: $caption, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    if let image = selectedImage,
                       let data = image.jpegData(compressionQuality: 0.7),
                       !caption.isEmpty {
                        vm.addCustomPhoto(imageData: data, caption: caption)
                        dismiss()
                    }
                } label: {
                    Text("Add to my board")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedImage != nil && !caption.isEmpty
                                    ? Color(hex: "#412402")
                                    : Color.secondary)
                        .foregroundColor(Color(hex: "#FAEEDA"))
                        .cornerRadius(12)
                }
                .disabled(selectedImage == nil || caption.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }
    }
}
