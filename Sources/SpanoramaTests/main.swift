import Foundation
import CoreGraphics
import ImageIO
import SpanoramaKit

// Minimal test runner: Command Line Tools ships neither XCTest nor a working
// swift-testing macro plugin, so verification runs as a plain executable.
// Exits non-zero when any check fails.

final class TestRunner {
    var failures: [String] = []
    var passed = 0

    func check(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        if condition {
            passed += 1
        } else {
            failures.append("\(file):\(line) — \(message)")
        }
    }

    @discardableResult
    func run(_ name: String, _ body: (TestRunner) -> Void) -> TestRunner {
        let before = failures.count
        body(self)
        if failures.count == before {
            print("✔ \(name)")
        } else {
            print("✘ \(name)")
            for failure in failures.dropFirst(before) {
                print("    \(failure)")
            }
        }
        return self
    }
}

func approxEqual(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.origin.x - b.origin.x) < 0.0001
        && abs(a.origin.y - b.origin.y) < 0.0001
        && abs(a.size.width - b.size.width) < 0.0001
        && abs(a.size.height - b.size.height) < 0.0001
}

// MARK: - CanvasGeometry

let runner = TestRunner()

runner.run("CanvasGeometry: union bounds") { t in
    t.check(
        CanvasGeometry.unionBounds(of: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]) == CGRect(x: 0, y: 0, width: 1920, height: 1080),
        "single screen"
    )
    t.check(
        CanvasGeometry.unionBounds(of: [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        ]) == CGRect(x: -1920, y: 0, width: 3840, height: 1080),
        "display to the left has negative origin"
    )
    t.check(
        CanvasGeometry.unionBounds(of: [
            CGRect(x: 0, y: 0, width: 2560, height: 1440),
            CGRect(x: 2560, y: 200, width: 1080, height: 1920)
        ]) == CGRect(x: 0, y: 0, width: 3640, height: 2120),
        "stacked mixed sizes"
    )
    t.check(CanvasGeometry.unionBounds(of: []) == nil, "empty")
}

runner.run("CanvasGeometry: local frames") { t in
    let union = CGRect(x: -1920, y: 0, width: 3840, height: 1080)
    let left = CanvasGeometry.localFrame(for: CGRect(x: -1920, y: 0, width: 1920, height: 1080), in: union)
    let right = CanvasGeometry.localFrame(for: CGRect(x: 0, y: 0, width: 1920, height: 1080), in: union)
    t.check(left == CGRect(x: 0, y: 0, width: 1920, height: 1080), "left screen localizes to 0")
    t.check(right == CGRect(x: 1920, y: 0, width: 1920, height: 1080), "right screen localizes to union width/2")
    let union2 = CGRect(x: 0, y: 0, width: 1920, height: 2160)
    let top = CanvasGeometry.localFrame(for: CGRect(x: 0, y: 1080, width: 1920, height: 1080), in: union2)
    t.check(top == CGRect(x: 0, y: 1080, width: 1920, height: 1080), "screen above main keeps positive y")
}

// MARK: - AspectMath

runner.run("AspectMath: modes") { t in
    let square = CGRect(x: 0, y: 0, width: 100, height: 100)
    t.check(AspectMath.drawRect(imageAspect: 2, in: square, mode: .stretch) == square, "stretch exact")
    t.check(
        approxEqual(AspectMath.drawRect(imageAspect: 2, in: square, mode: .fit), CGRect(x: 0, y: 25, width: 100, height: 50)),
        "fit wide image letterboxes"
    )
    t.check(
        approxEqual(AspectMath.drawRect(imageAspect: 2, in: square, mode: .fill), CGRect(x: -50, y: 0, width: 200, height: 100)),
        "fill wide image overflows horizontally"
    )
    t.check(
        approxEqual(AspectMath.drawRect(imageAspect: 0.5, in: square, mode: .fit), CGRect(x: 25, y: 0, width: 50, height: 100)),
        "fit tall image letterboxes"
    )
    t.check(
        approxEqual(AspectMath.drawRect(imageAspect: 0.5, in: square, mode: .fill), CGRect(x: 0, y: -50, width: 100, height: 200)),
        "fill tall image overflows vertically"
    )
    let zero = CGRect(x: 0, y: 0, width: 0, height: 100)
    t.check(AspectMath.drawRect(imageAspect: 2, in: zero, mode: .fill) == zero, "degenerate rect falls back")
}

// MARK: - Rendering (exercises the real CGContext pipeline)

