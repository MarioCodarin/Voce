import AppKit
import VoceKit

/// Waveform envelope plus cue blocks. Clicking or dragging seeks and selects the cue
/// under the pointer; the editor keeps the table and this view in sync.
final class SubtitleTimelineView: NSView {
    var onSeek: ((Double) -> Void)?
    var onSelect: ((Int) -> Void)?

    private var samples: [Float] = []
    private var cues: [SubtitleCue] = []
    private var duration: Double = 0
    private var selectedIndex: Int?
    private var playhead: Double = 0

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 84) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.slider)
        setAccessibilityLabel(Copy.subtitleTimeline)
    }

    required init?(coder: NSCoder) { nil }

    func update(samples: [Float], cues: [SubtitleCue], duration: Double) {
        self.samples = samples
        self.cues = cues
        self.duration = max(duration, cues.map(\.end).max() ?? 0)
        needsDisplay = true
    }

    func update(cues: [SubtitleCue], duration: Double) {
        self.cues = cues
        self.duration = max(duration, cues.map(\.end).max() ?? 0)
        needsDisplay = true
    }

    func select(_ index: Int?) {
        selectedIndex = index
        needsDisplay = true
    }

    func setPlayhead(_ seconds: Double) {
        playhead = min(max(seconds, 0), max(duration, 0.001))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: Radius.control, yRadius: Radius.control)
        Palette.surface.setFill()
        path.fill()
        Palette.hairline.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1
        path.stroke()

        let waveTop = Space.s
        let waveBottom = bounds.height - 28
        let center = (waveTop + waveBottom) / 2
        let amplitude = max(2, (waveBottom - waveTop) / 2)

        if !samples.isEmpty, duration > 0 {
            let barWidth = max(1, bounds.width / CGFloat(samples.count))
            let accent = Palette.accent.withAlphaComponent(0.8)
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * barWidth
                let height = min(1, max(0, CGFloat(sample))) * amplitude
                let bar = NSBezierPath(
                    roundedRect: NSRect(x: x, y: center - height, width: max(0.8, barWidth - 0.6), height: max(1, height * 2)),
                    xRadius: 0.8,
                    yRadius: 0.8
                )
                accent.setFill()
                bar.fill()
            }
        }

        // Cue blocks
        if duration > 0 {
            for (index, cue) in cues.enumerated() {
                let x = CGFloat(cue.start / duration) * bounds.width
                let width = max(2, CGFloat(cue.duration / duration) * bounds.width)
                let block = NSBezierPath(
                    roundedRect: NSRect(x: x, y: bounds.height - 22, width: min(width, bounds.width - x), height: 12),
                    xRadius: 3,
                    yRadius: 3
                )
                (index == selectedIndex ? Palette.accent : Palette.accentWashStrong).setFill()
                block.fill()
            }

            // Playhead
            let x = min(bounds.width - 1, max(1, CGFloat(playhead / duration) * bounds.width))
            let line = NSBezierPath()
            line.move(to: NSPoint(x: x, y: Space.xs))
            line.line(to: NSPoint(x: x, y: bounds.height - Space.xs))
            Palette.accentText.setStroke()
            line.lineWidth = 1.5
            line.stroke()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        seek(to: event)
    }

    override func mouseDragged(with event: NSEvent) {
        seek(to: event)
    }

    private func seek(to event: NSEvent) {
        guard duration > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let time = min(max(0, Double(point.x / max(bounds.width, 1)) * duration), duration)
        playhead = time
        if let index = cues.firstIndex(where: { time >= $0.start && time <= $0.end })
            ?? nearestCue(to: time) {
            selectedIndex = index
            onSelect?(index)
        }
        onSeek?(time)
        needsDisplay = true
    }

    private func nearestCue(to time: Double) -> Int? {
        guard !cues.isEmpty else { return nil }
        return cues.enumerated().min {
            abs($0.element.start - time) < abs($1.element.start - time)
        }?.offset
    }

    override func accessibilityValue() -> Any? { NSNumber(value: playhead) }
    override func accessibilityMinValue() -> Any? { NSNumber(value: 0) }
    override func accessibilityMaxValue() -> Any? { NSNumber(value: max(duration, 0.001)) }
}
