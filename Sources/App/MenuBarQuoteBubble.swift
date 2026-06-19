import SwiftUI

/// A small speech bubble with an upward tail, dropped from the menu bar icon.
struct MenuBarQuoteBubble: View {
    let text: String

    private var isMultiline: Bool {
        text.contains("\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 14, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.leading)
                .lineLimit(isMultiline ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: 280, alignment: .leading)
                .background {
                    if isMultiline {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.regularMaterial)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
                .overlay {
                    if isMultiline {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    } else {
                        Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
                }
        }
        .environment(\.colorScheme, .dark)
        .padding(6)
        .fixedSize(horizontal: !isMultiline, vertical: true)
    }
}

/// Upward-pointing triangle (apex at top).
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
