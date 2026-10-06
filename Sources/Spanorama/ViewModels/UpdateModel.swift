import AppKit
import Combine
import Foundation
import SpanoramaKit

/// Drives update checking against GitHub Releases: manual "Check for Updates",
/// automatic checks (on launch + every 6 hours), skip-version, and
/// download-and-open for the found release.
@MainActor
final class UpdateModel: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(GitHubRelease)
        case downloading
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// True whenever a release becomes available — drives the update dialog.
    @Published var showDialog = false

    static let autoCheckKey = "autoCheckUpdates"
    private static let skippedVersionKey = "skippedUpdateVersion"

    private let service = UpdaterService()
    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var availableRelease: GitHubRelease? {
        if case .available(let release) = state { return release }
        return nil
    }

    var statusMessage: String? {
        switch state {
        case .idle: return nil
        case .checking: return "Checking for updates…"
        case .upToDate: return "You're up to date (v\(currentVersion))."
        case .available(let release): return "\(release.tagName) is available — you have v\(currentVersion)."
        case .downloading: return "Downloading update…"
        case .failed(let message): return message
        }
    }

    init() {
        // Check shortly after launch, then every 6 hours while running.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await self?.autoCheck()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.autoCheck()
            }
        }
    }

    // MARK: - Actions

    /// Manual "Check for Updates" from Settings — ignores skip-version.
    func checkNow() {
        Task { await check(showUpToDate: true, respectSkip: false, presentDialog: false) }
    }

    /// Automatic background check — respects the setting and skipped versions,
    /// and presents the dialog when something newer is found.
    func autoCheck() async {
        guard UserDefaults.standard.bool(forKey: Self.autoCheckKey) else { return }
        await check(showUpToDate: false, respectSkip: true, presentDialog: true)
    }

    func downloadAndOpen() async {
        guard let release = availableRelease else { return }
        state = .downloading
        do {
            let dmgURL = try await service.downloadDMG(of: release)
            state = .idle
            NSWorkspace.shared.open(dmgURL)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func skipCurrentRelease() {
        guard let release = availableRelease else { return }
        UserDefaults.standard.set(release.tagName, forKey: Self.skippedVersionKey)
        state = .idle
        showDialog = false
    }

    func dismissDialog() {
        showDialog = false
    }

    // MARK: - Internals

    private func check(showUpToDate: Bool, respectSkip: Bool, presentDialog: Bool) async {
        state = .checking
        do {
            let release = try await service.fetchLatestRelease()
            guard UpdateCheck.isNewer(release.tagName, than: currentVersion) else {
                state = .upToDate
                return
            }
            let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey)
            if respectSkip && release.tagName == skipped {
                state = .idle
                return
            }
            state = .available(release)
            if presentDialog { showDialog = true }
        } catch {
            // Silent for background checks; visible for manual ones.
            if !respectSkip {
                state = .failed(error.localizedDescription)
            } else {
                state = .idle
            }
        }
    }
}
