import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Stores copies of the images used in layouts under Application Support,
/// so layouts survive moves/renames/deletions of the original files.
public final class ImageStore {
    public let directory: URL
    private var cache: [String: CGImage] = [:]

    public init(directory: URL? = nil) throws {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Spanorama/Images", isDirectory: true)
        self.directory = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    /// Copies an image file into the store and returns its key.
    public func store(from sourceURL: URL) throws -> String {
        let id = UUID().uuidString
        let ext = sourceURL.pathExtension.isEmpty
            ? "png"
            : sourceURL.pathExtension
        let destination = directory.appendingPathComponent("\(id).\(ext)")
        // Copying (instead of referencing) protects against later moves/deletes
        // of the original file.
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return "\(id).\(ext)"
    }

    public func url(for key: String) -> URL {
        directory.appendingPathComponent(key)
    }

    /// Loads (and caches) the decoded image for a store key.
    public func image(for key: String) -> CGImage? {
        if let cached = cache[key] { return cached }
        let source = CGImageSourceCreateWithURL(url(for: key) as CFURL, nil)
        let image = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        if let image { cache[key] = image }
        return image
    }

    public func remove(_ key: String) {
        cache[key] = nil
        try? FileManager.default.removeItem(at: url(for: key))
    }
}
