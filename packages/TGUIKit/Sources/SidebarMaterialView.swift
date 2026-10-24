import Cocoa
import ColorPalette

open class SidebarMaterialView: View {

    public enum Style {
        case sidebar
        case bar
    }

    public static let defaultTintAlpha: CGFloat = 0.45
    public static let barTintAlpha: CGFloat = 0

    private static let sidebarGlassVariant = 17
    private static let sidebarAdaptiveAppearance = 1

    public let style: Style
    private let effectView: NSView
    private let tintView = View()

    public var tintColor: NSColor = presentation.colors.background {
        didSet {
            applyAppearance(presentation)
        }
    }

    public var tintAlpha: CGFloat {
        didSet {
            applyAppearance(presentation)
        }
    }

    public init(frame frameRect: NSRect, style: Style) {
        self.style = style
        switch style {
        case .sidebar:
            self.tintAlpha = SidebarMaterialView.defaultTintAlpha
        case .bar:
            self.tintAlpha = SidebarMaterialView.barTintAlpha
        }
        self.effectView = SidebarMaterialView.makeEffectView(style: style, frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        backgroundColor = .clear

        tintView.isEventLess = true
        tintView.userInteractionEnabled = false
        tintView.frame = bounds

        addSubview(effectView)
        addSubview(tintView)

        applyAppearance(presentation)
    }

    public required convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, style: .sidebar)
    }

    public convenience init(frame frameRect: NSRect, style: Style = .sidebar, tintColor: NSColor) {
        self.init(frame: frameRect, style: style)
        self.tintColor = tintColor
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeEffectView(style: Style, frame: NSRect) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: frame)
            glass.style = .regular
            glass.cornerRadius = 0
            if style == .sidebar {
                setPrivateInteger(glass, "set_variant:", sidebarGlassVariant)
                setPrivateInteger(glass, "set_adaptiveAppearance:", sidebarAdaptiveAppearance)
            }
            return glass
        }
        let visual = NSVisualEffectView(frame: frame)
        switch style {
        case .sidebar:
            visual.material = .sidebar
            visual.blendingMode = .behindWindow
            visual.state = .followsWindowActiveState
        case .bar:
            if #available(macOS 10.14, *) {
                visual.material = .headerView
            } else {
                visual.material = .titlebar
            }
            visual.blendingMode = .withinWindow
            visual.state = .active
        }
        return visual
    }

    private static func setPrivateInteger(_ view: NSView, _ selectorName: String, _ value: Int) {
        let selector = NSSelectorFromString(selectorName)
        guard view.responds(to: selector) else {
            return
        }
        typealias Setter = @convention(c) (NSObject, Selector, Int) -> Void
        unsafeBitCast(view.method(for: selector), to: Setter.self)(view, selector, value)
    }

    open override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        applyAppearance(theme)
    }

    private func applyAppearance(_ theme: PresentationTheme) {
        effectView.appearance = theme.appearance
        effectView.isHidden = !System.blurEnabled
        let usesThemeTint = tintAlpha > 0 && SidebarMaterialView.hasTintedBackground(theme.colors)
        let tint = usesThemeTint ? tintColor.withAlphaComponent(tintColor.alphaComponent * tintAlpha) : nil
        if #available(macOS 26.0, *), let glass = effectView as? NSGlassEffectView {
            glass.tintColor = tint
            tintView.backgroundColor = System.blurEnabled ? .clear : tintColor
        } else {
            tintView.backgroundColor = System.blurEnabled ? (tint ?? .clear) : tintColor
        }
    }

    private static func hasTintedBackground(_ colors: ColorPalette) -> Bool {
        if colors.tinted {
            return true
        }
        return !colors.background.isEqual(colors.parent.palette.background)
    }

    open override func layout() {
        super.layout()
        effectView.frame = bounds
        tintView.frame = bounds
    }
}
