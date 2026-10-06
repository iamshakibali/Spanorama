import Foundation

/// Persists the working layout (autosave) and supports JSON export/import.
public enum LayoutStore {
    public static var autosaveURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Spanorama/current-layout.json")
    }

    public static func save(_ document: CanvasDocument, to url: URL? = nil) throws {
        let target = url ?? autosaveURL
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(document)
        try data.write(to: target, options: .atomic)
    }

    public static func load(from url: URL? = nil) -> CanvasDocument? {
        let target = url ?? autosaveURL
        guard let data = try? Data(contentsOf: target) else { return nil }
        return try? JSONDecoder().decode(CanvasDocument.self, from: data)
    }
}
