import SwiftUI
import AppKit
import AgentPetCore

/// Minimal menu bar popover: quick pet controls and the current Dhammapada quote.
struct MenuContentView: View {
    @ObservedObject private var petWindow = PetWindowController.shared
    @ObservedObject private var statusBar = StatusBarController.shared
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            quoteSection
            divider
            controls
            divider
            footer
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .noFocusRing()
    }

    private var divider: some View { Divider().overlay(Color.white.opacity(0.08)) }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "pawprint.fill").font(.system(size: 13)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text("AgentPet").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text("Minimal Zen pet").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            let name = imagePets.pack(id: pet.selectedPetID ?? "")?.displayName ?? "Your pet"
            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
        }
        .padding(14)
    }

    // MARK: Quote

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dhammapada")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 14)
                .padding(.top, 12)

            if pet.showQuote && pet.showIdleMessage && !pet.quoteLine.isEmpty {
                Text(pet.quoteLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(IdleBoost.dhammapadaLine(at: context.date))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 0) {
            controlRow(icon: "pawprint", label: "Show pet", isOn: $petWindow.isVisible)
            controlRow(icon: "bubble.left", label: "Show quote near menu bar", isOn: $statusBar.showQuoteOnMenuBar)
            sizeRow
        }
    }

    private var sizeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text("Pet size").font(.system(size: 13)).foregroundStyle(.white)
            Slider(value: $pet.petPoint, in: PetController.minPoint...PetController.maxPoint)
                .controlSize(.mini)
                .tint(Color.systemAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func controlRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text(label).font(.system(size: 13)).foregroundStyle(.white)
            Spacer()
            ColorSwitch(isOn: isOn)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: Footer

    @ObservedObject private var updater = UpdaterController.shared

    private var footer: some View {
        HStack {
            FooterButton(icon: "gearshape", label: "Settings") {
                // Use closeAndThen so the window appears only after the popover
                // animation fully completes.
                StatusBarController.shared.closeAndThen {
                    SettingsWindowController.shared.show()
                }
            }
            FooterButton(
                icon: "arrow.triangle.2.circlepath",
                label: "Updates",
                badge: updater.updatePending
            ) {
                StatusBarController.shared.closeAndThen {
                    UpdaterController.shared.checkForUpdates()
                }
            }
            Spacer()
            FooterButton(icon: "power", label: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct FooterButton: View {
    let icon: String
    let label: String
    var badge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                    if badge {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(label)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}
