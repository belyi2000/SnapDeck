import SwiftUI

/// A small Liquid Glass surface with restrained light and a single hairline.
/// On macOS 26+ it uses the real system glass material; on older systems it
/// falls back to a blurred material with the same restrained highlights.
struct GlassBackground: View {
    var cornerRadius: CGFloat = 22
    var tint: Color?
    var veilOpacity: Double = 0.10

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Color.white.opacity(0.001)
                    .glassEffect(
                        .regular.tint(tint ?? Color.white.opacity(0.14)),
                        in: shape
                    )
            } else {
                shape.fill(.ultraThinMaterial)
            }

            // A barely-there frosted veil keeps the glass luminous on dark
            // wallpapers without hiding the blurred content underneath.
            shape
                .fill(Color.white.opacity(veilOpacity))

            // Diffused light from the top-left; deliberately low contrast so
            // it reads as reflected light instead of a colored fill.
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.31),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 620
                    )
                )
                .blendMode(.screen)

            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 420
                    )
                )
                .blendMode(.screen)

            // Diffused rim light: a blurred inner stroke rather than a hard
            // colored border. This is the main "liquid" highlight of the pane.
            shape
                .strokeBorder(Color.white.opacity(0.32), lineWidth: 3)
                .blur(radius: 8)
                .clipShape(shape)

            // One hairline only. It is brightest along the top-left highlight
            // and almost disappears along the bottom edge.
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.48),
                        Color.white.opacity(0.12),
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
        }
        .clipShape(shape)
    }
}
