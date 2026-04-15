import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var canvases: [Canvas]
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                LaunchSplashView()
                    .transition(.opacity)
            } else if let canvas = canvases.first, canvas.onboardingComplete {
                DashboardView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut, value: canvases.first?.onboardingComplete)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { showSplash = false }
            }
        }
    }
}

// MARK: - Launch Splash
struct LaunchSplashView: View {
    @State private var opacity = 0.0
    @State private var scale = 0.92

    var body: some View {
        ZStack {
            Color(hex: "#412402")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BA7517").opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "map.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#EF9F27"))
                }

                VStack(spacing: 6) {
                    Text("Blueprint")
                        .font(.custom("Georgia", size: 32))
                        .foregroundColor(Color(hex: "#FAEEDA"))

                    Text("Design your life.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#BA7517"))
                        .tracking(1.5)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 1.0
                    scale = 1.0
                }
            }
        }
    }
}
