import SwiftUI
import SwiftData

@main
struct Prototype_1App: App {

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                Canvas.self,
                VisionItem.self,
                LifeArea.self,
                Reflection.self,
                MonthlyRecord.self,
                WeeklyTaskItem.self
            )
        } catch {
            fatalError("SwiftData failed to load: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
