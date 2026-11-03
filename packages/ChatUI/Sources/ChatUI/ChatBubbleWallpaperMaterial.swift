import AppKit
import CoreImage
import Accelerate
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

    static let incomingGlassReference = NSColor(0x3B3B3D)
    static let incomingOutlineColor = NSColor.white.withAlphaComponent(0.18)

    static func isActive(_ presentation: TelegramPresentationTheme, hasBubble: Bool, liteBlur: Bool) -> Bool {
        return hasBubble && presentation.bubbled && presentation.liquidGlass && !liteBlur && presentation.hasWallpaper
    }


    static func legible(_ color: NSColor, on background: NSColor, minimum: CGFloat = 4.5) -> NSColor {
        var result = color
        var fraction: CGFloat = 0
        while contrastRatio(result, background) < minimum, fraction < 1 {
            fraction = min(1, fraction + 0.1)
            result = color.blended(withFraction: fraction, of: .white) ?? result
        }
        return result
    }

    static func frostedFill(_ color: NSColor) -> NSColor {
        return (color.blended(withFraction: 0.45, of: .white) ?? color).withAlphaComponent(0.22)
    }

    private static let contentThemeLock = NSLock()
    private static var lastContentTheme: (source: TelegramPresentationTheme, theme: TelegramPresentationTheme)?

    static func contentTheme(for presentation: TelegramPresentationTheme, liteBlur: Bool) -> TelegramPresentationTheme {
        guard !presentation.colors.isDark, isActive(presentation, hasBubble: true, liteBlur: liteBlur) else {
            return presentation
        }
        contentThemeLock.lock()
        defer {
            contentThemeLock.unlock()
        }
        if let cached = lastContentTheme, cached.source === presentation {
            return cached.theme
        }
        let source = presentation.colors
        let palette = darkPalette.withAccentColor(PaletteAccentColor(source.accent, source.bubbleBackground_outgoing), disableTint: true)
        let theme = generateTheme(palette: palette, cloudTheme: nil, bubbled: presentation.bubbled, fontSize: presentation.fontSize, wallpaper: presentation.wallpaper, backgroundSize: presentation.backgroundSize, liquidGlass: presentation.liquidGlass)
        lastContentTheme = (presentation, theme)
        return theme
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

    private struct Raster {
        let pixels: UnsafeMutableRawPointer
        let width: Int
        let height: Int
        let rowBytes: Int

        func deallocate() {
            pixels.deallocate()
        }
    }

    private final class Snapshot {
        weak var view: BackgroundView?
        let key: SnapshotKey
        let canvasSize: NSSize
        let materialScale: CGFloat
        let padding: Int
        let blurred: Raster
        let luminance: Raster
        let colorSpace: CGColorSpace

        init(view: BackgroundView, key: SnapshotKey, canvasSize: NSSize, materialScale: CGFloat, padding: Int, blurred: Raster, luminance: Raster, colorSpace: CGColorSpace) {
            self.view = view
            self.key = key
            self.canvasSize = canvasSize
            self.materialScale = materialScale
            self.padding = padding
            self.blurred = blurred
            self.luminance = luminance
            self.colorSpace = colorSpace
        }

        deinit {
            blurred.deallocate()
            luminance.deallocate()
        }
    }

    private var snapshots: [ObjectIdentifier: Snapshot] = [:]
    private var snapshotOrder: [ObjectIdentifier] = []
    private let snapshotLimit = 4
    private let luminanceScale: CGFloat = 0.5
    private let matrixDivisor: Int32 = 4096
    private let linearTable: [CGFloat] = (0 ..< 256).map {
        let value = CGFloat($0) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private init() {}

    func materialImage(
        for backgroundView: BackgroundView,
        rect: NSRect,
        style: ChatBubbleWallpaperMaterial.Style,
        luminance: Float,
        bleed: CGFloat = 0
    ) -> (image: CGImage, frame: NSRect)? {
        guard rect.width > 0, rect.height > 0, let snapshot = snapshot(for: backgroundView) else {
            return nil
        }
        let scale = snapshot.materialScale
        let raster = snapshot.blurred
        let padding = CGFloat(snapshot.padding)
        let source = rect.insetBy(dx: -bleed, dy: -bleed)
        let minX = max(0, (source.minX * scale).rounded(.down))
        let minY = max(-padding, (source.minY * scale).rounded(.down))
        let maxX = min(CGFloat(raster.width), (source.maxX * scale).rounded(.up))
        let maxY = min(CGFloat(raster.height) - padding, (source.maxY * scale).rounded(.up))
        guard maxX - minX >= 1, maxY - minY >= 1 else {
            return nil
        }
        let width = Int(maxX - minX)
        let height = Int(maxY - minY)
        guard let output = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: snapshot.colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outputPixels = output.data else {
            return nil
        }
        let values = ChatBubbleWallpaperMaterial.matrix(style: style, luminance: CGFloat(luminance))
        let divisor = CGFloat(matrixDivisor)
        var matrix = [Int16](repeating: 0, count: 16)
        for channel in 0 ..< 4 {
            for source in 0 ..< 4 {
                matrix[source * 4 + channel] = Int16(max(-32768, min(32767, (values[channel * 5 + source] * divisor).rounded())))
            }
        }
        let bias: [Int32] = (0 ..< 4).map { Int32((values[$0 * 5 + 4] * 255 * divisor).rounded()) }
        let sourceRow = Int(minY + padding)
        var sourceBuffer = vImage_Buffer(
            data: raster.pixels + sourceRow * raster.rowBytes + Int(minX) * 4,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: raster.rowBytes
        )
        var outputBuffer = vImage_Buffer(
            data: outputPixels,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: output.bytesPerRow
        )
        guard vImageMatrixMultiply_ARGB8888(&sourceBuffer, &outputBuffer, matrix, matrixDivisor, nil, bias, vImage_Flags(kvImageNoFlags)) == kvImageNoError, let image = output.makeImage() else {
            return nil
        }
        let covered = NSRect(x: minX / scale, y: minY / scale, width: CGFloat(width) / scale, height: CGFloat(height) / scale)
        return (image, covered.offsetBy(dx: -rect.minX, dy: -rect.minY))
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
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else {
            return 0.2
        }
        let raster = snapshot.luminance
        let pixels = raster.pixels.assumingMemoryBound(to: UInt8.self)
        var total: CGFloat = 0
        for row in 0 ..< 4 {
            for column in 0 ..< 8 {
                let x = clipped.minX + (CGFloat(column) + 0.5) * clipped.width / 8
                let y = clipped.minY + (CGFloat(row) + 0.5) * clipped.height / 4
                let px = min(raster.width - 1, max(0, Int(x / snapshot.canvasSize.width * CGFloat(raster.width))))
                let py = min(raster.height - 1, max(0, Int(y / snapshot.canvasSize.height * CGFloat(raster.height))))
                let offset = py * raster.rowBytes + px * 4
                total += linearTable[Int(pixels[offset])] * 0.2126 + linearTable[Int(pixels[offset + 1])] * 0.7152 + linearTable[Int(pixels[offset + 2])] * 0.0722
            }
        }
        return Float(total / 32)
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
        let downsample = ChatBubbleWallpaperMaterial.blurDownsample
        let blurredWidth = max(1, Int((CGFloat(source.width) * downsample).rounded(.down)))
        let blurredHeight = max(1, Int((CGFloat(source.height) * downsample).rounded(.down)))
        let padding = blurredHeight
        let blurred = CIImage(cgImage: source)
            .transformed(by: CGAffineTransform(scaleX: downsample, y: downsample))
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ChatBubbleWallpaperMaterial.blurRadius * key.scale * downsample])
        let blurredRaster = Raster(
            pixels: UnsafeMutableRawPointer.allocate(byteCount: blurredWidth * 4 * (blurredHeight + padding * 2), alignment: 16),
            width: blurredWidth,
            height: blurredHeight + padding * 2,
            rowBytes: blurredWidth * 4
        )
        let context = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
        context.render(
            blurred,
            toBitmap: blurredRaster.pixels,
            rowBytes: blurredRaster.rowBytes,
            bounds: CGRect(x: 0, y: -CGFloat(padding), width: CGFloat(blurredWidth), height: CGFloat(blurredHeight + padding * 2)),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        let luminanceWidth = max(1, Int((CGFloat(source.width) * luminanceScale).rounded()))
        let luminanceHeight = max(1, Int((CGFloat(source.height) * luminanceScale).rounded()))
        let luminanceRaster = Raster(
            pixels: UnsafeMutableRawPointer.allocate(byteCount: luminanceWidth * 4 * luminanceHeight, alignment: 16),
            width: luminanceWidth,
            height: luminanceHeight,
            rowBytes: luminanceWidth * 4
        )
        guard let luminanceContext = CGContext(
            data: luminanceRaster.pixels,
            width: luminanceWidth,
            height: luminanceHeight,
            bitsPerComponent: 8,
            bytesPerRow: luminanceRaster.rowBytes,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            blurredRaster.deallocate()
            luminanceRaster.deallocate()
            return nil
        }
        luminanceContext.interpolationQuality = .high
        luminanceContext.draw(source, in: CGRect(x: 0, y: 0, width: luminanceWidth, height: luminanceHeight))
        let snapshot = Snapshot(
            view: view,
            key: key,
            canvasSize: NSSize(width: key.width, height: key.height),
            materialScale: CGFloat(blurredWidth) / key.width,
            padding: padding,
            blurred: blurredRaster,
            luminance: luminanceRaster,
            colorSpace: colorSpace
        )
        snapshots[identifier] = snapshot
        snapshotOrder.removeAll(where: { $0 == identifier })
        snapshotOrder.append(identifier)
        while snapshotOrder.count > snapshotLimit {
            snapshots.removeValue(forKey: snapshotOrder.removeFirst())
        }
        return snapshot
    }
}
