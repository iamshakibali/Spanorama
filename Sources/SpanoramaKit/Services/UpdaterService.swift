import Foundation

/// Semantic-ish version comparison for GitHub release tags ("v0.2.0", "0.1.10").
public enum UpdateCheck {
    /// Parses "v1.2.3" / "1.2" / "v1" into (major, minor, patch); malformed parts become 0.
    public static func parse(_ version: String) -> (Int, Int, Int) {
        var body = version
        if body.hasPrefix("v") || body.hasPrefix("V") {
            body = String(body.dropFirst())
        }
        let parts = body.split(separator: ".").prefix(3)
        let numbers = parts.map { Int($0) ?? 0 }
        var result = (0, 0, 0)
        for (index, value) in numbers.enumerated() {
            switch index {
            case 0: result.0 = value
            case 1: result.1 = value
            case 2: result.2 = value
            default: break
            }
        }
        return result
    }

    /// True when `candidate` is strictly newer than `current`.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let new = parse(candidate)
        let old = parse(current)
        return new > old
    }
}

/// A GitHub release as returned by /repos/{owner}/{repo}/releases/latest.
public struct GitHubRelease: Codable, Equatable {
    public struct Asset: Codable, Equatable {
        public let name: String
        public let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let name: String?
    public let htmlURL: String
    public let body: String?
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case assets
    }

    public var dmgAsset: Asset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}

/// Talks to the GitHub Releases API and downloads release assets.
public final class UpdaterService {
    public let repository: String
    private let session: URLSession

    public init(repository: String = "iamshakibali/Spanorama", session: URLSession = .shared) {
        self.repository = repository
        self.session = session
    }

    /// The latest stable (non-prerelease) release.
    public func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.fetchFailed
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    /// Downloads the release's DMG into a temp directory and returns its URL.
    public func downloadDMG(of release: GitHubRelease) async throws -> URL {
        guard let asset = release.dmgAsset, let url = URL(string: asset.browserDownloadURL) else {
            throw UpdateError.dmgNotFound
        }
        let (temporary, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Spanorama.dmg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    public enum UpdateError: LocalizedError {
        case fetchFailed
        case dmgNotFound
        case downloadFailed

        public var errorDescription: String? {
            switch self {
            case .fetchFailed: return "Could not reach GitHub to check for updates."
            case .dmgNotFound: return "The new release has no DMG attached."
            case .downloadFailed: return "The update download failed."
            }
        }
    }
}
