import AppKit

/// Second screen: file name, status, progress bar, elapsed time and a cancel button.
final class WorkingView: NSView {
    var onCancel: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let cancelButton = NSButton(title: "Annulla", target: nil, action: nil)

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
        progress.doubleValue = 0
        startedAt = Date()
        refreshDetail()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDetail() }
        }
    }

    /// Progress only moves forward, so late callbacks can't make the bar jump back.
    func update(status: String, progress value: Double) {
        statusLabel.stringValue = status
        progress.doubleValue = max(progress.doubleValue, value)
        refreshDetail()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshDetail() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let percent = Int((progress.doubleValue * 100).rounded())
        detailLabel.stringValue = String(format: "%d%%  ·  %d:%02d", percent, elapsed / 60, elapsed % 60)
        progress.setAccessibilityValueDescription("\(percent) per cento")
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

        cancelButton.applyPillStyle(accent: false)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)

        let stack = NSStackView(views: [fileLabel, statusLabel, progress, detailLabel, cancelButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        progress.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 72)
        ])
    }

    @objc private func cancelClicked() {
        onCancel?()
    }
}
