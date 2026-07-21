import AppKit

#if DIRECT_DISTRIBUTION
import Sparkle
#endif

@MainActor
final class AppUpdateController: NSObject {
    static let releaseNotesURL = URL(string: "https://github.com/blitzreels/blitzrecorder/releases/latest")!

    nonisolated static func hasSparkleConfiguration(feedURLString: String?, publicKey: String?) -> Bool {
        guard let feedURLString,
              let feedURL = URL(string: feedURLString),
              feedURL.scheme == "https",
              let publicKey,
              !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    private(set) var isCheckingForUpdates = false
    var onStateChange: (() -> Void)?

#if DIRECT_DISTRIBUTION
    private var updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?
#endif
    private var checkWindowController: UpdateCheckWindowController?
    private var hasStarted = false

    override init() {
        super.init()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startAutomaticUpdatesIfConfigured()
    }

    var canCheckForUpdates: Bool {
        guard !isCheckingForUpdates else { return false }
#if DIRECT_DISTRIBUTION
        return updaterController?.updater.canCheckForUpdates ?? true
#else
        return true
#endif
    }

    @objc func checkForUpdates(_ sender: Any?) {
#if DIRECT_DISTRIBUTION
        if let updaterController {
            beginManualCheck()
            updaterController.updater.checkForUpdates()
            return
        }

        showUnavailableBuildAlert()
#else
        openAppStoreUpdatesPage()
#endif
    }

    @objc func openReleaseNotes(_ sender: Any?) {
        NSWorkspace.shared.open(Self.releaseNotesURL)
    }

    private func startAutomaticUpdatesIfConfigured() {
#if DIRECT_DISTRIBUTION
        guard Self.hasSparkleConfiguration else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        updaterController = controller
        controller.startUpdater()
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.onStateChange?()
            }
        }

        guard controller.updater.automaticallyChecksForUpdates else { return }
        setChecking(true)
        controller.updater.checkForUpdatesInBackground()
#endif
    }

    private func beginManualCheck() {
        setChecking(true)
        if checkWindowController == nil {
            checkWindowController = UpdateCheckWindowController()
        }
        checkWindowController?.present()
    }

    private func finishCheck() {
        checkWindowController?.dismiss()
        setChecking(false)
    }

    private func setChecking(_ isChecking: Bool) {
        guard isCheckingForUpdates != isChecking else { return }
        isCheckingForUpdates = isChecking
        onStateChange?()
    }

#if DIRECT_DISTRIBUTION
    private static var hasSparkleConfiguration: Bool {
        hasSparkleConfiguration(
            feedURLString: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        )
    }

    private func showUnavailableBuildAlert() {
        let alert = NSAlert()
        alert.messageText = "Updates are unavailable in this build"
        alert.informativeText = "This development build has no signed update feed. "
            + "Release builds check automatically when BlitzRecorder opens."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "View Releases")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.releaseNotesURL)
        }
    }
#else
    private func openAppStoreUpdatesPage() {
        let updatesURL = URL(string: "macappstore://showUpdatesPage")
        let fallbackURL = URL(string: "https://apps.apple.com/account/subscriptions")
        if let url = updatesURL ?? fallbackURL {
            NSWorkspace.shared.open(url)
        }
    }
#endif
}

#if DIRECT_DISTRIBUTION
@MainActor
extension AppUpdateController: SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        finishCheck()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        finishCheck()
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        finishCheck()
    }

    nonisolated func standardUserDriverWillShowModalAlert() {
        Task { @MainActor [weak self] in
            self?.finishCheck()
        }
    }
}
#endif

@MainActor
private final class UpdateCheckWindowController: NSWindowController {
    private let progressIndicator = NSProgressIndicator()

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 132),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "BlitzRecorder"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: panel)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func present() {
        progressIndicator.startAnimation(nil)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        progressIndicator.stopAnimation(nil)
        close()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Checking for Updates…")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(labelWithString: "Looking for the latest BlitzRecorder version.")
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(progressIndicator)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            progressIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            progressIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: progressIndicator.trailingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            detailLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 7)
        ])
    }
}
