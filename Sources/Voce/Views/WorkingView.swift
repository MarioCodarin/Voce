import AppKit
import VoceKit

/// Second screen: the working waveform, status, progress and cancel.
final class WorkingView: NSView {
    var onCancel: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let waveform = WaveformView()
    private let progress = ProgressBar()
    private let cancelButton = ActionButton(title: "", target: nil, action: nil)

    private var timer: Timer?
    private var startedAt = Date()
    private var modelName = ""
    private var announcedQuarter = 0
    private var lastStatus: TranscriptionStatus = .listening

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Resets the screen for a new job and starts the elapsed-time clock.
    func begin(file: String, model: TranscriptionModel) {
        fileLabel.stringValue = file
        modelName = model.displayName
        statusLabel.stringValue = TranscriptionStatus.listening.displayText(for: Copy.lang)
        lastStatus = .listening
        progress.setIndeterminate(false)
        progress.setValue(0, animated: false)
        waveform.setProgress(0)
        waveform.startAnimating()
        startedAt = Date()
        announcedQuarter = 0
        refreshDetail()
        timer?.invalidate()
        // `.common` keeps the clock running while menus are open or the window resizes.
        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDetail() }
        }
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    /// Progress only moves forward, so late callbacks can't make the bar jump back.
    func update(status: TranscriptionStatus, progress value: Double) {
        lastStatus = status
        setStatus(status.displayText(for: Copy.lang))
        progress.setIndeterminate(status.isIndeterminate)
        if !status.isIndeterminate {
            progress.setValue(max(progress.value, value))
            waveform.setProgress(max(waveform.progress, CGFloat(value)))
        }
        refreshDetail()
        let quarter = Int(progress.value * 4)
        if quarter > announcedQuarter, quarter < 4, !status.isIndeterminate {
            announcedQuarter = quarter
            Announcer.say(Copy.percent(quarter * 25))
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        waveform.stopAnimating()
        progress.setIndeterminate(false)
    }

    private func setStatus(_ status: String) {
        guard statusLabel.stringValue != status else { return }
        statusLabel.stringValue = status
    }

    private func refreshDetail() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let time = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        let prefix = modelName.isEmpty ? "" : modelName + "  ·  "
        if lastStatus.isIndeterminate {
            detailLabel.stringValue = prefix + time
        } else {
            let percent = Int((progress.value * 100).rounded())
            detailLabel.stringValue = "\(prefix)\(percent)%  ·  \(time)"
        }
    }

    private func build() {
        fileLabel.applyStyle(font: Typo.title, color: Palette.ink, lines: 1)
        fileLabel.lineBreakMode = .byTruncatingMiddle

        waveform.barCount = 13
        waveform.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            waveform.widthAnchor.constraint(equalToConstant: 120),
            waveform.heightAnchor.constraint(equalToConstant: 34)
        ])

        statusLabel.applyStyle(font: Typo.headline, color: Palette.ink, lines: 1)
        statusLabel.setAccessibilityLabel(Copy.transcript)
        detailLabel.applyStyle(font: Typo.captionDigits, color: Palette.muted, lines: 1)
        detailLabel.setAccessibilityElement(false)
        hintLabel.applyStyle(font: Typo.caption, color: Palette.muted, lines: 1)
        hintLabel.stringValue = Copy.keepUsingMac

        progress.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.title = Copy.cancel
        cancelButton.style(accent: false)
        cancelButton.toolTip = Copy.cancel + " (esc)"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)

        let stack = NSStackView(views: [fileLabel, waveform, statusLabel, progress, detailLabel, hintLabel, cancelButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.xl, after: fileLabel)
        stack.setCustomSpacing(Space.m, after: waveform)
        stack.setCustomSpacing(Space.xs, after: statusLabel)
        stack.setCustomSpacing(Space.s, after: progress)
        stack.setCustomSpacing(Space.xxl, after: hintLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let wide = progress.widthAnchor.constraint(equalToConstant: Layout.column)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            wide,
            progress.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -2 * Layout.side),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -Space.l),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Layout.side),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Layout.side)
        ])
    }

    override var acceptsFirstResponder: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    @objc private func cancelClicked() {
        onCancel?()
    }
}
