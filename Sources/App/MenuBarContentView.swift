import SwiftUI
import AppKit
import AgentPetCore

/// The menu bar dropdown (native menu, so it dismisses on selection and on
/// outside clicks).
struct MenuBarContentView: View {
    @ObservedObject private var daemon = AppDaemon.shared
    @ObservedObject private var petWindow = PetWindowController.shared

    var body: some View {
        if daemon.sessions.isEmpty {
            Text("No agents running")
        } else {
            ForEach(daemon.sessions) { session in
                Text(line(for: session))
            }
        }

        Divider()

        Toggle("Show pet", isOn: $petWindow.isVisible)
        Button("Choose Pet...") { SettingsWindowController.shared.show() }

        Divider()

        Button("Settings...") { SettingsWindowController.shared.show() }
            .keyboardShortcut(",")
        Button("Quit AgentPet") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func line(for session: AgentSession) -> String {
        let dot: String
        switch session.state {
        case .working, .registered: dot = "🔵"
        case .waiting: dot = "🟠"
        case .done: dot = "🟢"
        case .idle: dot = "⚪️"
        }
        let project = session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
        return "\(dot)  \(project) — \(session.state.rawValue) · \(time(session))"
    }

    private func time(_ session: AgentSession) -> String {
        switch session.state {
        case .done, .idle:
            return session.updatedAt.formatted(date: .omitted, time: .shortened)
        default:
            let secs = Int(Date().timeIntervalSince(session.updatedAt))
            return secs < 60 ? "\(secs)s" : "\(secs / 60)m"
        }
    }
}
