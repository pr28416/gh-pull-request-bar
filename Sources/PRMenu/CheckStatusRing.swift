import SwiftUI

struct CheckStatusRing: View {
    var summary: CheckSummary
    var size: CGFloat = 18
    var lineWidth: CGFloat = 3

    private var passedColor: Color { Color(red: 0.12, green: 0.62, blue: 0.33) }
    private var failedColor: Color { Color(red: 0.86, green: 0.21, blue: 0.27) }
    private var pendingColor: Color { Color.secondary.opacity(0.38) }
    private var emptyColor: Color { Color.secondary.opacity(0.22) }

    var body: some View {
        Canvas { context, canvasSize in
            let radius = min(canvasSize.width, canvasSize.height) / 2 - lineWidth / 2
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            if !summary.hasChecks {
                stroke(
                    context: context,
                    center: center,
                    radius: radius,
                    start: .degrees(-90),
                    sweep: .degrees(360),
                    color: emptyColor
                )
                return
            }

            var start = Angle.degrees(-90)
            let slices: [(Int, Color)] = [
                (summary.passed, passedColor),
                (summary.pending, pendingColor),
                (summary.failed, failedColor),
            ]

            for (count, color) in slices where count > 0 {
                let sweep = Angle.degrees(360 * Double(count) / Double(summary.total))
                stroke(
                    context: context,
                    center: center,
                    radius: radius,
                    start: start,
                    sweep: sweep,
                    color: color
                )
                start += sweep
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func stroke(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        start: Angle,
        sweep: Angle,
        color: Color
    ) {
        let path = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: start + sweep,
                clockwise: false
            )
        }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: summary.total > 1 ? .butt : .round)
        )
    }
}

struct CheckStatusView: View {
    var summary: CheckSummary
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            CheckStatusRing(
                summary: summary,
                size: compact ? 12 : 18,
                lineWidth: compact ? 2 : 3
            )
            Text(fractionText)
                .font(
                    compact
                        ? .system(size: 11, weight: .medium).monospacedDigit()
                        : .caption.monospacedDigit().weight(.medium)
                )
                .foregroundStyle(fractionColor)
                .frame(minWidth: compact ? 0 : 28, alignment: .leading)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var fractionText: String {
        guard summary.hasChecks else { return "–" }
        return "\(summary.passed)/\(summary.total)"
    }

    private var fractionColor: Color {
        if !summary.hasChecks {
            return .secondary
        }
        if summary.failed > 0 {
            return Color(red: 0.86, green: 0.21, blue: 0.27)
        }
        if summary.pending > 0 {
            return .secondary
        }
        return Color(red: 0.12, green: 0.62, blue: 0.33)
    }

    private var accessibilityText: String {
        guard summary.hasChecks else {
            return "No checks"
        }
        return "\(summary.passed) of \(summary.total) checks passed"
    }
}
