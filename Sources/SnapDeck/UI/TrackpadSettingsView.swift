import AppKit
import SnapDeckCore
import SwiftUI

struct TrackpadSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var trackpad: TrackpadGestureController

    @State private var isWorking = false

    private var status: (title: String, color: Color) {
        if !settings.trackpadGesturesEnabled {
            return ("Выключено", .secondary)
        }
        if !permissions.accessibilityGranted {
            return ("Нет доступа", .orange)
        }
        if trackpad.isRunning {
            return ("Активно", .green)
        }
        return ("Не запущено", .orange)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !permissions.accessibilityGranted {
                    PermissionBanner(
                        title: "Нужен доступ Accessibility",
                        message: "Без него SnapDeck не сможет получать касания трекпада и управлять окнами.",
                        buttonTitle: "Разрешить",
                        action: {
                            permissions.requestAccessibilityPermission()
                            permissions.openAccessibilitySettings()
                        }
                    )
                }

                controlCard
                gesturesCard
                sensitivityCard
                diagnosticsCard
                Spacer(minLength: 4)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            trackpad.refreshStatus()
            if settings.trackpadGesturesEnabled {
                trackpad.startIfEnabled()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 67, height: 67)
                .background(
                    LinearGradient(
                        colors: [.indigo, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .blue.opacity(0.24), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Text("Трекпад")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    StatusBadge(title: status.title, color: status.color)
                }
                Text("Три и четыре пальца управляют окнами напрямую — без модификаторов и лишних движений.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.12),
                            Color(nsColor: .controlBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var controlCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                if settings.trackpadGesturesEnabled {
                    HStack(spacing: 11) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Жесты трекпада включены")
                                .font(.system(size: 13, weight: .semibold))
                            Text("SnapDeck слушает 3–4 касания и подавляет конфликтующие scroll/swipe события.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Выключить") {
                            isWorking = true
                            trackpad.disableAndRestoreSystemGestures()
                            trackpad.refreshStatus()
                            isWorking = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !trackpad.systemGesturesManaged {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Системные свайпы macOS не отключены — они могут срабатывать одновременно с SnapDeck.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Настроить") {
                                _ = trackpad.enableWithSystemSetup()
                                trackpad.refreshStatus()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Text("Конфликтующие системные свайпы macOS отключены. Оригинальные настройки сохраняются до выключения жестов.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(.indigo)
                            .frame(width: 42, height: 42)
                            .background(.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Включить жесты трекпада")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Для свайпов SnapDeck нужно один раз отключить встроенные свайпы macOS для Mission Control, App Exposé и переключения приложений. SnapDeck сохранит исходные значения, сможет вернуть их и один раз перезапустит Dock, чтобы настройки применились.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            guard permissions.accessibilityGranted else {
                                permissions.requestAccessibilityPermission()
                                permissions.openAccessibilitySettings()
                                return
                            }
                            isWorking = true
                            _ = trackpad.enableWithSystemSetup()
                            trackpad.refreshStatus()
                            isWorking = false
                        } label: {
                            HStack(spacing: 6) {
                                if isWorking {
                                    ProgressView().controlSize(.mini)
                                }
                                Text(isWorking ? "Настраиваю…" : "Включить жесты")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(isWorking)
                    }

                    if trackpad.threeFingerDragEnabled {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Включён «Перетаскивание тремя пальцами» в Универсальном доступе. Он будет мешать свайпам — лучше отключить.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var gesturesCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Жесты")
                    .font(.system(size: 13, weight: .semibold))
                Text("Свайп должен быть уверенным и прямым. Диагонали, pinch и случайные касания игнорируются.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    GestureRow(gesture: "3 пальца влево / вправо", action: "Прижать к половине", symbol: "arrow.left.and.right")
                    GestureRow(gesture: "3 пальца вверх", action: "Развернуть окно", symbol: "arrow.up")
                    GestureRow(gesture: "3 пальца вниз", action: "Свернуть активное окно", symbol: "arrow.down")
                    GestureRow(gesture: "4 пальца вверх", action: "Развернуть все свёрнутые окна", symbol: "arrow.up.to.line")
                    GestureRow(gesture: "4 пальца вниз", action: "Свернуть все окна", symbol: "rectangle.stack")
                    GestureRow(gesture: "4 пальца вправо, длинный свайп", action: "Закрыть приложение", symbol: "xmark.rectangle")
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle")
                    Text("Для закрытия приложения свайп вправо должен быть заметно длиннее остальных. Короткий свайп и свайп влево ничего не делают. Приложение закрывается обычным завершением — если документ не сохранён, macOS предложит сохранить.")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sensitivityCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Чувствительность свайпа")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.0f%%", settings.trackpadGestureSensitivity * 100))
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $settings.trackpadGestureSensitivity,
                    in: 0.6...1.6,
                    step: 0.05
                )
                Text("Выше — короче свайп для срабатывания. Если жесты срабатывают случайно, уменьшите значение.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var diagnosticsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Состояние")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("Проверить") {
                        trackpad.refreshStatus()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10.5, weight: .semibold))
                }

                diagnosticRow(
                    "Устройство",
                    trackpad.deviceAvailable ? "MultitouchSupport доступен" : "Недоступно",
                    color: trackpad.deviceAvailable ? .green : .orange
                )
                diagnosticRow(
                    "Gesture engine",
                    trackpad.isRunning ? "Работает" : "Остановлен",
                    color: trackpad.isRunning ? .green : .secondary
                )
                diagnosticRow(
                    "Подавление событий",
                    trackpad.suppressionRunning ? "Включено" : "Выключено",
                    color: trackpad.suppressionRunning ? .green : .secondary
                )
                diagnosticRow(
                    "Системные свайпы",
                    trackpad.systemGesturesManaged ? "Отключены SnapDeck" : "Активны",
                    color: trackpad.systemGesturesManaged ? .green : .orange
                )
                diagnosticRow(
                    "Пальцев сейчас",
                    "\(trackpad.liveFingerCount)",
                    color: .secondary
                )

                if trackpad.threeFingerDragEnabled {
                    Label(
                        "Включён «Перетаскивание тремя пальцами» в Универсальном доступе — он конфликтует со свайпами SnapDeck.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
                }

                if let error = trackpad.lastError {
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Жесты используют приватный MultitouchSupport и доступны только вне Mac App Store. SnapDeck не отправляет данные о касаниях в сеть.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func diagnosticRow(_ title: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
    }
}
