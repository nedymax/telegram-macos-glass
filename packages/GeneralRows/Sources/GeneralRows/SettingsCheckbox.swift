import Cocoa
import TGUIKit
import TelegramTheme

public enum SettingsCheckbox {
    public static let size: CGFloat = 14
    public static let cornerRadius: CGFloat = 4

    private static var cache: [String: CGImage] = [:]

    public static func selected(_ fill: NSColor = theme.colors.accent) -> CGImage {
        let color = fill.usingColorSpace(.sRGB) ?? fill
        let key = "on-\(color.redComponent)-\(color.greenComponent)-\(color.blueComponent)-\(color.alphaComponent)-\(System.backingScale)"
        if let image = cache[key] {
            return image
        }
        let image = generateImage(NSMakeSize(size, size), rotatedContext: { size, ctx in
            ctx.clear(CGRect(origin: .zero, size: size))
            let rect = CGRect(origin: .zero, size: size)
            ctx.addPath(CGPath.continuousRoundedRect(rect, topLeft: cornerRadius, topRight: cornerRadius, bottomLeft: cornerRadius, bottomRight: cornerRadius, smoothing: SettingsRowMetrics.cornerSmoothing))
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.75)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: 3.6, y: 7.3))
            ctx.addLine(to: CGPoint(x: 6.0, y: 9.7))
            ctx.addLine(to: CGPoint(x: 10.5, y: 4.4))
            ctx.strokePath()
        })!
        cache[key] = image
        return image
    }

    public static var unselected: CGImage {
        let key = "off-\(theme.colors.isDark)-\(System.backingScale)"
        if let image = cache[key] {
            return image
        }
        let image = generateImage(NSMakeSize(size, size), rotatedContext: { size, ctx in
            ctx.clear(CGRect(origin: .zero, size: size))
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let radius = cornerRadius - 0.5
            let path = CGPath.continuousRoundedRect(rect, topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius, smoothing: SettingsRowMetrics.cornerSmoothing)
            ctx.addPath(path)
            ctx.setFillColor(theme.colors.text.withAlphaComponent(0.06).cgColor)
            ctx.fillPath()
            ctx.addPath(path)
            ctx.setStrokeColor(theme.colors.text.withAlphaComponent(0.28).cgColor)
            ctx.setLineWidth(1)
            ctx.strokePath()
        })!
        cache[key] = image
        return image
    }
}
