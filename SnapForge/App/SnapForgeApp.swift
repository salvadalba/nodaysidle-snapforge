import SwiftUI
import SwiftData

@main
struct SnapForgeApp: App {
    @State private var appServices = AppServices()

    var body: some Scene {
        MenuBarExtra("SnapForge", systemImage: "hammer.fill") {
            MenuBarView()
                .environment(appServices)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appServices)
        }

        Window("SnapForge Library", id: "library") {
            LibraryBrowserView()
                .environment(appServices)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
