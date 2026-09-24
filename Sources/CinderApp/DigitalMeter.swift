import SwiftUI
import CinderCore

struct DigitalMeter: View {
    @Environment(\.cinderTheme) private var theme
    let peak: Double
    let rms: Double
    let needle: Bool
    private func normalized(_ db: Double) -> Double { (max(-90, min(0, db)) + 90) / 90 }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(Array([("Peak", peak), ("RMS", rms)].enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(item.0); Spacer(); Text(item.1.isFinite ? String(format: "%.1f dBFS", item.1) : "−∞ dBFS").monospacedDigit() }
                    ZStack {
                    if needle {
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height - 5)
                            let radius = min(size.width / 2 - 16, size.height - 14)
                            var arc = Path()
                            arc.addArc(center: center, radius: radius, startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
                            context.stroke(arc, with: .color(theme.map { Color(hex: $0.colors["meter.track"]!) } ?? .secondary.opacity(0.3)), lineWidth: 2)
                            let angle = (210 + normalized(item.1) * 120) * .pi / 180
                            var hand = Path(); hand.move(to: center)
                            hand.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
                            context.stroke(hand, with: .color(theme.map { Color(hex: $0.colors["meter.fill"]!) } ?? .orange.opacity(0.8)), lineWidth: 2)
                        }.frame(height: 48)
                    } else {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.map { Color(hex: $0.colors["meter.track"]!) } ?? .secondary.opacity(0.2))
                                Capsule().fill(theme.map { Color(hex: $0.colors["meter.fill"]!) } ?? .orange.opacity(0.7)).frame(width: geometry.size.width * normalized(item.1))
                            }
                        }.frame(height: 8)
                    }
                    }.frame(height: 48)
                    HStack { Text("−90"); Spacer(); Text("−45"); Spacer(); Text("0 dBFS") }.foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
        }.padding(14)
            .background(theme.map { Color(hex: $0.colors["meter.background"]!) } ?? .clear, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(theme.map { Color(hex: $0.colors["meter.text"]!) } ?? .primary)
    }
}
