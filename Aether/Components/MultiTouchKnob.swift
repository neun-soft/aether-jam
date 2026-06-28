import SwiftUI
import UIKit

/// A transparent vertical-drag touch surface for a knob. Each instance owns its own UITouch, so
/// several knobs can be driven at once (DJ-style) even though SwiftUI gestures inside a ScrollView
/// can't. While a knob is held it disables the enclosing scroll view so the vertical drag adjusts
/// the value instead of scrolling.
struct MultiTouchKnobSurface: UIViewRepresentable {
    var onChange: (Double) -> Void
    var currentValue: () -> Double

    func makeUIView(context: Context) -> KnobTouchView {
        let v = KnobTouchView()
        v.onChange = onChange; v.currentValue = currentValue
        return v
    }
    func updateUIView(_ v: KnobTouchView, context: Context) {
        v.onChange = onChange; v.currentValue = currentValue
    }
}

final class KnobTouchView: UIView {
    var onChange: (Double) -> Void = { _ in }
    var currentValue: () -> Double = { 0.5 }

    private var activeTouch: UITouch?
    private var startY: CGFloat = 0
    private var startVal: Double = 0.5
    private weak var scroll: UIScrollView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    private func enclosingScroll() -> UIScrollView? {
        var v: UIView? = superview
        while let s = v { if let sc = s as? UIScrollView { return sc }; v = s.superview }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let t = touches.first else { return }
        activeTouch = t
        startY = t.location(in: self).y
        startVal = currentValue()
        scroll = enclosingScroll()
        scroll?.isScrollEnabled = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = activeTouch, touches.contains(t) else { return }
        let y = t.location(in: self).y
        let dv = Double((startY - y) / 140.0)          // ~140pt of travel = full range
        onChange(min(1, max(0, startVal + dv)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }

    private func end(_ touches: Set<UITouch>) {
        if let t = activeTouch, touches.contains(t) {
            activeTouch = nil
            scroll?.isScrollEnabled = true
        }
    }
}
