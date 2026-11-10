import AppKit
import VoceKit

/// First screen: brand, drop zone, optional message, and recent transcripts.
final class IdleView: NSView {
    var onChoose: (() -> Void)? {
        didSet { dropZone.onClick = onChoose }
    }
    var onSetup: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenRecent: ((TranscriptSummary) -> Void)?

    private let dropZone = DropZoneView()
    var focusTarget: NSView { dropZone }

    private let wordmark = NSTextField(labelWithString: "Voce")
    private let accentDot = NSView()
    private let statusPill = PillView()
    private let settingsButton = NSButton()
    private let mark = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let formatsLabel = NSTextField(labelWithString: "")
    private let setupButton = ActionButton(title: "", target: nil, action: nil)
    private let banner = MessageBanner()

    private let recentTitle = NSTextField(labelWithString: "")
    private let recentCount = NSTextField(labelWithString: "")
    private let recentCard = CardView()
    private let recentRows = NSStackView()

    private var hasKey = true
    private var baseTitle = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Public

    func update(
        hasKey: Bool,
        model: TranscriptionModel,
        language: TranscriptionLanguage,
        recent: [TranscriptSummary],
        historyEnabled: Bool
    ) {
        self.hasKey = hasKey
        titleLabel.font = hasKey ? Typo.display : Typo.title
        titleLabel.stringValue = hasKey ? Copy.idleTitle : Copy.setupTitle
        baseTitle = titleLabel.stringValue
        subtitleLabel.stringValue = hasKey ? Copy.idleSubtitle : Copy.setupBody
        formatsLabel.stringValue = Copy.idleMeta
        formatsLabel.isHidden = !hasKey
        setupButton.title = Copy.setupButton
        setupButton.isHidden = hasKey
        statusPill.setText(Copy.idleStatus(model: model, language: language))
        dropZone.setAccessibilityLabel(hasKey ? Copy.idleTitle : Copy.setupTitle)
        dropZone.setAccessibilityHelp(hasKey ? Copy.idleSubtitle : Copy.setupBody)
        refreshRecent(historyEnabled ? recent : [])
        needsLayout = true
    }

    func setDropTargeted(_ targeted: Bool) {
        dropZone.targeted = targeted
        titleLabel.stringValue = targeted && hasKey ? Copy.dropHere : baseTitle
    }

    /// Shows a message under the drop zone; nil hides it.
    func show(message: String?, isError: Bool = true, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        banner.show(
            message: message,
            style: isError ? .error : .info,
            actionTitle: actionTitle,
            action: action
        )
        needsLayout = true
    }

    // MARK: - Building

    private func build() {
        wordmark.font = Typo.headline
        wordmark.textColor = Palette.ink
        wordmark.setAccessibilityElement(false)

        accentDot.wantsLayer = true
        accentDot.layer?.cornerRadius = 3
        accentDot.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: Copy.settings)
        settingsButton.isBordered = false
        settingsButton.bezelStyle = .inline
        settingsButton.contentTintColor = Palette.muted
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.toolTip = Copy.settings + " (⌘,)"
        settingsButton.setAccessibilityLabel(Copy.settings)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        let brand = NSStackView(views: [wordmark, accentDot])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 5
        brand.setContentHuggingPriority(.required, for: .horizontal)

        let topBar = NSStackView(views: [brand, statusPill, NSView(), settingsButton])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY
        topBar.spacing = Space.m
        topBar.translatesAutoresizingMaskIntoConstraints = false

