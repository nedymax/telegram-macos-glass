import Cocoa

public enum ScrollPocketEdge: Int {
    case top = 0
    case bottom = 1
}

public extension NSScrollView {
    func registerScrollPocketContainer(_ view: NSView, edge: ScrollPocketEdge) {
        performPocketSelector("registerPocketContainer:onEdge:", view: view, edge: edge)
    }

    func unregisterScrollPocketContainer(_ view: NSView, edge: ScrollPocketEdge) {
        performPocketSelector("unregisterPocketContainer:onEdge:", view: view, edge: edge)
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
