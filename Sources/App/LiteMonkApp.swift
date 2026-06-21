import SwiftUI
import AppKit

struct LiteMonkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI lives in a status-item popover and floating windows managed by
        // AppDelegate; this empty scene just satisfies the App protocol.
        Settings { EmptyView() }
    }
}

/// Runs the app as a menu bar accessory (no Dock icon).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Held strongly so the Sparkle updater delegate and background timers are
    // never deallocated for the lifetime of the app.
    private var updater: UpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = AppLanguage.shared   // apply the saved language before any UI renders
        DefaultPetBootstrap.installBundledPetIfNeeded()
        ImagePetStore.shared.reload()
        if PetController.shared.selectedPetID == nil {
            if ImagePetStore.shared.packs.contains(where: { $0.id == "an-mo" }) {
                PetController.shared.selectedPetID = "an-mo"
            } else {
                PetController.shared.selectedPetID = ImagePetStore.shared.packs.first?.id
            }
        }
        PetController.shared.start()
        MindfulnessBellSettings.shared.start()
        PetWindowController.shared.start()
        updater = UpdaterController.shared
        StatusBarController.shared.start()
        DefaultPetBootstrap.installIfNeeded()
        SettingsWindowController.shared.showOnFirstLaunch()
    }

}