        // Drop zone content
        mark.image = Assets.icon()
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.setAccessibilityElement(false)
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 76),
            mark.heightAnchor.constraint(equalToConstant: 76)
        ])

        titleLabel.applyStyle(font: Typo.display, color: Palette.ink, lines: 2)
        subtitleLabel.applyStyle(font: Typo.label, color: Palette.muted, lines: 0)
        subtitleLabel.preferredMaxLayoutWidth = 420
        formatsLabel.applyStyle(font: Typo.caption, color: Palette.muted, lines: 1)

        setupButton.style(accent: true)
        setupButton.target = self
        setupButton.action = #selector(setupClicked)
        setupButton.isHidden = true
        setupButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [mark, titleLabel, subtitleLabel, setupButton, formatsLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.l, after: mark)
        stack.setCustomSpacing(Space.xs, after: titleLabel)
        stack.setCustomSpacing(Space.l, after: subtitleLabel)
        stack.setCustomSpacing(Space.l, after: setupButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(stack)
        dropZone.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: dropZone.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: dropZone.trailingAnchor, constant: -Space.xl)
        ])

        banner.isHidden = true
        banner.translatesAutoresizingMaskIntoConstraints = false

        // Recent transcripts
        recentTitle.stringValue = Copy.recentTitle
        recentTitle.font = Typo.headline
        recentTitle.textColor = Palette.ink
        recentCount.font = Typo.caption
        recentCount.textColor = Palette.muted

        let recentHeader = NSStackView(views: [recentTitle, NSView(), recentCount])
        recentHeader.orientation = .horizontal
        recentHeader.alignment = .centerY
        recentHeader.translatesAutoresizingMaskIntoConstraints = false

        recentRows.orientation = .vertical
        recentRows.alignment = .leading
        recentRows.spacing = Space.xxs
        recentRows.translatesAutoresizingMaskIntoConstraints = false

        recentCard.translatesAutoresizingMaskIntoConstraints = false
        recentCard.addSubview(recentRows)
        NSLayoutConstraint.activate([
            recentRows.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor, constant: 6),
            recentRows.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor, constant: -6),
            recentRows.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 6),
            recentRows.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -6)
        ])

        let recentSection = NSStackView(views: [recentHeader, recentCard])
        recentSection.orientation = .vertical
        recentSection.alignment = .leading
        recentSection.spacing = Space.s
        recentSection.translatesAutoresizingMaskIntoConstraints = false
        recentSection.isHidden = true
        self.recentSection = recentSection

        let root = NSStackView(views: [topBar, dropZone, banner, recentSection])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = Space.l
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        dropZone.setContentHuggingPriority(.init(1), for: .vertical)
        dropZone.setContentCompressionResistancePriority(.init(1), for: .vertical)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.side),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.side),
            root.topAnchor.constraint(equalTo: topAnchor, constant: Layout.top - 8),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.bottom),

            topBar.widthAnchor.constraint(equalTo: root.widthAnchor),
            dropZone.widthAnchor.constraint(equalTo: root.widthAnchor),
            dropZone.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            banner.widthAnchor.constraint(equalTo: root.widthAnchor),
            recentSection.widthAnchor.constraint(equalTo: root.widthAnchor),
            recentHeader.widthAnchor.constraint(equalTo: recentSection.widthAnchor),
            recentCard.widthAnchor.constraint(equalTo: recentSection.widthAnchor),

            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),
            accentDot.widthAnchor.constraint(equalToConstant: 6),
            accentDot.heightAnchor.constraint(equalToConstant: 6)
        ])

        effectiveAppearance.performAsCurrentDrawingAppearance {
            accentDot.layer?.backgroundColor = Palette.accent.cgColor
        }
    }

    private var recentSection: NSStackView?

    private func refreshRecent(_ summaries: [TranscriptSummary]) {
        recentRows.arrangedSubviews.forEach {
            recentRows.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let visible = Array(summaries.prefix(4))
        for summary in visible {
            let row = RecentRowView()
            row.show(summary)
            row.onOpen = { [weak self] in self?.onOpenRecent?(summary) }
            row.translatesAutoresizingMaskIntoConstraints = false
            recentRows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: recentRows.widthAnchor).isActive = true
        }
        recentCount.stringValue = visible.isEmpty ? "" : "\(summaries.count)"
        recentSection?.isHidden = visible.isEmpty
        recentCount.isHidden = visible.isEmpty
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            accentDot.layer?.backgroundColor = Palette.accent.cgColor
        }
    }

    @objc private func setupClicked() { onSetup?() }
    @objc private func openSettings() { onOpenSettings?() }
}
