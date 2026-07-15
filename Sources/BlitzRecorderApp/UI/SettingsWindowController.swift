import AppKit
import Observation
import SwiftUI

enum SettingsPane: Int, CaseIterable, Identifiable {
    case recording
    case devices
    case permissions
    case account

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .recording: return "Recording"
        case .devices: return "Devices"
        case .permissions: return "Access"
        case .account: return "Account"
        }
    }

    var symbolName: String {
        switch self {
        case .recording: return "slider.horizontal.3"
        case .devices: return "iphone.gen3"
        case .permissions: return "lock.shield"
        case .account: return "person.crop.circle"
        }
    }
}

@MainActor
@Observable
private final class SettingsNavigation {
    let viewModel: RecorderViewModel
    var selectedPane: SettingsPane = .recording

    init(viewModel: RecorderViewModel) {
        self.viewModel = viewModel
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let navigation: SettingsNavigation

    init(viewModel: RecorderViewModel) {
        navigation = SettingsNavigation(viewModel: viewModel)
        let rootView = SettingsRootView(navigation: navigation)
            .preferredColorScheme(.dark)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask.remove(.resizable)
        window.setContentSize(SettingsRootView.contentSize)
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func select(_ pane: SettingsPane) {
        navigation.selectedPane = pane
    }
}

private struct SettingsRootView: View {
    static let contentSize = NSSize(width: 1_040, height: 720)

    @Bindable var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(Color.white.opacity(0.06))

            detail
        }
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            ForEach(SettingsPane.allCases) { pane in
                sidebarButton(pane)
            }

            Spacer(minLength: 24)

            Text("Changes save automatically")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
        }
        .padding(12)
        .padding(.top, 8)
        .frame(width: 178)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
    }

    private func sidebarButton(_ pane: SettingsPane) -> some View {
        let isSelected = navigation.selectedPane == pane
        let issueCount = pane == .permissions
            ? navigation.viewModel.recordingReadiness.blockers.count
            : 0

        return Button {
            navigation.selectedPane = pane
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pane.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? BlitzUI.mint : .secondary)
                    .frame(width: 18)

                Text(pane.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if issueCount > 0 {
                    Text("\(issueCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.8))
                        .frame(minWidth: 17, minHeight: 17)
                        .background(BlitzUI.warning, in: .circle)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                isSelected ? Color.white.opacity(0.10) : .clear,
                in: .rect(cornerRadius: 8)
            )
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selectedPane {
        case .recording:
            ScrollView {
                RecordingSettingsPage(vm: navigation.viewModel)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .devices:
            RemoteCameraPage(vm: navigation.viewModel)
        case .permissions:
            ScrollView {
                PermissionsPage(vm: navigation.viewModel)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .account:
            BlitzReelsCreatorPage(access: navigation.viewModel.accessController)
        }
    }
}
