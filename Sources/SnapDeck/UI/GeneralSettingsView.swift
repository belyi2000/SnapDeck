import SnapDeckCore
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: PermissionManager

    @State private var nativeTilingStatus = NativeTilingController.status()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                if !permissions.accessibilityGranted {
                    PermissionBanner(
                        title: "Нужен доступ Accessibility",
                        message: "Без него macOS не разрешает двигать окна и читать их положение. Разрешите SnapDeck в системных настройках.",
                        buttonTitle: "Разрешить",
                        action: {
                            permissions.requestAccessibilityPermission()
                            permissions.openAccessibilitySettings()
                        }
                    )
                }

                if permissions.accessibilityGranted && !permissions.screenRecordingGranted {
                    PermissionBanner(
                        title: "Включите живые миниатюры",
                        message: "Snap Assist покажет превью окон, если разрешить SnapDeck запись экрана. Без этого останутся иконки приложений.",
                        buttonTitle: "Разрешить",
                        action: {
                            permissions.requestScreenRecordingPermission()
                            permissions.openScreenRecordingSettings()
                        }
                    )
                }

                if nativeTilingStatus.isLikelyActive {
                    nativeTilingBanner
                }

                SettingsCard {
                    VStack(spacing: 0) {
                        SettingToggleRow(
                            title: "Прилипание перетаскиванием",
                            subtitle: "Поднесите окно к краю или углу экрана и отпустите. Слева и справа — половины, в углах — четверти, сверху — на весь экран.",
                            isOn: $settings.edgeSnapEnabled
                        )
                        Divider().padding(.vertical, 13)
                        SettingToggleRow(
                            title: "Показывать зону при перетаскивании",
                            subtitle: "Полупрозрачный предпросмотр будущего положения окна.",
                            isOn: $settings.showTargetPreview
                        )
                        Divider().padding(.vertical, 13)
                        SettingToggleRow(
                            title: "Snap Assist",
                            subtitle: "После прижатия окна показать список окон, которыми можно заполнить свободную половину.",
                            isOn: $settings.snapAssistEnabled
                        )
                        Divider().padding(.vertical, 13)
                        SettingToggleRow(
                            title: "Заполнять вторую половину автоматически",
                            subtitle: "Сразу подставлять следующее окно в свободную часть экрана. Если окон нет, Snap Assist покажет список.",
                            isOn: $settings.autoFillOtherHalf
                        )
                        Divider().padding(.vertical, 13)
                        SettingToggleRow(
                            title: "Связанное изменение размера",
                            subtitle: "Потяните за перемычку между двумя окнами — размер изменят оба окна сразу.",
                            isOn: $settings.linkedResizeEnabled
                        )
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Отступ между окнами")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("0 pt — как в Windows. Отступ применяется к краям экрана и между окнами.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(settings.gap)) pt")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Text("0")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Slider(value: $settings.gap, in: 0...24, step: 1)
                            Text("24")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                howItWorks
                Spacer(minLength: 4)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity)
        }
    }

    private var nativeTilingBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 38, height: 38)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Системное прилипание macOS включено")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Из-за него при перетаскивании видны два контура. Отключите встроенный drag-to-tile — SnapDeck заменит его своим прилипанием. Системные горячие клавиши не затрагиваются.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("Убрать второй контур") {
                _ = NativeTilingController.disableEdgeTiling()
                nativeTilingStatus = NativeTilingController.status()
            }
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

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            AppMark(size: 68)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Text("SnapDeck")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    StatusBadge(
                        title: !permissions.accessibilityGranted
                            ? "Нет доступа"
                            : (settings.isEnabled ? "Активно" : "Пауза"),
                        color: !permissions.accessibilityGranted
                            ? .orange
                            : (settings.isEnabled ? .green : .secondary)
                    )
                }
                Text("Windows-прилипание, четверти и Snap Assist — нативно для macOS.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Toggle("", isOn: $settings.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                Text(settings.isEnabled ? "Включено" : "Выключено")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.snapDeck.opacity(0.16),
                            Color(nsColor: .controlBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.snapDeck.opacity(0.18), lineWidth: 1)
        }
    }

    private var howItWorks: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("Как это работает")
                    .font(.system(size: 13, weight: .semibold))

                HStack(alignment: .top, spacing: 12) {
                    step(
                        number: "1",
                        icon: "cursorarrow.motionlines",
                        title: "Край экрана",
                        detail: "Потяните окно за заголовок к краю."
                    )
                    step(
                        number: "2",
                        icon: "rectangle.split.2x1",
                        title: "Отпустите",
                        detail: "Окно мгновенно займёт половину."
                    )
                    step(
                        number: "3",
                        icon: "rectangle.on.rectangle",
                        title: "Заполните",
                        detail: "Snap Assist предложит второе окно."
                    )
                }
            }
        }
    }

    private func step(number: String, icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(number)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(Color.snapDeck, in: Circle())
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.snapDeck)
            }
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
