import AppKit

/// The signature motion of the app: a small waveform that animates while Voce works.
/// Bars are plain CALayers animated on the render server, so CPU stays near zero and
/// animations stop as soon as the view is hidden. Reduce Motion keeps a still waveform.
final class WaveformView: NSView {
    var barCount = 9 {
        didSet {
            guard barCount != oldValue else { return }
            rebuild()
        }
    }

    /// 0...1, used to tint the bars that represent completed work.
    private(set) var progress: CGFloat = 0
    private(set) var isAnimating = false

    private var bars: [CALayer] = []
    /// Resting heights, also used while Reduce Motion is on.
    private static let pattern: [CGFloat] = [0.55, 0.85, 1, 0.7, 0.45, 0.8, 0.6, 1, 0.5, 0.75, 0.9, 0.55, 0.7]
    private static let barWidth: CGFloat = 4
    private static let gap: CGFloat = 5

    override var intrinsicContentSize: NSSize {
        let width = CGFloat(barCount) * Self.barWidth + CGFloat(barCount - 1) * Self.gap
        return NSSize(width: width, height: 34)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        rebuild()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func setProgress(_ value: CGFloat) {
        progress = min(max(value, 0), 1)
        updateColors()
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        updateColors()
        guard !Motion.reduced else { return }
        for (index, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: "wave")
            bar.transform = CATransform3DMakeScale(1, Self.pattern[index % Self.pattern.count], 1)
            let wave = CAKeyframeAnimation(keyPath: "transform.scale.y")
            wave.values = [0.35, 1.0, 0.5, 0.85, 0.35]
            wave.keyTimes = [0, 0.28, 0.5, 0.78, 1]
            wave.duration = 1.5 + Double(index % 4) * 0.18
            wave.repeatCount = .infinity
            wave.beginTime = CACurrentMediaTime() + Double(index) * 0.06
            wave.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(wave, forKey: "wave")
        }
    }

    func stopAnimating() {
        isAnimating = false
        for (index, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: "wave")
            bar.transform = CATransform3DMakeScale(1, Self.pattern[index % Self.pattern.count], 1)
        }
        updateColors()
    }

    override func viewDidHide() {
        super.viewDidHide()
        stopAnimating()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    // MARK: - Layers

    private func rebuild() {
        bars.forEach { $0.removeFromSuperlayer() }
        bars = (0..<barCount).map { _ in
            let bar = CALayer()
            bar.cornerRadius = Self.barWidth / 2
            bar.cornerCurve = .continuous
            layer?.addSublayer(bar)
            return bar
        }
        updateColors()
        needsLayout = true
        invalidateIntrinsicContentSize()
    }

    private func layoutBars() {
        guard !bars.isEmpty else { return }
        let totalWidth = CGFloat(barCount) * Self.barWidth + CGFloat(barCount - 1) * Self.gap
        let startX = (bounds.width - totalWidth) / 2
        let height = max(8, min(bounds.height, 34))
        let centerY = bounds.midY

        for (index, bar) in bars.enumerated() {
            let x = startX + CGFloat(index) * (Self.barWidth + Self.gap)
            bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: height)
            bar.position = CGPoint(x: x + Self.barWidth / 2, y: centerY)
            if !isAnimating || Motion.reduced {
                bar.transform = CATransform3DMakeScale(1, Self.pattern[index % Self.pattern.count], 1)
            }
        }
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            for (index, bar) in bars.enumerated() {
                let reached = CGFloat(index + 1) / CGFloat(max(barCount, 1)) <= progress
                bar.backgroundColor = (reached || isAnimating ? Palette.accent : Palette.muted.withAlphaComponent(0.38)).cgColor
            }
        }
    }
}
