import AppKit

/// Second screen: file name, status, progress bar, elapsed time and a cancel button.
final class WorkingView: NSView {
    var onCancel: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let cancelButton = PillButton(title: "Annulla", target: nil, action: nil)

    private var timer: Timer?
    private var startedAt = Date()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Resets the screen for a new job and starts the elapsed-time clock.
    func begin(file: String) {
        fileLabel.stringValue = file
        statusLabel.stringValue = "In ascolto…"
        setIndeterminate(false)
        progress.doubleValue = 0
        startedAt = Date()
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
    func update(status: String, progress value: Double) {
        setStatus(status)
        setIndeterminate(false)
        progress.doubleValue = max(progress.doubleValue, value)
        refreshDetail()
    }

    /// Shows a busy bar for network waits, where there is no measurable progress.
    func update(waiting status: String) {
        setStatus(status)
        setIndeterminate(true)
        refreshDetail()
    }

    private func setStatus(_ status: String) {
        guard statusLabel.stringValue != status else { return }
        statusLabel.stringValue = status
    }

    private func setIndeterminate(_ on: Bool) {
        guard progress.isIndeterminate != on else { return }
        progress.isIndeterminate = on
        if on { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        progress.stopAnimation(nil)
    }

    private func refreshDetail() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let time = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        if progress.isIndeterminate {
            detailLabel.stringValue = time
            progress.setAccessibilityValueDescription("In corso")
        } else {
            let percent = Int((progress.doubleValue * 100).rounded())
            detailLabel.stringValue = "\(percent)%  ·  \(time)"
            progress.setAccessibilityValueDescription("\(percent) per cento")
        }
    }

    private func build() {
        fileLabel.applyStyle(size: 20, weight: .semibold, color: Palette.ink)
        statusLabel.applyStyle(size: 14, weight: .regular, color: Palette.muted)
        detailLabel.applyStyle(size: 12, weight: .medium, color: Palette.muted)
        detailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.controlSize = .small
        progress.style = .bar
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.heightAnchor.constraint(equalToConstant: 8).isActive = true

        cancelButton.style(accent: false)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)

        let stack = NSStackView(views: [fileLabel, statusLabel, progress, detailLabel, cancelButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        progress.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.side),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.side),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
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
