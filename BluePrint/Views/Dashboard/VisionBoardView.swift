import SwiftUI
import SwiftData

// MARK: - Vision Board

struct VisionBoardView: View {
    @Query private var canvases: [Canvas]
    @State private var selectedPhotoIndex: Int? = nil
    @State private var selectedAreaIndex:  Int? = nil
    @State private var appeared = false

    private var canvas: Canvas? { canvases.first }

    private var likedPhotos: [PhotoInteraction] {
        var seen = Set<String>()
        return (canvas?.photoInteractions ?? [])
            .filter { $0.isLiked }
            .sorted { $0.sortIndex < $1.sortIndex }
            .filter { seen.insert($0.photoName).inserted }
    }

    private var lifeAreas: [LifeArea] {
        (canvas?.lifeAreas ?? []).sorted { $0.priorityRank < $1.priorityRank }
    }

    /// Assigns every liked photo to the life area whose name/description
    /// best matches the photo's description. Unmatched photos are spread
    /// evenly so the area with the fewest photos absorbs the next one.
    private var photoAreaMap: [UUID: [PhotoInteraction]] {
        guard !lifeAreas.isEmpty else { return [:] }

        var map: [UUID: [PhotoInteraction]] = Dictionary(
            uniqueKeysWithValues: lifeAreas.map { ($0.id, [PhotoInteraction]()) }
        )
        var counts: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: lifeAreas.map { ($0.id, 0) }
        )

        for photo in likedPhotos {
            // Use both the stored description AND the asset name (e.g. "photo_social" → "social")
            // so existing records with mismatched descriptions still match sensibly.
            let nameHint = photo.photoName
                .replacingOccurrences(of: "photo_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            let desc = (photo.photoDescription + " " + nameHint).lowercased()
            var bestId: UUID? = nil
            var bestScore = 0

            for area in lifeAreas {
                let keywords = (area.name + " " + area.areaDescription)
                    .lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count > 3 }
                let score = keywords.filter { desc.contains($0) }.count
                if score > bestScore {
                    bestScore = score
                    bestId = area.id
                }
            }

            // Distribute unmatched photos to the area with fewest photos
            let assignId: UUID? = bestId ?? lifeAreas
                .min(by: { (counts[$0.id] ?? 0) < (counts[$1.id] ?? 0) })?.id

            if let id = assignId {
                map[id, default: []].append(photo)
                counts[id, default: 0] += 1
            }
        }
        return map
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("How your photos build your life.")
                        .font(.custom("Georgia", size: 22))
                        .foregroundColor(Color(hex: "#FAC775"))
                    Text("Each photo you liked shapes a vision. Here's how.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: appeared)

                if likedPhotos.isEmpty {
                    emptyState
                } else {
                    // One section per life area
                    ForEach(Array(lifeAreas.enumerated()), id: \.offset) { i, area in
                        let areaPhotos = photoAreaMap[area.id] ?? []
                        let pct = likedPhotos.isEmpty ? 0.0
                            : Double(areaPhotos.count) / Double(likedPhotos.count)

                        AreaPhotoSection(
                            area: area,
                            photos: areaPhotos,
                            photoPercentage: pct,
                            totalPhotos: likedPhotos.count,
                            onAreaTap: { selectedAreaIndex = i },
                            onPhotoTap: { photo in
                                if let idx = likedPhotos.firstIndex(where: {
                                    $0.photoName == photo.photoName
                                }) {
                                    selectedPhotoIndex = idx
                                }
                            }
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(
                            .easeOut(duration: 0.4).delay(0.08 + Double(i) * 0.07),
                            value: appeared
                        )

                        if i < lifeAreas.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.07))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                    }
                }

