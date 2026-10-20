import AppKit

/// Second screen: file name, status, progress bar, elapsed time and a cancel button.
final class WorkingView: NSView {
    var onCancel: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progress = ProgressBar()
    private let cancelButton = ActionButton(title: "Annulla", target: nil, action: nil)

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
        progress.setIndeterminate(false)
        progress.setValue(0, animated: false)
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
        progress.setIndeterminate(false)
        progress.setValue(max(progress.value, value))
        refreshDetail()
    }

    /// Shows a busy bar for network waits, where there is no measurable progress.
    func update(waiting status: String) {
        setStatus(status)
        progress.setIndeterminate(true)
        refreshDetail()
    }

    private func setStatus(_ status: String) {
        guard statusLabel.stringValue != status else { return }
        statusLabel.stringValue = status
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        progress.setIndeterminate(false)
    }

    private func refreshDetail() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let time = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        if progress.isIndeterminate {
            detailLabel.stringValue = time
        } else {
            let percent = Int((progress.value * 100).rounded())
            detailLabel.stringValue = "\(percent)%  ·  \(time)"
        }
    }

    private func build() {
        fileLabel.applyStyle(font: Typo.title, color: Palette.ink)
        statusLabel.applyStyle(font: Typo.label, color: Palette.muted)
        detailLabel.applyStyle(font: Typo.captionDigits, color: Palette.muted)
        detailLabel.setAccessibilityElement(false)

        progress.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.style(accent: false)
        cancelButton.toolTip = "Annulla (esc)"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)

        let stack = NSStackView(views: [fileLabel, statusLabel, progress, detailLabel, cancelButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.xs, after: fileLabel)
        stack.setCustomSpacing(Space.l, after: statusLabel)
        stack.setCustomSpacing(Space.s, after: progress)
        stack.setCustomSpacing(Space.xl, after: detailLabel)
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
