import Cocoa
import ColorPalette

open class SidebarMaterialView: View {

    public enum Style {
        case sidebar
        case bar
    }

    public static let defaultTintAlpha: CGFloat = 0.7
    public static let barTintAlpha: CGFloat = 0.6

    public let style: Style
    private let effectView = NSVisualEffectView()
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
        super.init(frame: frameRect)
        backgroundColor = .clear

        switch style {
        case .sidebar:
            effectView.material = .sidebar
            effectView.blendingMode = .behindWindow
            effectView.state = .followsWindowActiveState
        case .bar:
            effectView.material = .headerView
            effectView.blendingMode = .withinWindow
            effectView.state = .active
        }
        effectView.frame = bounds

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

    open override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        applyAppearance(theme)
    }

    private func applyAppearance(_ theme: PresentationTheme) {
        effectView.appearance = theme.appearance
        effectView.isHidden = !System.blurEnabled
        let alpha = System.blurEnabled ? tintAlpha : 1
        tintView.backgroundColor = tintColor.withAlphaComponent(tintColor.alphaComponent * alpha)
    }

    open override func layout() {
        super.layout()
        effectView.frame = bounds
        tintView.frame = bounds
    }
}