runner.run("WallpaperApplier: render") { t in
    // Build a 2x1 red-on-blue panorama PNG in a temp store.
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SpanoramaTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let panoramaURL = dir.appendingPathComponent("pano.png")
    let panorama = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    panorama.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
    panorama.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    panorama.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
    panorama.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
    let panoImage = panorama.makeImage()!
    let destination = CGImageDestinationCreateWithURL(panoramaURL as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, panoImage, nil)
    CGImageDestinationFinalize(destination)

    let store = try! ImageStore(directory: dir.appendingPathComponent("images"))
    let key = try! store.store(from: panoramaURL)

    // Two 100x100-pt screens side by side, both @1x.
    let screens = [
        ScreenInfo(id: "1", frame: CGRect(x: 0, y: 0, width: 100, height: 100), name: "Left", scaleFactor: 1, isMain: true),
        ScreenInfo(id: "2", frame: CGRect(x: 100, y: 0, width: 100, height: 100), name: "Right", scaleFactor: 1, isMain: false)
    ]
    let union = CanvasGeometry.unionBounds(of: screens.map(\.frame))!

    var document = CanvasDocument()
    document.layers = [ImageLayer(imageID: key, originalName: "pano.png", frame: union, mode: .fill, zOrder: 1)]

    // Left half of the rendered left screen must be red, right half blue.
    let leftRender = WallpaperApplier.renderWallpaper(for: screens[0], canvasBounds: union, document: document, imageStore: store)!
    t.check(leftRender.width == 100 && leftRender.height == 100, "left render is 100x100 px, got \(leftRender.width)x\(leftRender.height)")

    func pixelColor(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        var data = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        return (Int(data[0]), Int(data[1]), Int(data[2]))
    }

    let leftPixel = pixelColor(leftRender, x: 10, y: 50)
    t.check(leftPixel.r > 200 && leftPixel.b < 50, "left screen shows red half, got rgb\(leftPixel)")
    // The panorama's red→blue seam sits at canvas x=100, i.e. exactly at the
    // boundary between the two screens: canvas x=99 must still be red.
    let seamLeftPixel = pixelColor(leftRender, x: 99, y: 50)
    t.check(seamLeftPixel.r > 200 && seamLeftPixel.b < 50, "canvas x=99 still red (seam hasn't crossed yet), got rgb\(seamLeftPixel)")

    let rightRender = WallpaperApplier.renderWallpaper(for: screens[1], canvasBounds: union, document: document, imageStore: store)!
    let rightLeftPixel = pixelColor(rightRender, x: 10, y: 50)
    t.check(rightLeftPixel.b > 200 && rightLeftPixel.r < 50, "right screen starts with blue (seam continues), got rgb\(rightLeftPixel)")

    // Retina screen should render at 2x pixel dimensions.
    let retina = ScreenInfo(id: "3", frame: CGRect(x: 0, y: 0, width: 100, height: 100), name: "Retina", scaleFactor: 2, isMain: true)
    let retinaRender = WallpaperApplier.renderWallpaper(for: retina, canvasBounds: union, document: document, imageStore: store)!
    t.check(retinaRender.width == 200 && retinaRender.height == 200, "retina render is 200x200 px, got \(retinaRender.width)x\(retinaRender.height)")
}

// MARK: - Coding

runner.run("ImageLayer coding") { t in
    var document = CanvasDocument()
    document.background = CodableColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
    document.layers = [
        ImageLayer(imageID: "a.png", originalName: "a.png", frame: CGRect(x: 1, y: 2, width: 30, height: 40), mode: .fit, zOrder: 3)
    ]
    let data = try! JSONEncoder().encode(document)
    let decoded = try! JSONDecoder().decode(CanvasDocument.self, from: data)
    t.check(decoded == document, "document round-trips")

    // CGRect encodes as [[x, y], [width, height]]; mode and zOrder are optional.
    let json = """
    {"id":"11223344-5566-7788-99AA-BBCCDDEEFF01","imageID":"x.png","originalName":"x.png","frame":[[0,0],[10,10]]}
    """
    let layer = try! JSONDecoder().decode(ImageLayer.self, from: Data(json.utf8))
    t.check(layer.mode == .fill, "missing mode defaults to fill")
    t.check(layer.zOrder == 0, "missing zOrder defaults to 0")
}

// MARK: - ImageStore

runner.run("ImageStore") { t in
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SpanoramaStore-\(UUID().uuidString)", isDirectory: true)
    let store = try! ImageStore(directory: dir)
    defer { try? FileManager.default.removeItem(at: dir) }

    let source = dir.appendingPathComponent("src.png")
    let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(source as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)

    let key = try! store.store(from: source)
    t.check(store.image(for: key) != nil, "stored image loads")
    t.check(store.url(for: key).isFileURL, "store key maps to file URL")
    store.remove(key)
    t.check(store.image(for: key) == nil, "removed image no longer loads")
}

// MARK: - UpdateCheck

runner.run("UpdateCheck: version comparison") { t in
    t.check(UpdateCheck.isNewer("v0.2.0", than: "0.1.0"), "v0.2.0 is newer than 0.1.0")
    t.check(!UpdateCheck.isNewer("v0.1.0", than: "0.1.0"), "equal versions are not newer")
    t.check(!UpdateCheck.isNewer("v0.1.0", than: "0.2.0"), "older version is not newer")
    t.check(UpdateCheck.isNewer("v0.1.10", than: "v0.1.9"), "numeric comparison, not lexicographic")
    t.check(UpdateCheck.isNewer("0.2", than: "v0.1.9"), "missing parts padded as zero")
    t.check(UpdateCheck.isNewer("1.0", than: "0.9.9"), "major bump wins")
    t.check(!UpdateCheck.isNewer("garbage", than: "0.1.0"), "malformed candidate parses as 0.0.0")
    t.check(UpdateCheck.parse("v1.2.3") == (1, 2, 3), "parse strips v prefix")
}

print("\n\(runner.passed) checks passed, \(runner.failures.count) failed")
exit(runner.failures.isEmpty ? 0 : 1)
