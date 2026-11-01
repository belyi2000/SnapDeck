import SnapDeckCore
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case zones
    case trackpad
    case access

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Общее"
        case .zones: "Зоны"
        case .trackpad: "Трекпад"
        case .access: "Доступ"
        }
    }

    var symbol: String {
        switch self {
        case .general: "switch.2"
        case .zones: "rectangle.3.group"
        case .trackpad: "hand.draw"
        case .access: "lock.shield"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var trackpad: TrackpadGestureController
    let onRestartMonitoring: () -> Void

    @State private var selection: SettingsSection

    init(
        settings: AppSettings,
        permissions: PermissionManager,
        trackpad: TrackpadGestureController,
        onRestartMonitoring: @escaping () -> Void,
        initialSection: SettingsSection = .general
    ) {
        self.settings = settings
        self.permissions = permissions
        self.trackpad = trackpad
        self.onRestartMonitoring = onRestartMonitoring
        _selection = State(initialValue: initialSection)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.snapDeck)
        .accentColor(.snapDeck)
        .frame(minWidth: 800, minHeight: 560)
        .onAppear {
            permissions.refresh()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppMark(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SnapDeck")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Управление окнами")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 22)

            Text("НАСТРОЙКИ")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 18)
                .padding(.bottom, 7)

            VStack(spacing: 3) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarRow(section)
                }
            }
            .padding(.horizontal, 9)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Divider()
                HStack(spacing: 7) {
                    Circle()
                        .fill(permissions.accessibilityGranted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(permissions.accessibilityGranted ? "Доступ выдан" : "Нужен доступ")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("v\(version)")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 13)
            }
        }
        .frame(width: 200)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.55))
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selection == section ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                selection == section ? Color.snapDeck : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            GeneralSettingsView(
                settings: settings,
                permissions: permissions
            )
        case .zones:
            ZonesSettingsView(settings: settings)
        case .trackpad:
            TrackpadSettingsView(
                settings: settings,
                permissions: permissions,
                trackpad: trackpad
            )
        case .access:
            AccessSettingsView(
                permissions: permissions,
                onRestartMonitoring: onRestartMonitoring
            )
        }
    }
}
