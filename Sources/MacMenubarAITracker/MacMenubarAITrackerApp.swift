import SwiftUI

@main
struct MacMenubarAITrackerApp: App {
    @StateObject private var store = SkillStore()
    @StateObject private var settings = TrackerSettings()

    var body: some Scene {
        MenuBarExtra("AI Skills", systemImage: "sparkles") {
            TrackerPanel(store: store, settings: settings)
                .frame(width: 760, height: 520)
                .task {
                    await store.refresh(roots: settings.scanRoots)
                }
        }
        .menuBarExtraStyle(.window)
    }
}
