import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramTheme
import TelegramContext


public final class PeerInfoMusicView : View {
    public static func height(colorful: Bool) -> CGFloat {
        return colorful ? capsuleHeight + 10 : 20
    }
    public static let capsuleHeight: CGFloat = 28
    private static let capsulePadding: CGFloat = 12
    private var capsule = false
    private let textView: TextView = TextView()
    private var titleFont: NSFont = .semibold(.short)
    private let chevron = ImageView()
    private let imageView = ImageView()
    private let container = View()
    public let control = Control()
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        control.addSubview(container)
        container.addSubview(textView)
        container.addSubview(chevron)
        container.addSubview(imageView)

        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isAccessibilityDecorative = true
        chevron.isAccessibilityDecorative = true
        imageView.isAccessibilityDecorative = true
        
        control.scaleOnClick = true
        
        
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(file: TelegramMediaFile, primaryText: NSColor, secondaryText: NSColor, backgroundColor: NSColor, colorfull: Bool, context: any AccountContextProtocol) {
        var t:String = "Unknown Track"
        var p:String = "Unknown Performer"
        
        
        

        
        self.capsule = colorfull
        self.backgroundColor = .clear
        container.backgroundColor = colorfull ? backgroundColor : .clear
        container.layer?.cornerRadius = colorfull ? PeerInfoMusicView.capsuleHeight / 2 : 0
        
        for attribute in file.attributes {
            if case let .Audio(_, _, title, performer, _) = attribute {
                if let title {
                    t = title
                }
                if let performer {
                    p = performer
                }
                break
            }
        }
        
        titleFont = !colorfull ? .semibold(.text) : .semibold(.short)
        let attr = NSMutableAttributedString()
        attr.append(string: t, color: primaryText, font: titleFont)
        attr.append(string: " - ", color: secondaryText, font: !colorfull ? .normal(.text) : .normal(.short))
        attr.append(string: p, color: secondaryText, font: !colorfull ? .normal(.text) : .normal(.short))

        let textLayout = TextViewLayout(attr, maximumNumberOfLines: 1, alignment: .center)
        textLayout.measure(width: frame.width - 40)
        
        self.textView.update(textLayout)
        control.setAccessibilityLabel(attr.string)
        
        imageView.image = TelegramThemeHooks.shared.image(.iconPeerMusicWaveform).precomposed(primaryText)
        imageView.sizeToFit()

        
        chevron.image = TelegramThemeHooks.shared.image(.iconPeerMusicChevron).precomposed(secondaryText)
        chevron.sizeToFit()
        
        needsLayout = true
    }
    
    public override func layout() {
        super.layout()
        
        control.frame = bounds
        let padding: CGFloat = capsule ? PeerInfoMusicView.capsulePadding : 0
        let height: CGFloat = capsule ? PeerInfoMusicView.capsuleHeight : frame.height
        textView.resize(frame.width - 60 - padding * 2)

        let contentWidth = imageView.frame.width + 3 + textView.frame.width + 3 + chevron.frame.width
        container.setFrameSize(NSMakeSize(contentWidth + (capsule ? padding * 2 : 6), height))

        imageView.centerY(x: padding)
        textView.centerY(x: imageView.frame.maxX + 3)
        if let line = textView.textLayout?.lines.first {
            let glyphCenter = line.frame.minY - (titleFont.ascender + titleFont.descender) / 2
            textView.setFrameOrigin(NSMakePoint(textView.frame.minX, floorToScreenPixels(backingScaleFactor, height / 2 - glyphCenter)))
        }
        chevron.centerY(x: textView.frame.maxX + 3)

        if capsule {
            container.centerX(y: 0)
        } else {
            container.center()
        }
    }
}