                Spacer().frame(height: 60)
            }
        }
        .background(Color(hex: "#120D05").ignoresSafeArea())
        .navigationTitle("Vision Board")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color(hex: "#120D05"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { withAnimation { appeared = true } }
        .sheet(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let idx = selectedPhotoIndex {
                PhotoDetailSheet(photos: likedPhotos, startIndex: idx, areas: lifeAreas)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedAreaIndex != nil },
            set: { if !$0 { selectedAreaIndex = nil } }
        )) {
            if let idx = selectedAreaIndex, idx < lifeAreas.count {
                let area = lifeAreas[idx]
                AreaVisionFullScreen(
                    area: area,
                    backgroundPhoto: (photoAreaMap[area.id] ?? []).first
                )
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.18))
            Text("No liked photos yet")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.32))
            Text("Swipe through photos during onboarding to fill your vision board.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Area Photo Section
private struct AreaPhotoSection: View {
    let area:            LifeArea
    let photos:          [PhotoInteraction]
    let photoPercentage: Double   // this area's share of all liked photos
    let totalPhotos:     Int
    let onAreaTap:       () -> Void
    let onPhotoTap:      (PhotoInteraction) -> Void

    @State private var barAppeared = false

    private var photoCountLabel: String {
        "\(photos.count) photo\(photos.count == 1 ? "" : "s")"
    }

    private var contributionLabel: String {
        let pct = Int((photoPercentage * 100).rounded())
        return "\(pct)% of your vision board"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Area header
            HStack(alignment: .center, spacing: 12) {
                Text(area.emoji)
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 3) {
                    Text(area.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Text(photoCountLabel)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#BA7517"))
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                        Text(contributionLabel)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#BA7517").opacity(0.55))
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture { onAreaTap() }

            // Contribution bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#BA7517"), Color(hex: "#E8950A")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width: barAppeared
                                ? max(geo.size.width * photoPercentage, photos.isEmpty ? 0 : 6)
                                : 0,
                            height: 3
                        )
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: barAppeared)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .onAppear { barAppeared = true }

            // Photo strip
            if photos.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.18))
                    Text("No photos assigned to this area yet")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.22))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos, id: \.photoName) { photo in
                            VBPhotoTile(photo: photo)
                                .onTapGesture { onPhotoTap(photo) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Vision Board Photo Tile (horizontal strip)

private struct VBPhotoTile: View {
    let photo: PhotoInteraction
    private let size: CGFloat = 118

    var body: some View {
        Group {
            if photo.isCustom, let data = photo.imageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let img = UIImage(named: photo.photoName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(hex: "#2A1701")
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#BA7517").opacity(0.4))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let photos: [PhotoInteraction]
    let areas:  [LifeArea]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    private var photoHeight: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.height ?? 800) * 0.54
    }

    init(photos: [PhotoInteraction], startIndex: Int, areas: [LifeArea]) {
        self.photos = photos
        self.areas  = areas
        _currentIndex = State(initialValue: min(startIndex, max(0, photos.count - 1)))
    }

    private var photo: PhotoInteraction { photos[currentIndex] }

    var body: some View {
        VStack(spacing: 0) {

            // Photo
            ZStack(alignment: .top) {
                photoView(photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: photoHeight)
                    .clipped()

                HStack(alignment: .center) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                currentIndex = max(0, currentIndex - 1)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(currentIndex == 0)
                        .opacity(currentIndex == 0 ? 0.3 : 1)

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                currentIndex = min(photos.count - 1, currentIndex + 1)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(currentIndex == photos.count - 1)
                        .opacity(currentIndex == photos.count - 1 ? 0.3 : 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }

            // Visions Panel
            VisionsPanel(areas: areas)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func photoView(_ photo: PhotoInteraction) -> some View {
        if photo.isCustom, let data = photo.imageData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else if let img = UIImage(named: photo.photoName) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Color(hex: "#1A1208")
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#BA7517").opacity(0.4))
                )
        }
    }
}

// MARK: - Visions Panel (used inside PhotoDetailSheet)

private struct VisionsPanel: View {
    let areas: [LifeArea]
    private let w = UIScreen.main.bounds.width

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR VISIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "#BA7517"))
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ForEach(Array(areas.enumerated()), id: \.offset) { i, area in
                    HStack(alignment: .top, spacing: 10) {
                        Text(area.emoji)
                            .font(.system(size: 18))
                            .frame(width: 28, alignment: .center)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(area.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(area.vision.isEmpty ? "Vision not set" : area.vision)
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(Int(area.progressScore * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BA7517"))
                            .fixedSize()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(width: w, alignment: .leading)

                    if i < areas.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.07))
                            .padding(.leading, 58)
                            .frame(width: w)
                    }
                }
                Spacer().frame(height: 32)
            }
            .frame(width: w, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#1A1208"))
    }
}

// MARK: - Area Vision Full Screen

private struct AreaVisionFullScreen: View {
    let area:            LifeArea
    let backgroundPhoto: PhotoInteraction?
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)

            Spacer()

            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text(area.emoji)
                        .font(.system(size: 52))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.4), value: appeared)

                    Text(area.name)
                        .font(.custom("Georgia", size: 32))
                        .foregroundColor(Color(hex: "#FAC775"))
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)
                }

                Divider().background(Color.white.opacity(0.15))

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHERE YOU'RE GOING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "#BA7517"))

                    Text(area.vision.isEmpty ? "Open Edit Canvas to set your vision." : area.vision)
                        .font(.system(size: 17, weight: .light))
                        .foregroundColor(.white.opacity(0.88))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                }

                if !area.currentReality.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHERE YOU ARE NOW")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Color(hex: "#1D9E75"))

                        Text(area.currentReality)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.58))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PROGRESS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                        Text("\(Int(area.progressScore * 100))%  ·  \(area.completedTaskCount)/\(area.totalTaskCount) tasks")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BA7517"))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#BA7517"))
                                .frame(
                                    width: appeared
                                        ? geo.size.width * max(area.progressScore, 0.03)
                                        : 0,
                                    height: 4
                                )
                                .animation(.easeOut(duration: 0.9).delay(0.3), value: appeared)
                        }
                    }
                    .frame(height: 4)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Group {
                if let photo = backgroundPhoto {
                    blurredPhoto(photo)
                } else {
                    Color(hex: "#412402")
                }
            }
            .overlay(Color.black.opacity(0.55))
            .ignoresSafeArea()
        }
        .onAppear { withAnimation { appeared = true } }
    }

    @ViewBuilder
    private func blurredPhoto(_ photo: PhotoInteraction) -> some View {
        Group {
            if photo.isCustom, let data = photo.imageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let img = UIImage(named: photo.photoName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(hex: "#412402")
            }
        }
        .blur(radius: 22)
    }
}
