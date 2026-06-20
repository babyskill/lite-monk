import SwiftUI
import AppKit
import LiteMonkCore

/// Minimal menu bar popover: quick character controls and the current Dhammapada quote.
struct MenuContentView: View {
    @ObservedObject private var petWindow = PetWindowController.shared
    @ObservedObject private var statusBar = StatusBarController.shared
    @ObservedObject private var pet = PetController.shared
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
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.58, blue: 0.16),
                        Color(red: 0.60, green: 0.34, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 28, height: 28)
                .overlay(ZenCharacterGlyph().foregroundStyle(.white).padding(5))
            VStack(alignment: .leading, spacing: 1) {
                Text("An Mộ").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text("Nhân vật Pháp Cú").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(petWindow.isVisible ? "Đang hiện" : "Đang ẩn")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(14)
    }

    // MARK: Quote

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pháp Cú")
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
            controlRow(icon: "figure.mind.and.body", label: "Hiện nhân vật", isOn: $petWindow.isVisible)
            controlRow(icon: "bubble.left", label: "Hiện câu kệ trên thanh menu", isOn: $statusBar.showQuoteOnMenuBar)
            sizeRow
            fontSizeRow
        }
    }

    private var sizeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text("Cỡ nhân vật").font(.system(size: 13)).foregroundStyle(.white)
            Slider(value: $pet.petPoint, in: PetController.minPoint...PetController.maxPoint)
                .controlSize(.mini)
                .tint(Color.systemAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var fontSizeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "textformat.size")
                .foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text("Cỡ chữ").font(.system(size: 13)).foregroundStyle(.white)
            Slider(value: $pet.fontSize, in: PetController.minFontSize...PetController.maxFontSize)
                .controlSize(.mini)
                .tint(Color.systemAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func controlRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
            Spacer()
            ColorSwitch(isOn: isOn)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: Footer

    @ObservedObject private var updater = UpdaterController.shared

    private var footer: some View {
        HStack {
            FooterButton(icon: "gearshape", label: "Cài đặt") {
                // Use closeAndThen so the window appears only after the popover
                // animation fully completes.
                StatusBarController.shared.closeAndThen {
                    SettingsWindowController.shared.show()
                }
            }
            FooterButton(
                icon: "arrow.triangle.2.circlepath",
                label: "Cập nhật",
                badge: updater.updatePending
            ) {
                StatusBarController.shared.closeAndThen {
                    UpdaterController.shared.checkForUpdates()
                }
            }
            Spacer()
            FooterButton(icon: "power", label: "Thoát") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct ZenCharacterGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Circle()
                    .frame(width: w * 0.45, height: w * 0.45)
                    .offset(y: -h * 0.22)
                Capsule()
                    .frame(width: w * 0.64, height: h * 0.38)
                    .offset(y: h * 0.18)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.20, y: h * 0.78))
                    path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.60),
                                      control: CGPoint(x: w * 0.28, y: h * 0.58))
                    path.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.78),
                                      control: CGPoint(x: w * 0.72, y: h * 0.58))
                }
                .stroke(style: StrokeStyle(lineWidth: max(1.2, w * 0.09), lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
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
