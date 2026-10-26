import AppKit
import QuartzCore
import TGUIKit

private final class PeerListScrollEdgeHost: NSView {
    override var isFlipped: Bool { true }
}

private final class PeerListScrollEdgeBlur: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class PeerListScrollEdgeView: View {
    private let scrollView: NSScrollView
    private let header: NSView
    private var splitController: NSSplitViewController?
    private var headerHeight: NSLayoutConstraint?
    private var blurView: NSVisualEffectView?
    private let fadeMask = CAGradientLayer()
    private let outlineMask = CAShapeLayer()

    weak var clippingView: NSView? {
        didSet { needsLayout = true }
    }

    init(scrollView: NSScrollView, header: NSView, nativeEffectsAvailable: Bool) {
        self.scrollView = scrollView
        self.header = header
        super.init(frame: scrollView.frame)
        layer?.masksToBounds = false
        outlineMask.fillColor = NSColor.black.cgColor

        if #available(macOS 26.0, *), nativeEffectsAvailable {
            let split = NSSplitViewController()
            split.splitView.isVertical = true
            split.splitView.dividerStyle = .thin
            let content = NSViewController()
            let contentHost = PeerListScrollEdgeHost(frame: bounds)
            content.view = contentHost
            let item = NSSplitViewItem(viewController: content)
            item.canCollapse = false
            let accessory = NSSplitViewItemAccessoryViewController()
            accessory.automaticallyAppliesContentInsets = false
            if #available(macOS 26.1, *) {
                accessory.preferredScrollEdgeEffectStyle = .soft
            }
            let accessoryHost = PeerListScrollEdgeHost(frame: header.frame)
            accessory.view = accessoryHost
            let height = accessoryHost.heightAnchor.constraint(equalToConstant: header.frame.height)
            height.isActive = true
            headerHeight = height
            item.addTopAlignedAccessoryViewController(accessory)
            split.addSplitViewItem(item)
            split.view.frame = bounds
            addSubview(split.view)
            contentHost.addSubview(scrollView)
            accessoryHost.addSubview(header)
            splitController = split
        } else {
            addSubview(scrollView)
            let blur = PeerListScrollEdgeBlur(frame: .zero)
            blur.wantsLayer = true
            blur.blendingMode = .withinWindow
            blur.material = .titlebar
            blur.state = .active
            fadeMask.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
            fadeMask.startPoint = CGPoint(x: 0.5, y: 1)
            fadeMask.endPoint = CGPoint(x: 0.5, y: 0)
            blur.layer?.mask = fadeMask
            addSubview(blur)
            addSubview(header)
            blurView = blur
        }
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        if let root = splitController?.view {
            root.appearance = theme.appearance
            (scrollView as? AppearanceViewProtocol)?.updateLocalizationAndTheme(theme: theme)
            (header as? AppearanceViewProtocol)?.updateLocalizationAndTheme(theme: theme)
        }
        blurView?.appearance = theme.appearance
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        updateLayout()
    }

    func updateLayout() {
        if let root = splitController?.view {
            root.frame = bounds
            if #available(macOS 26.0, *) {
                let insets = root.additionalSafeAreaInsets
                let top = -safeAreaInsets.top
                if insets.top != top {
                    root.additionalSafeAreaInsets = NSEdgeInsets(top: top, left: insets.left, bottom: insets.bottom, right: insets.right)
                }
            }
            if headerHeight?.constant != header.frame.height {
                headerHeight?.constant = header.frame.height
            }
            root.layoutSubtreeIfNeeded()
        }
        scrollView.frame = scrollView.superview?.bounds ?? bounds
        if let blurView {
            let height = header.frame.height
            let fade: CGFloat = 24
            blurView.frame = NSMakeRect(0, 0, bounds.width, height + fade)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fadeMask.frame = blurView.bounds
            fadeMask.locations = [0, NSNumber(value: Double(height / max(1, height + fade))), 1]
            CATransaction.commit()
        }
        if let clippingView, let clippingLayer = clippingView.layer {
            let radius = clippingLayer.cornerRadius
            let scale = window?.backingScaleFactor ?? 2
            let inset: CGFloat = radius > 0 ? 1 / scale : 0
            let rect = convert(clippingView.bounds, from: clippingView).insetBy(dx: inset, dy: inset)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            outlineMask.frame = bounds
            outlineMask.contentsScale = scale
            outlineMask.path = CGPath(roundedRect: rect, cornerWidth: max(0, radius - inset), cornerHeight: max(0, radius - inset), transform: nil)
            layer?.mask = outlineMask
            CATransaction.commit()
        } else {
            layer?.mask = nil
        }
    }
}
