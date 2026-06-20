import SwiftUI
import AgentPetCore

/// The pet sprite alone (imported pack, reacting to mood). Shows a paw
/// placeholder if no pet is selected yet.
struct PetView: View {
    var size: CGFloat = 120
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    @ObservedObject private var bindings = PetBindingsStore.shared

    var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        if let id = pet.selectedPetID, let pack = imagePets.pack(id: id) {
            let clip = bindings.clipIndex(packId: pack.id, clipCount: pack.clipCount, mood: pet.mood)
            ImageSpriteView(frames: pack.clip(clip), mood: pet.mood, size: size)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

/// Tracks and sizes the floating window so it follows the visible bubble/pet
/// area and avoids clipping.
private struct PetContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

/// Full floating window content: quote bubble + pet interaction reaction.
struct FloatingPetView: View {
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var appLang = AppLanguage.shared

    var body: some View {
        VStack(spacing: 2) {
            if pet.showQuote && pet.selectedPetID != nil, !pet.quoteLine.isEmpty {
                QuoteBubble(text: pet.quoteLine)
                    .id(pet.quoteSwapToken)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            Button(action: { pet.petTap() }) {
                PetView(size: pet.petPoint)
                    .overlay {
                        if pet.petTapCount > 0 {
                            PetHearts(size: pet.petPoint)
                                .id(pet.petTapCount)
                        }
                    }
                    .overlay(alignment: .top) {
                        if !pet.petReactionLine.isEmpty {
                            Text(pet.petReactionLine)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                .offset(y: -16)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .scaleEffect(
                x: pet.isPetted ? 1.12 : 1.0,
                y: pet.isPetted ? 0.82 : 1.0,
                anchor: .bottom
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 8), value: pet.isPetted)
        }
        .fixedSize(horizontal: true, vertical: true)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pet.quoteLine)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pet.petReactionLine)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pet.showQuote)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PetContentSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(PetContentSizeKey.self) { size in
            PetWindowController.shared.resizeToContent(size)
        }
        .environment(\.locale, appLang.locale)
    }
}

/// Plain speech bubble with a downward tail, used for quote and reaction text.
struct QuoteBubble: View {
    let text: String
    private let fill = Color(nsColor: .windowBackgroundColor).opacity(0.72)
    private let textColor = Color.primary.opacity(0.9)
    private let borderColor = Color.primary.opacity(0.08)
    private var isMultiline: Bool { text.contains("\n") }

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(isMultiline ? nil : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: 320, alignment: .leading)
                .background {
                    if isMultiline {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
                    } else {
                        Capsule().fill(fill)
                    }
                }
                .overlay {
                    if isMultiline {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    } else {
                        Capsule().strokeBorder(borderColor, lineWidth: 1)
                    }
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            Triangle()
                .fill(fill)
                .frame(width: 12, height: 7)
        }
        .fixedSize(horizontal: !isMultiline, vertical: true)
        .frame(maxWidth: 420)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
