import AppKit
import CoreImage
import ColorPalette
import TGUIKit
import TelegramTheme
import ThemeSettings

final class ChatBubbleWallpaperMaterial {
    enum Style {
        case incoming(tint: NSColor?, tintOpacity: CGFloat)
        case outgoing(tint: NSColor)
    }

    static let blurDownsample: CGFloat = 0.25
    static let blurRadius: CGFloat = 12

    static func isNonStockWallpaper(selected: Wallpaper, themeDefault: Wallpaper) -> Bool {
        guard selected != .none else {
            return false
        }
        return selected != themeDefault
    }

    static func themeDefaultWallpaper(_ presentation: TelegramPresentationTheme) -> Wallpaper {
        return presentation.wallpaper.associated?.wallpaper ?? presentation.colors.wallpaper.wallpaper
    }

    static func isNonStockWallpaper(_ presentation: TelegramPresentationTheme) -> Bool {
        return isNonStockWallpaper(selected: presentation.wallpaper.wallpaper, themeDefault: themeDefaultWallpaper(presentation))
    }

    static func matrix(outgoing: Bool, tint: NSColor, luminance: CGFloat) -> [CGFloat] {
        let light = min(1, max(0, luminance))
        if outgoing {
            let rgb = tint.usingColorSpace(.sRGB) ?? tint.usingColorSpace(.deviceRGB) ?? .white
            let bias = 0.17 + 0.1 * light
            let weights: [CGFloat] = [0.08504, 0.28608, 0.02888, 0]
            return weights + [min(0.97, rgb.redComponent) - bias]
                + weights + [min(0.97, rgb.greenComponent) - bias]
                + weights + [min(0.97, rgb.blueComponent) - bias]
                + [0, 0, 0, 1, 0]
        }
        let index = light * CGFloat(grayBlueWeights.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, grayBlueWeights.count - 1)
        let blue = grayBlueWeights[lower] + (grayBlueWeights[upper] - grayBlueWeights[lower]) * (index - CGFloat(lower))
        let red = -0.03720494 * (1 + light)
        let green = -0.12516013 * (1 + light)
        let bias = 0.125 * (1 - light)
        return [0.8 + red, green, blue, 0, bias,
                red, 0.8 + green, blue, 0, bias,
                red, green, 0.8 + blue, 0, bias,
                0, 0, 0, 1, 0]
    }

    static func matrix(style: Style, luminance: CGFloat) -> [CGFloat] {
        switch style {
        case let .outgoing(tint):
            return matrix(outgoing: true, tint: tint, luminance: luminance)
        case let .incoming(tint, opacity):
            var values = matrix(outgoing: false, tint: .white, luminance: luminance)
            guard let tint, opacity > 0 else {
                return values
            }
            let alpha = min(1, max(0, opacity))
            let rgb = tint.usingColorSpace(.sRGB) ?? tint.usingColorSpace(.deviceRGB) ?? .white
            let overlay: [CGFloat] = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            for channel in 0 ..< 3 {
                let row = channel * 5
                for column in 0 ..< 4 {
                    values[row + column] *= (1 - alpha)
                }
                values[row + 4] = values[row + 4] * (1 - alpha) + overlay[channel] * alpha
            }
            return values
        }
    }

    static func contrastRatio(_ first: NSColor, _ second: NSColor) -> CGFloat {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return 0
        }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map {
            $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }

    static func colorMatrixParameters(_ values: [CGFloat]) -> [String: Any] {
        return [
            "inputRVector": CIVector(x: values[0], y: values[1], z: values[2], w: values[3]),
            "inputGVector": CIVector(x: values[5], y: values[6], z: values[7], w: values[8]),
            "inputBVector": CIVector(x: values[10], y: values[11], z: values[12], w: values[13]),
            "inputAVector": CIVector(x: values[15], y: values[16], z: values[17], w: values[18]),
            "inputBiasVector": CIVector(x: values[4], y: values[9], z: values[14], w: 0)
        ]
    }

    private static let grayBlueWeights: [CGFloat] = [
        0.050365116, 0.045841020, 0.041519698, 0.037396270, 0.033465903, 0.029723700,
        0.026164811, 0.022784363, 0.019577485, 0.016539324, 0.013665002, 0.010949653,
        0.008388419, 0.005976420, 0.003708798, 0.001580697, -0.000412773, -0.002276465,
        -0.004015248, -0.005633991, -0.007137552, -0.008530803, -0.009818614, -0.011005852,
        -0.012097377, -0.013098057, -0.014012761, -0.014846351, -0.015603706, -0.016289681,
        -0.016909145, -0.017466966, -0.017968010, -0.018417142, -0.018819232, -0.019179143,
        -0.019501746, -0.019791905, -0.020054486, -0.020294353, -0.020516377, -0.020725425,
        -0.020926360, -0.021124028, -0.021321450, -0.021518867, -0.021716290, -0.021913711,
        -0.022111136, -0.022308558, -0.022505980, -0.022703398, -0.022900820, -0.023098245,
        -0.023295667, -0.023493089, -0.023690510, -0.023887932, -0.024085354, -0.024282776,
        -0.024480198, -0.024677620, -0.024875041, -0.025072463, -0.025269885
    ]
}

