import SwiftUI
import AgentPetCore

/// Draws an original built-in pet with SwiftUI shapes and animates it by mood.
/// Continuous motion is driven by `TimelineView` so there are no timers to
/// manage; expression and accessories switch on the mood.
struct PetSpriteView: View {
    let kind: PetKind
    let mood: PetMood
    var size: CGFloat = 110

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let m = PetMotion.resolve(mood, t)

            ZStack {
                MoodAccessories(mood: mood, t: t, size: size, bubbleTint: kind.tint)

                ZStack {
                    body(t)
                    face(t)
                }
                .rotationEffect(.degrees(m.rotation), anchor: .bottom)
                .scaleEffect(x: m.scaleX, y: m.scaleY, anchor: .bottom)
                .offset(y: m.offsetY)
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Body

    @ViewBuilder private func body(_ t: Double) -> some View {
        let w = size * 0.62
        let h = size * 0.56
        ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [kind.tint, kind.tint.opacity(0.78)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(shape.stroke(.black.opacity(0.08), lineWidth: 1))
                .frame(width: w, height: h)
                .shadow(color: kind.tint.opacity(0.35), radius: 6, y: 3)

            if kind == .bot { antenna(height: h) }
        }
    }

    private var shape: AnyShape {
        switch kind {
        case .blob:
            return AnyShape(Ellipse())
        case .ghost:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 40, bottomLeadingRadius: 12,
                bottomTrailingRadius: 12, topTrailingRadius: 40))
        case .bot:
            return AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder private func antenna(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle().fill(kind.tint).frame(width: 7, height: 7)
            Rectangle().fill(kind.tint).frame(width: 2.5, height: 10)
        }
        .offset(y: -height / 2 - 6)
    }

    // MARK: - Face

    @ViewBuilder private func face(_ t: Double) -> some View {
        let happy = (mood == .done || mood == .celebrate)
        VStack(spacing: 5) {
            HStack(spacing: 14) {
                eye(t, happy: happy, lookLeft: mood == .waiting)
                eye(t, happy: happy, lookLeft: mood == .waiting)
            }
            mouth
        }
        .offset(y: -2)
    }

    @ViewBuilder private func eye(_ t: Double, happy: Bool, lookLeft: Bool) -> some View {
        if happy {
            HappyEye().stroke(.black.opacity(0.8), style: .init(lineWidth: 2.4, lineCap: .round))
                .frame(width: 11, height: 7)
        } else {
            let blink = blinkAmount(t)
            ZStack {
                Capsule().fill(.white).frame(width: 11, height: 13)
                Circle().fill(.black.opacity(0.85)).frame(width: 6, height: 6)
                    .offset(x: lookLeft ? -2 : 0, y: 1)
            }
            .scaleEffect(y: blink, anchor: .center)
        }
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .done, .celebrate:
            Smile().stroke(.black.opacity(0.7), style: .init(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 9)
        case .waiting:
            Circle().fill(.black.opacity(0.55)).frame(width: 6, height: 6)
        default:
            Capsule().fill(.black.opacity(0.45)).frame(width: 9, height: 2.4)
        }
    }

    private func blinkAmount(_ t: Double) -> CGFloat {
        let cycle = t.truncatingRemainder(dividingBy: 4.0)
        return cycle > 3.82 ? 0.12 : 1.0
    }
}

// MARK: - Expression shapes

private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return p
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
        return p
    }
}
