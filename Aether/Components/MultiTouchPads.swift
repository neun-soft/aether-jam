import SwiftUI
import UIKit

/// A transparent multitouch surface laid over the pad grid. SwiftUI gestures can't track
/// several simultaneous touches across a grid, so we use a UIView and map each live touch to
/// a pad cell — enabling true polyphony (hold a chord) plus glissando when a finger slides.
struct MultiTouchPadGrid: UIViewRepresentable {
    let rows: Int
    let cols: Int
    let onDown: (Int) -> Void
    let onUp: (Int) -> Void

    func makeUIView(context: Context) -> PadTouchView {
        let v = PadTouchView()
        v.rows = rows; v.cols = cols
        v.onDown = onDown; v.onUp = onUp
        return v
    }

    func updateUIView(_ v: PadTouchView, context: Context) {
        v.rows = rows; v.cols = cols
        v.onDown = onDown; v.onUp = onUp   // refresh closures (capture latest octave/state)
    }
}

final class PadTouchView: UIView {
    var rows = 4
    var cols = 4
    var onDown: (Int) -> Void = { _ in }
    var onUp: (Int) -> Void = { _ in }

    private var touchPad: [UITouch: Int] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    private func pad(for touch: UITouch) -> Int {
        let p = touch.location(in: self)
        guard bounds.width > 0, bounds.height > 0 else { return 0 }
        let col = min(cols - 1, max(0, Int(p.x / (bounds.width / CGFloat(cols)))))
        let row = min(rows - 1, max(0, Int(p.y / (bounds.height / CGFloat(rows)))))
        return row * cols + col
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let id = pad(for: t)
            touchPad[t] = id
            onDown(id)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let now = pad(for: t)
            if let prev = touchPad[t], prev != now {
                onUp(prev)
                onDown(now)
                touchPad[t] = now
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }

    private func release(_ touches: Set<UITouch>) {
        for t in touches {
            if let id = touchPad[t] { onUp(id); touchPad[t] = nil }
        }
    }
}
