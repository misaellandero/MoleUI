//
//  OperationEffectView.swift
//  Libella
//

import SwiftUI

struct OperationEffectView: View {
    let title: String
    let subtitle: String

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .leading) {
                if VisualSettings.particlesEnabled {
                    AmbientParticleBackdrop(seed: 8.8, intensity: 0.72)
                }
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(0.82)
                Canvas { context, size in
                    let center = CGPoint(x: size.width * 0.78, y: size.height * 0.5)
                    let width = min(size.width * 0.28, 154)
                    let height = min(size.height * 0.58, 76)

                    var leftLoop = Path()
                    leftLoop.addEllipse(in: CGRect(x: center.x - width, y: center.y - height / 2, width: width, height: height))
                    var rightLoop = Path()
                    rightLoop.addEllipse(in: CGRect(x: center.x, y: center.y - height / 2, width: width, height: height))

                    context.stroke(leftLoop, with: .color(.cyan.opacity(0.035)), lineWidth: 2)
                    context.stroke(rightLoop, with: .color(.blue.opacity(0.035)), lineWidth: 2)

                    for index in 0..<7 {
                        let phase = time * (0.34 + Double(index) * 0.018) + Double(index) * .pi * 0.57
                        let wobble = sin(time * 0.21 + Double(index) * 2.1) * 0.12
                        let x = center.x + CGFloat(sin(phase) + wobble) * width * 0.52
                        let y = center.y + CGFloat(sin(phase * 2 + wobble * 2.7)) * height * 0.42
                        let size = CGFloat(18 + (index % 3) * 8)
                        let glowRect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
                        context.addFilter(.blur(radius: 13))
                        context.fill(Path(ellipseIn: glowRect.insetBy(dx: -16, dy: -16)), with: .color(index % 2 == 0 ? .cyan.opacity(0.13) : .blue.opacity(0.10)))
                    }
                }
                .blur(radius: 8)
                .opacity(0.78)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.09))
                            .frame(width: 250, height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.35), .blue.opacity(0.72), .cyan.opacity(0.35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 82, height: 6)
                            .offset(x: CGFloat((sin(time * 1.2) + 1) * 84))
                            .shadow(color: .cyan.opacity(0.45), radius: 8, x: 0, y: 0)
                    }
                    .accessibilityLabel("Scanning in progress")
                    .padding(.top, 4)
                    HStack(spacing: 5) {
                        ForEach(0..<24, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cyan.opacity(0.08 + 0.28 * max(0, sin(time * 2.1 + Double(index) * 0.34))))
                                .frame(width: 3, height: 6 + CGFloat(max(0, sin(time * 1.7 + Double(index) * 0.5))) * 14)
                        }
                    }
                    .frame(height: 28)
                    .blur(radius: 0.6)
                    .padding(.top, 6)
                }
                .padding(22)
            }
            .clipShape(.rect(cornerRadius: 8))
            .overlay(TronLoopBorderView(cornerRadius: 8, lineWidth: 1.3))
        }
    }
}