final class ChatBubbleWallpaperMaterialRenderer {
    static let shared = ChatBubbleWallpaperMaterialRenderer()

    private struct SnapshotKey: Equatable {
        let mode: TableBackgroundMode
        let width: CGFloat
        let height: CGFloat
        let scale: CGFloat
    }

    private struct CanvasKey: Hashable {
        let snapshot: Int
        let style: Int
        let tint: UInt32
        let tintAlpha: UInt16
        let luminance: Int
    }

    private final class Snapshot {
        weak var view: BackgroundView?
        let key: SnapshotKey
        let identity: Int
        let canvasSize: NSSize
        let pixelScale: CGFloat
        let blurred: CIImage
        let context: CIContext
        let colorSpace: CGColorSpace
        let luminance: NSBitmapImageRep

        init(view: BackgroundView, key: SnapshotKey, identity: Int, canvasSize: NSSize, pixelScale: CGFloat, blurred: CIImage, context: CIContext, colorSpace: CGColorSpace, luminance: NSBitmapImageRep) {
            self.view = view
            self.key = key
            self.identity = identity
            self.canvasSize = canvasSize
            self.pixelScale = pixelScale
            self.blurred = blurred
            self.context = context
            self.colorSpace = colorSpace
            self.luminance = luminance
        }
    }

    private var snapshots: [ObjectIdentifier: Snapshot] = [:]
    private var snapshotOrder: [ObjectIdentifier] = []
    private var canvases: [CanvasKey: CGImage] = [:]
    private var canvasOrder: [CanvasKey] = []
    private var nextSnapshotIdentity: Int = 0
    private let snapshotLimit = 4
    private let canvasLimit = 24

    private init() {}

