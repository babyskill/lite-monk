import SwiftUI

/// A small, low-key "thanks" sheet. Vietnamese users get a VietQR they can scan
/// from any banking app; everyone else gets the international coffee link. It's
/// opt-in (only shown when the user taps "Buy me a coffee"), never nagging.
struct CoffeeView: View {
    let coffeeURL: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Show the local QR to people whose system region/language is Vietnamese.
    private var isVietnam: Bool {
        if Locale.current.language.languageCode?.identifier == "vi" { return true }
        if Locale.current.region?.identifier == "VN" { return true }
        return false
    }

    private var qrImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "donate-vietqr", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 30)).foregroundStyle(Color.systemAccent)
            Text("Thanks for using AgentPet")
                .font(.title3.bold())
            Text("It's free and open source. If it makes your day a little nicer, a coffee is always appreciated, never expected.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isVietnam, let qr = qrImage {
                Image(nsImage: qr)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 220, height: 260)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                Text("Quét mã bằng app ngân hàng bất kỳ")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("626333362", forType: .string)
                } label: {
                    Label("Sao chép số tài khoản", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            } else {
                Button { openURL(coffeeURL) } label: {
                    Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(Color.systemAccent).controlSize(.large)
            }

            Button("Close") { dismiss() }
                .controlSize(.large)
        }
        .padding(24)
        .frame(width: 320)
        .preferredColorScheme(.dark)
        .noFocusRing()
    }
}
