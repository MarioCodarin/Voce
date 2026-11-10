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
    private let queueBox = CardView()
    private let queueStack = NSStackView()

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
    func begin(file: String, model: TranscriptionModel, queue: [QueueItem] = []) {
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
        renderQueue(queue)
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

    /// Updates the batch list as files finish or fail.
    func updateQueue(_ queue: [QueueItem]) {
        renderQueue(queue)
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

        queueStack.orientation = .vertical
        queueStack.alignment = .leading
        queueStack.spacing = 2
        queueStack.translatesAutoresizingMaskIntoConstraints = false
        queueBox.addSubview(queueStack)
        queueBox.translatesAutoresizingMaskIntoConstraints = false
        queueBox.isHidden = true
        NSLayoutConstraint.activate([
            queueStack.leadingAnchor.constraint(equalTo: queueBox.leadingAnchor, constant: Space.m),
            queueStack.trailingAnchor.constraint(equalTo: queueBox.trailingAnchor, constant: -Space.m),
            queueStack.topAnchor.constraint(equalTo: queueBox.topAnchor, constant: Space.s),
            queueStack.bottomAnchor.constraint(equalTo: queueBox.bottomAnchor, constant: -Space.s),
            queueBox.widthAnchor.constraint(equalToConstant: 360)
        ])

        let stack = NSStackView(views: [fileLabel, waveform, statusLabel, progress, detailLabel, hintLabel, cancelButton, queueBox])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.xl, after: fileLabel)
        stack.setCustomSpacing(Space.m, after: waveform)
        stack.setCustomSpacing(Space.xs, after: statusLabel)
        stack.setCustomSpacing(Space.s, after: progress)
        stack.setCustomSpacing(Space.xxl, after: hintLabel)
        stack.setCustomSpacing(Space.l, after: cancelButton)
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

    // MARK: - Batch list

    private func renderQueue(_ queue: [QueueItem]) {
        queueStack.arrangedSubviews.forEach {
            queueStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        queueBox.isHidden = queue.count <= 1

        // Keep the active file visible even in a long batch.
        let active = queue.firstIndex { $0.state == .active } ?? 0
        queueBox.setAccessibilityLabel(Copy.queuePosition(active + 1, queue.count))
        let start = max(0, min(active - 1, max(0, queue.count - 4)))
        let end = min(queue.count, start + 4)
        let visible = Array(queue[start..<end].enumerated())
        if start > 0 {
            let before = NSTextField(labelWithString: "…")
            before.font = Typo.caption
            before.textColor = Palette.muted
            queueStack.addArrangedSubview(before)
        }

        for (offset, item) in visible {
            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: symbol(for: item.state), accessibilityDescription: nil)
            icon.contentTintColor = color(for: item.state)
            icon.imageScaling = .scaleProportionallyDown
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 13),
                icon.heightAnchor.constraint(equalToConstant: 13)
            ])

            let label = NSTextField(labelWithString: item.name)
            label.font = item.state == .active ? Typo.labelStrong : Typo.caption
            label.textColor = item.state == .active ? Palette.ink : Palette.muted
            label.lineBreakMode = .byTruncatingMiddle
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.init(250), for: .horizontal)

            let position = NSTextField(labelWithString: "\(start + offset + 1)")
            position.font = Typo.captionDigits
            position.textColor = Palette.muted.withAlphaComponent(0.7)
            position.alignment = .right
            position.widthAnchor.constraint(equalToConstant: 14).isActive = true

            let row = NSStackView(views: [icon, label, NSView(), position])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = Space.s
            row.translatesAutoresizingMaskIntoConstraints = false
            queueStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: queueStack.widthAnchor).isActive = true
        }

        if end < queue.count {
            let more = NSTextField(labelWithString: Copy.queueMore(queue.count - end))
            more.font = Typo.caption
            more.textColor = Palette.muted
            queueStack.addArrangedSubview(more)
        }
    }

    private func symbol(for state: QueueItem.State) -> String {
        switch state {
        case .pending: "circle"
        case .active: "waveform"
        case .done: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private func color(for state: QueueItem.State) -> NSColor {
        switch state {
        case .pending: Palette.muted.withAlphaComponent(0.55)
        case .active: Palette.accent
        case .done: Palette.muted
        case .failed: Palette.accentText
        }
    }
}
