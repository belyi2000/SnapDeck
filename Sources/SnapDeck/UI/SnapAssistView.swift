import AppKit
import CoreGraphics
import SnapDeckCore
import SwiftUI

struct SnapAssistView: View {
    @ObservedObject var model: SnapAssistModel
    let onSelect: (WindowInfo) -> Void
    let onClose: () -> Void

    @State private var hoveredID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.32)
            content
            Divider().opacity(0.32)
            footer
        }
        .background {
            GlassBackground(cornerRadius: 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "rectangle.split.2x1.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.snapDeck)
                .frame(width: 38, height: 38)
                .background(
                    Color.snapDeck.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Snap Assist")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("\(model.candidates.count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Text(headerSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 25, height: 25)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Закрыть")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    private var content: some View {
        GeometryReader { proxy in
            let availableWidth = max(1, proxy.size.width - 28)
            let columns = model.candidates.count == 1
                ? 1
                : (availableWidth >= 540 ? 2 : 1)
            let spacing: CGFloat = 12
            let cardWidth = max(
                140,
                (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            )
            let rows = makeRows(columns: columns)

            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: spacing) {
                            if row.count < columns {
                                Spacer(minLength: 0)
                            }

                            ForEach(row) { candidate in
                                card(candidate)
                                    .frame(width: cardWidth)
                            }

                            if row.count < columns {
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(
                    minHeight: max(0, proxy.size.height - 28),
                    alignment: .center
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func makeRows(columns: Int) -> [[AssistCandidate]] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: model.candidates.count, by: columns).map { start in
            Array(model.candidates[start..<min(start + columns, model.candidates.count)])
        }
    }

    private func card(_ candidate: AssistCandidate) -> some View {
        Button {
            onSelect(candidate.window)
        } label: {
            VStack(spacing: 0) {
                thumbnail(candidate)
                    .padding(7)

                HStack(spacing: 8) {
                    Group {
                        if let icon = candidate.window.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "macwindow")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(candidate.window.appName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Text(candidate.window.displayTitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .background(
                Color(nsColor: .windowBackgroundColor)
                    .opacity(hoveredID == candidate.id ? 0.44 : 0.24),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        .white.opacity(hoveredID == candidate.id ? 0.26 : 0.10),
                        lineWidth: 0.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredID = hovering ? candidate.id : (hoveredID == candidate.id ? nil : hoveredID)
        }
    }

    private func thumbnail(_ candidate: AssistCandidate) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = model.thumbnails[candidate.id] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                VStack(spacing: 9) {
                    if let icon = candidate.window.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                    } else {
                        Image(systemName: "macwindow")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }

                    if candidate.window.isMinimized {
                        Text("Свернуто")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if model.permissionDenied {
                        Text("Нужна запись экрана")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Превью недоступно")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
        }
    }

    private var headerSubtitle: String {
        if model.candidates.allSatisfy({ $0.window.isMinimized }) {
            return "Свернутые окна — выберите для второй половины"
        }
        return "Выберите окно для второй половины"
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if model.permissionDenied {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Для живых миниатюр включите «Запись экрана»")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Включить") {
                    requestScreenRecording()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10.5, weight: .semibold))
            } else if model.isLoading {
                ProgressView()
                    .controlSize(.mini)
                Text("Загружаем превью окон…")
                    .foregroundStyle(.secondary)
                Spacer()
            } else if model.errorMessage != nil && !model.hasAnyThumbnail {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("Превью недоступны")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Image(systemName: "cursorarrow.click")
                Text("Выберите окно")
                Spacer()
                Text("1–6 · Esc — закрыть")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) {
            NSWorkspace.shared.open(url)
        }
    }
}
