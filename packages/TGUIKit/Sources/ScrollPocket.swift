import Cocoa

public enum ScrollPocketEdge: Int {
    case top = 0
    case bottom = 1

    fileprivate var mask: Int {
        return 1 << rawValue
    }
}

public extension NSScrollView {
    func registerScrollPocketContainer(_ view: NSView, edge: ScrollPocketEdge) {
        allowScrollPocketEdge(edge)
        performPocketSelector("registerPocketContainer:onEdge:", view: view, edge: edge)
    }

    func unregisterScrollPocketContainer(_ view: NSView, edge: ScrollPocketEdge) {
        performPocketSelector("unregisterPocketContainer:onEdge:", view: view, edge: edge)
    }

    private func allowScrollPocketEdge(_ edge: ScrollPocketEdge) {
        let getter = NSSelectorFromString("allowedPocketEdges")
        let setter = NSSelectorFromString("setAllowedPocketEdges:")
        guard responds(to: getter), responds(to: setter) else {
            return
        }
        typealias Getter = @convention(c) (NSObject, Selector) -> Int
        typealias Setter = @convention(c) (NSObject, Selector, Int) -> Void
        let allowed = unsafeBitCast(method(for: getter), to: Getter.self)(self, getter)
        if allowed & edge.mask == 0 {
            unsafeBitCast(method(for: setter), to: Setter.self)(self, setter, allowed | edge.mask)
        }
    }

    private func performPocketSelector(_ name: String, view: NSView, edge: ScrollPocketEdge) {
        let selector = NSSelectorFromString(name)
        guard responds(to: selector) else {
            return
        }
        typealias Function = @convention(c) (NSObject, Selector, NSView, Int) -> Void
        unsafeBitCast(method(for: selector), to: Function.self)(self, selector, view, edge.rawValue)
    }
}
