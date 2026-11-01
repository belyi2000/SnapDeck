import AppKit
import SnapDeckCore
import SwiftUI

struct AccessSettingsView: View {
    @ObservedObject var permissions: PermissionManager
    let onRestartMonitoring: () -> Void

    @State private var nativeTilingStatus = NativeTilingController.status()

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Доступ и диагностика")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("SnapDeck работает локально. Ему нужны только системные разрешения на управление окнами.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                SettingsCard {
                    VStack(spacing: 16) {
                        PermissionStatusRow(
                            title: "Универсальный доступ (Accessibility)",
                            description: "Чтение позиции окон и изменение их размера через публичный Accessibility API.",
                            isGranted: permissions.accessibilityGranted,
                            actionTitle: "Открыть",
                            action: {
                                permissions.requestAccessibilityPermission()
                                permissions.openAccessibilitySettings()
                            }
                        )

                        Divider()

                        PermissionStatusRow(
                            title: "Мониторинг ввода (Input Monitoring)",
                            description: "Прослушивание перетаскивания мыши и трекпада. События только читаются и никогда не подменяются.",
                            isGranted: permissions.inputMonitoringGranted,
                            actionTitle: "Открыть",
                            action: {
                                permissions.requestInputMonitoringPermission()
                                permissions.openInputMonitoringSettings()
                            }
                        )

                        Divider()

                        PermissionStatusRow(
                            title: "Запись экрана (Screen Recording)",
                            description: "Живые миниатюры окон в Snap Assist. Без этого доступа показываются иконки приложений. После выдачи может потребоваться перезапуск SnapDeck.",
                            isGranted: permissions.screenRecordingGranted,
                            actionTitle: "Открыть",
                            action: {
                                permissions.requestScreenRecordingPermission()
                                permissions.openScreenRecordingSettings()
                            }
                        )

                        Divider()

                        HStack(spacing: 10) {
                            Image(systemName: permissions.eventTapRunning ? "waveform.circle.fill" : "waveform.circle")
                                .foregroundStyle(permissions.eventTapRunning ? .green : .secondary)
                            Text("Монитор перетаскивания")
                                .font(.system(size: 11.5, weight: .medium))
                            Spacer()
                            Text(permissions.eventTapRunning ? "Работает" : "Остановлен")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(permissions.eventTapRunning ? .green : .secondary)
                            Button("Перезапустить", action: onRestartMonitoring)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Image(systemName: "macwindow.on.rectangle")
                                .foregroundStyle(.orange)
                            Text("Системное прилипание macOS")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if nativeTilingStatus.isLikelyActive {
                                Button("Убрать второй контур") {
                                    _ = NativeTilingController.disableEdgeTiling()
                                    nativeTilingStatus = NativeTilingController.status()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            Button("Настройки окон") {
                                openDesktopSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("macOS 15 и новее умеет прилипать окна к краям самостоятельно. Чтобы не появлялись две рамки и не срабатывали два механизма, отключите «Перетаскивать окна к краю экрана для мозаики» в Системные настройки → Рабочий стол и Dock → Окна. SnapDeck после этого полностью отвечает за край.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Клавиатурные сочетания SnapDeck работают независимо от этой настройки.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Label("Приватность", systemImage: "hand.raised.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("SnapDeck не содержит сетевого кода, аналитики и телеметрии. Заголовки окон и их координаты обрабатываются только в памяти на этом Mac.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Сборка")
                            .font(.system(size: 13, weight: .semibold))
                        diagnosticRow("Версия", appVersion)
                        diagnosticRow("Bundle ID", Bundle.main.bundleIdentifier ?? "—")
                        diagnosticRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
                        diagnosticRow("Архитектура", architecture)
                        Text("Если после пересборки изменилась подпись, macOS может попросить выдать Accessibility заново. Это нормально для ad-hoc сборки.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity)
        }
    }

    private var architecture: String {
        #if arch(arm64)
        "Apple Silicon (arm64)"
        #else
        "Intel (x86_64)"
        #endif
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func openDesktopSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
