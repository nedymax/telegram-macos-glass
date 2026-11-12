import Cocoa
import TGUIKit
import LocalAnimations

public final class ActionButton : Control {
    fileprivate let imageView: ImageView = ImageView()
    fileprivate let textView: TextView = TextView()
    private var glassView: LiquidGlassView?
    private let circleView = View()
    private var circle = false

    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        circleView.isEventLess = true
        addSubview(circleView)
        addSubview(imageView)
        addSubview(textView)

        self.imageView.animates = true
        imageView.isEventLess = true
        imageView.isAccessibilityDecorative = true
        textView.isEventLess = true
        textView.isAccessibilityDecorative = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false

        self.controlOpacityEventIgnored = true

        set(handler: { control in
            control.change(opacity: 0.8, animated: true)
        }, for: .Highlight)

        set(handler: { control in
            control.change(opacity: 1.0, animated: true)
        }, for: .Normal)

        set(handler: { control in
            control.change(opacity: 1.0, animated: true)
        }, for: .Hover)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateAndLayout(item: ActionItem, bgColor: NSColor, useGlass: Bool, circle: Bool = false, labelWidth: CGFloat = ActionItem.actionItemWidth) {
        self.setAccessibilityLabel(item.text)
        self.toolTip = circle ? item.text : nil
        self.circle = circle
        let font: NSFont = circle ? .normal(ActionItem.circleLabelSize) : .normal(.text)
        if useGlass {
            let foreground: NSColor = bgColor.lightness > 0.8 ? NSColor.black : NSColor.white
            self.imageView.image = item.image.highlight(color: foreground)
            let layout = TextViewLayout(.initialize(string: item.text, color: foreground, font: font), maximumNumberOfLines: circle ? 1 : INT32_MAX, truncationType: .end, alignment: .center)
            layout.measure(width: labelWidth)
            self.textView.update(layout)
        } else {
            self.imageView.image = item.image
            if circle {
                let layout = TextViewLayout(.initialize(string: item.text, color: item.color, font: font), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
                layout.measure(width: labelWidth)
                self.textView.update(layout)
            } else {
                self.textView.update(item.textLayout)
            }
        }
        self.imageView.sizeToFit()

        if useGlass {
            let glass: LiquidGlassView
            if let existing = self.glassView {
                glass = existing
            } else {
                glass = LiquidGlassView(frame: bounds, cornerRadius: circle ? ActionItem.circleSize / 2 : 20, hasShadow: true, hasBorder: true, forceAppearance: .forceLight)
                self.glassView = glass
                addSubview(glass, positioned: .below, relativeTo: imageView)
            }
            glass.customTint = bgColor
            self.backgroundColor = .clear
            self.layer?.cornerRadius = 0
            self.layer?.masksToBounds = false
            self.stretchReferenceView = glass
            circleView.backgroundColor = .clear
        } else {
            if let glass = self.glassView {
                glass.removeFromSuperview()
                self.glassView = nil
            }
            self.stretchReferenceView = nil
            if circle {
                self.backgroundColor = .clear
                self.layer?.cornerRadius = 0
                circleView.backgroundColor = bgColor
                circleView.layer?.cornerRadius = ActionItem.circleSize / 2
            } else {
                self.backgroundColor = bgColor
                self.layer?.cornerRadius = 20
                circleView.backgroundColor = .clear
            }
        }


        self.removeAllHandlers()
        if let subItems = item.subItems, !subItems.isEmpty {
            self.contextMenu = {
                let menu = ContextMenu()
                var added = false
                for sub in subItems {
                    let item = ContextMenuItem(sub.text, handler: sub.action, itemMode: sub.destruct ? .destruct : .normal, itemImage: sub.animation.value)
                    if sub.destruct, !added {
                        added = true
                        menu.addItem(ContextSeparatorItem())
                    }
                    menu.addItem(item)
                }
                return menu
            }
        } else {
            self.contextMenu = nil
            self.set(handler: { _ in
                item.action()
            }, for: .Click)
        }


        needsLayout = true

    }

    public override func layout() {
        super.layout()
        if circle {
            let circleFrame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - ActionItem.circleSize) / 2), 0, ActionItem.circleSize, ActionItem.circleSize)
            circleView.frame = circleFrame
            glassView?.frame = circleFrame
            glassView?.updateLayout(size: circleFrame.size, transition: .immediate)
            imageView.setFrameOrigin(NSMakePoint(floorToScreenPixels(backingScaleFactor, circleFrame.midX - imageView.frame.width / 2), floorToScreenPixels(backingScaleFactor, circleFrame.midY - imageView.frame.height / 2)))
            textView.centerX(y: circleFrame.maxY + ActionItem.circleLabelGap)
        } else {
            circleView.frame = .zero
            glassView?.frame = bounds
            glassView?.updateLayout(size: bounds.size, transition: .immediate)
            imageView.centerX(y: 5)
            textView.centerX(y: frame.height - textView.frame.height - 11)
        }
    }
}



public struct SubActionItem {
    public let text: String
    public let destruct: Bool
    public let action:()->Void
    public let animation: LocalAnimatedSticker
    public init(text: String, animation: LocalAnimatedSticker, destruct: Bool = false, action:@escaping()->Void) {
        self.text = text
        self.animation = animation
        self.action = action
        self.destruct = destruct
    }
}

public final class ActionItem {

    public static let actionItemWidth: CGFloat = 125
    public static let circleSize: CGFloat = 40
    public static let circleLabelSize: CGFloat = 11
    public static let circleLabelGap: CGFloat = 6
    public static let circleItemGap: CGFloat = 12
    public static let circleMinWidth: CGFloat = 64
    public static let circleMaxWidth: CGFloat = 96

    public static func circleItemWidth(_ items: [ActionItem]) -> CGFloat {
        let widest = items.map { NSAttributedString.initialize(string: $0.text, font: .normal(circleLabelSize)).size().width }.max() ?? 0
        return min(circleMaxWidth, max(circleMinWidth, ceil(widest) + 8))
    }

    public static var circleItemHeight: CGFloat {
        let label = NSAttributedString.initialize(string: "A", font: .normal(circleLabelSize)).size().height
        return circleSize + circleLabelGap + ceil(label)
    }
    public static func actionItemInsetWidth(isColorfull: Bool) -> CGFloat {
        return isColorfull ? 12 : 20
    }


    public let text: String
    public let color: NSColor
    public let destruct: Bool
    public let image: CGImage
    public let action:()->Void
    public let animation: LocalAnimatedSticker
    public let subItems:[SubActionItem]?


    public let textLayout: TextViewLayout
    public let size: NSSize

    public init(text: String, color: NSColor, image: CGImage, animation: LocalAnimatedSticker, destruct: Bool = false, action: @escaping()->Void, subItems:[SubActionItem]? = nil) {
        self.text = text
        self.color = color
        self.image = image.highlight(color: color)
        self.action = action
        self.animation = animation
        self.subItems = subItems
        self.destruct = destruct
        self.textLayout = TextViewLayout(.initialize(string: text, color: color, font: .normal(.text)), alignment: .center)
        self.textLayout.measure(width: ActionItem.actionItemWidth)

        self.size = NSMakeSize(ActionItem.actionItemWidth, image.backingSize.height + textLayout.layoutSize.height + 10)
    }

}
