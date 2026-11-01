import AppKit
import SnapDeckCore
import SwiftUI

extension Color {
    static let snapDeck = Color(red: 0.09, green: 0.40, blue: 0.96)
}

struct SettingsCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 18

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.11, blue: 0.31),
                            Color(red: 0.08, green: 0.36, blue: 0.93)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            HStack(spacing: size * 0.055) {
                RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                    .fill(.white.opacity(0.92))
                RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                    .fill(.white.opacity(0.38))
            }
            .padding(size * 0.17)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct PermissionBanner: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 38, height: 38)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.orange.opacity(0.22), lineWidth: 1)
        }
    }
}

struct PermissionStatusRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(isGranted ? .green : .orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            if isGranted {
                Text("Разрешено")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct ShortcutPill: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct SnapZoneDiagram: View {
    let zone: SnapZone

    var body: some View {
        GeometryReader { proxy in
            let rect = normalizedRect
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.snapDeck.opacity(0.82))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 0.7)
                    }
                    .frame(
                        width: max(4, proxy.size.width * rect.width - 4),
                        height: max(4, proxy.size.height * rect.height - 4)
                    )
                    .offset(
                        x: proxy.size.width * rect.minX + 2,
                        y: proxy.size.height * rect.minY + 2
                    )
            }
        }
        .aspectRatio(1.55, contentMode: .fit)
    }

    private var normalizedRect: CGRect {
        switch zone {
        case .leftHalf:
            CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf:
            CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf:
            CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf:
            CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft:
            CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight:
            CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft:
            CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight:
            CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .firstThird:
            CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        case .centerThird:
            CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .lastThird:
            CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .firstTwoThirds:
            CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1)
        case .lastTwoThirds:
            CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .maximize:
            CGRect(x: 0, y: 0, width: 1, height: 1)
        case .center:
            CGRect(x: 0.14, y: 0.09, width: 0.72, height: 0.82)
        }
    }
}

struct GestureRow: View {
    let gesture: String
    let action: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.snapDeck)
                .frame(width: 28)
            Text(gesture)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(action)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
