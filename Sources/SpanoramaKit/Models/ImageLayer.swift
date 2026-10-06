import Foundation
import CoreGraphics

/// One image placed on the canvas. Coordinates are in global screen points
/// (origin at the bottom-left of the main display), so layer positions stay
/// stable when displays connect or disconnect.
public struct ImageLayer: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    /// Key of the image inside the image store.
    public var imageID: String
    /// Original file name, shown in the UI only.
    public var originalName: String
    /// Placement rect in global screen coordinates.
    public var frame: CGRect
    public var mode: FillMode = .fill
    /// Higher values draw on top.
    public var zOrder: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, imageID, originalName, frame, mode, zOrder
    }

    public init(id: UUID = UUID(), imageID: String, originalName: String, frame: CGRect, mode: FillMode = .fill, zOrder: Int = 0) {
        self.id = id
        self.imageID = imageID
        self.originalName = originalName
        self.frame = frame
        self.mode = mode
        self.zOrder = zOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageID = try container.decode(String.self, forKey: .imageID)
        originalName = try container.decode(String.self, forKey: .originalName)
        frame = try container.decode(CGRect.self, forKey: .frame)
        mode = try container.decodeIfPresent(FillMode.self, forKey: .mode) ?? .fill
        zOrder = try container.decodeIfPresent(Int.self, forKey: .zOrder) ?? 0
    }
}

/// The persisted editing state: which images are placed where.
public struct CanvasDocument: Codable, Equatable {
    public var layers: [ImageLayer] = []
    public var background: CodableColor = .init(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)

    public init(layers: [ImageLayer] = [], background: CodableColor = .init(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)) {
        self.layers = layers
        self.background = background
    }
}
