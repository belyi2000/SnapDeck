import SnapDeckCore
import SwiftUI

struct ZonesSettingsView: View {
    @ObservedObject var settings: AppSettings

    private let featuredZones: [SnapZone] = [
        .leftHalf,
        .rightHalf,
        .maximize,
        .center,
        .topLeft,
        .topRight,
        .bottomLeft,
        .bottomRight
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader(
                    title: "Зоны",
                    subtitle: "Быстрые команды для одного окна и раскладки для всего рабочего стола."
                )

                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Одиночное окно")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Работает и перетаскиванием, и с клавиатуры. Выберите окно и нажмите сочетание.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 145), spacing: 11)],
                            spacing: 11
                        ) {
                            ForEach(featuredZones) { zone in
                                ZoneCard(zone: zone, shortcut: shortcut(for: zone))
                            }
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Массовая раскладка")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Разложить все видимые окна на активном дисплее.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.snapDeck)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 205), spacing: 9)],
                            spacing: 9
                        ) {
                            ForEach(TilingPreset.allCases) { preset in
                                HStack(spacing: 9) {
                                    Image(systemName: preset.symbolName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.snapDeck)
                                        .frame(width: 23, height: 23)
                                        .background(Color.snapDeck.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                                    Text(preset.title)
                                        .font(.system(size: 11.5, weight: .medium))
                                    Spacer()
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 8)
                                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "menubar.rectangle")
                            Text("Доступно из меню SnapDeck в строке состояния → «Разложить».")
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "rectangle.split.2x1.fill")
                                .foregroundStyle(Color.snapDeck)
                            Text("Snap Assist")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Toggle("", isOn: $settings.snapAssistEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }


                        Text("После прижатия к половине SnapDeck показывает живые превью окон, которыми можно заполнить вторую половину. Без разрешения «Запись экрана» остаются иконки приложений.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 9) {
                            miniPane(label: "Окно 1", filled: true)
                            Image(systemName: "arrow.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            VStack(spacing: 4) {
                                miniRow("Safari", icon: "safari")
                                miniRow("Finder", icon: "folder")
                                miniRow("Terminal", icon: "terminal")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(7)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                SettingsCard {
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.snapDeck)
                            .frame(width: 36, height: 36)
                            .background(Color.snapDeck.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Связанное изменение размера")
                                .font(.system(size: 13, weight: .semibold))
                            Text("После заполнения второй половины между окнами появляется перемычка. Потяните её — оба окна изменят размер одновременно, как в Windows Snap.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Toggle("", isOn: $settings.linkedResizeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity)
        }
    }

    private func shortcut(for zone: SnapZone) -> String? {
        WindowCommand.allCases.first { $0.snapZone == zone }?.shortcutHint
    }

    private func miniPane(label: String, filled: Bool) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4)
                .fill(filled ? Color.snapDeck.opacity(0.75) : Color.secondary.opacity(0.08))
                .frame(height: 58)
                .overlay(alignment: .topLeading) {
                    Text(label)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(filled ? .white : .secondary)
                        .padding(5)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func miniRow(_ label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8.5))
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }
}

private struct ZoneCard: View {
    let zone: SnapZone
    let shortcut: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SnapZoneDiagram(zone: zone)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(zone.shortTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                if let shortcut {
                    ShortcutPill(shortcut: shortcut)
                }
            }
        }
        .padding(9)
        .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
