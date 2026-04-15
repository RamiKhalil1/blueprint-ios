import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm {
                OnboardingContainerInner(vm: vm)
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .task {
            if vm == nil {
                vm = OnboardingViewModel(modelContext: modelContext)
            }
        }
    }
}

struct OnboardingContainerInner: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        Group {
            switch vm.currentStep {
            case .splash:       SplashView(vm: vm)
            case .visionBoard:  VisionBoardView(vm: vm)
            case .reflections:  ReflectionsView(vm: vm)
            case .priorityRank: PriorityRankView(vm: vm)
            case .complete:     DashboardView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: vm.currentStep)
    }
}