    func materialImage(
        for backgroundView: BackgroundView,
        rect: NSRect,
        style: ChatBubbleWallpaperMaterial.Style,
        luminance: Float
    ) -> CGImage? {
        guard rect.width > 0, rect.height > 0 else {
            return nil
        }
        guard let snapshot = snapshot(for: backgroundView) else {
            return nil
        }
        let clamped = CGPoint(x: min(max(rect.minX, 0), snapshot.canvasSize.width),
                              y: min(max(rect.minY, 0), snapshot.canvasSize.height))
        let clipped = NSRect(origin: clamped, size: NSSize(width: min(rect.width, snapshot.canvasSize.width - clamped.x),
                                                         height: min(rect.height, snapshot.canvasSize.height - clamped.y)))
        guard clipped.width > 0, clipped.height > 0 else {
            return nil
        }
        let key = CanvasKey(
            snapshot: snapshot.identity,
            style: style.isOutgoing ? 0 : 1,
            tint: style.tintKey,
            tintAlpha: style.tintAlphaKey,
            luminance: Int((min(1, max(0, CGFloat(luminance))) * 31).rounded())
        )
        let canvas: CGImage
        if let cached = canvases[key] {
            canvas = cached
        } else {
            guard let rendered = renderCanvas(snapshot: snapshot, style: style, luminance: CGFloat(key.luminance) / 31) else {
                return nil
            }
            canvas = rendered
            canvases[key] = rendered
            canvasOrder.append(key)
            while canvasOrder.count > canvasLimit {
                let removed = canvasOrder.removeFirst()
                canvases.removeValue(forKey: removed)
            }
        }
        let scale = snapshot.pixelScale * ChatBubbleWallpaperMaterial.blurDownsample
        let pixelRect = CGRect(
            x: (clipped.minX * scale).rounded(.down),
            y: (clipped.minY * scale).rounded(.down),
            width: max(1, (clipped.width * scale).rounded(.up)),
            height: max(1, (clipped.height * scale).rounded(.up))
        ).intersection(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        guard pixelRect.width >= 1, pixelRect.height >= 1 else {
            return nil
        }
        return canvas.cropping(to: pixelRect)
    }

    func averageColor(of image: CGImage) -> NSColor? {
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return NSColor(
            srgbRed: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
    }

    func luminance(for backgroundView: BackgroundView, rect: NSRect) -> Float {
        guard rect.width > 0, rect.height > 0, let snapshot = snapshot(for: backgroundView) else {
            return 0.2
        }
        let clipped = rect.intersection(CGRect(origin: .zero, size: snapshot.canvasSize))
        guard clipped.width > 0, clipped.height > 0 else {
            return 0.2
        }
        let mapSize = CGFloat(snapshot.luminance.pixelsWide)
        var total: CGFloat = 0
        var samples: CGFloat = 0
        for row in 0 ..< 4 {
            for column in 0 ..< 8 {
                let x = clipped.minX + (CGFloat(column) + 0.5) * clipped.width / 8
                let y = clipped.minY + (CGFloat(row) + 0.5) * clipped.height / 4
                let px = min(snapshot.luminance.pixelsWide - 1, max(0, Int(x / snapshot.canvasSize.width * mapSize)))
                let py = min(snapshot.luminance.pixelsHigh - 1, max(0, Int(y / snapshot.canvasSize.height * mapSize)))
                guard let color = snapshot.luminance.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else {
                    continue
                }
                let linear = [color.redComponent, color.greenComponent, color.blueComponent].map {
                    $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
                }
                total += linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
                samples += 1
            }
        }
        return samples > 0 ? Float(total / samples) : 0.2
    }

    private func snapshot(for view: BackgroundView) -> Snapshot? {
        let key = SnapshotKey(mode: view.backgroundMode, width: view.bounds.width, height: view.bounds.height, scale: view.window?.backingScaleFactor ?? System.backingScale)
        let identifier = ObjectIdentifier(view)
        if let cached = snapshots[identifier], cached.view === view, cached.key == key {
            return cached
        }
        guard key.width > 0, key.height > 0 else {
            return nil
        }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let source = bitmap.cgImage else {
            return nil
        }
        let colorSpace = source.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
        let image = CIImage(cgImage: source)
            .transformed(by: CGAffineTransform(scaleX: ChatBubbleWallpaperMaterial.blurDownsample, y: ChatBubbleWallpaperMaterial.blurDownsample))
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ChatBubbleWallpaperMaterial.blurRadius * key.scale * ChatBubbleWallpaperMaterial.blurDownsample])
            .cropped(to: CGRect(x: 0, y: 0, width: CGFloat(source.width) * ChatBubbleWallpaperMaterial.blurDownsample, height: CGFloat(source.height) * ChatBubbleWallpaperMaterial.blurDownsample))
        let pixelScale = CGFloat(source.width) / key.width
        guard let luminance = makeLuminanceMap(source: source) else {
            return nil
        }
        let snapshot = Snapshot(
            view: view,
            key: key,
            identity: nextSnapshotIdentity,
            canvasSize: NSSize(width: key.width, height: key.height),
            pixelScale: pixelScale,
            blurred: image,
            context: context,
            colorSpace: colorSpace,
            luminance: luminance
        )
        nextSnapshotIdentity += 1
        snapshots[identifier] = snapshot
        snapshotOrder.removeAll(where: { $0 == identifier })
        snapshotOrder.append(identifier)
        while snapshotOrder.count > snapshotLimit {
            snapshots.removeValue(forKey: snapshotOrder.removeFirst())
        }
        return snapshot
    }

    private func makeLuminanceMap(source: CGImage) -> NSBitmapImageRep? {
        let size = 64
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let image = context.makeImage() else {
            return nil
        }
        return NSBitmapImageRep(cgImage: image)
    }

    private func renderCanvas(snapshot: Snapshot, style: ChatBubbleWallpaperMaterial.Style, luminance: CGFloat) -> CGImage? {
        let values = ChatBubbleWallpaperMaterial.matrix(style: style, luminance: luminance)
        let filtered = snapshot.blurred.applyingFilter("CIColorMatrix", parameters: ChatBubbleWallpaperMaterial.colorMatrixParameters(values))
        return snapshot.context.createCGImage(filtered, from: snapshot.blurred.extent)
    }
}

private extension ChatBubbleWallpaperMaterial.Style {
    var isOutgoing: Bool {
        if case .outgoing = self {
            return true
        }
        return false
    }

    var tintKey: UInt32 {
        switch self {
        case let .outgoing(tint), let .incoming(tint?, _):
            return (tint.usingColorSpace(.sRGB) ?? tint).argb
        case .incoming(nil, _):
            return 0
        }
    }

    var tintAlphaKey: UInt16 {
        switch self {
        case .outgoing, .incoming(nil, _):
            return 0
        case let .incoming(_, opacity):
            return UInt16((min(1, max(0, opacity)) * 1000).rounded())
        }
    }
}
