import AppKit
import VoceKit

/// Local search across the archived transcripts. Reading at most 100 small JSON files is
/// done off the main thread; the UI only keeps the result rows.
@MainActor
final class HistorySearchWindowController: NSWindowController {
    var onOpen: ((UUID) -> Void)?

    private let archive = TranscriptArchive()
    private let searchField = NSSearchField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let results = NSStackView()
    private var searchTask: Task<Void, Never>?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.historySearchTitle
        window.minSize = NSSize(width: 480, height: 360)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window?.makeFirstResponder(searchField)
        refresh()
    }

    private func build(in window: NSWindow) {
        guard let content = window.contentView else { return }

        searchField.placeholderString = Copy.historySearchPlaceholder
        searchField.font = Typo.body
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.setAccessibilityLabel(Copy.historySearchTitle)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = Typo.caption
        statusLabel.textColor = Palette.muted
        statusLabel.lineBreakMode = .byTruncatingTail

        results.orientation = .vertical
        results.alignment = .leading
        results.spacing = Space.xxs
        results.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(results)

        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [searchField, statusLabel, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xxl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xxl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            searchField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            results.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            results.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            results.topAnchor.constraint(equalTo: document.topAnchor),
            results.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])
    }

    @objc private func searchChanged() {
        refresh()
    }

    private func refresh() {
        searchTask?.cancel()
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        statusLabel.stringValue = query.isEmpty ? Copy.historySearchHint : Copy.historySearchSearching
        let archive = self.archive

        searchTask = Task { [weak self] in
            let hits = await Task.detached {
                if query.isEmpty {
                    return archive.list().prefix(30).map {
                        TranscriptSearchHit(summary: $0, snippet: "")
                    }
                }
                return archive.search(query)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.render(Array(hits), query: query)
        }
    }

    private func render(_ hits: [TranscriptSearchHit], query: String) {
        results.arrangedSubviews.forEach {
            results.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if hits.isEmpty {
            statusLabel.stringValue = query.isEmpty ? Copy.historySearchEmpty : Copy.historySearchNoResults
            return
        }
        statusLabel.stringValue = Copy.historySearchCount(hits.count)

        for hit in hits {
            let row = SearchResultRow()
            row.show(hit)
            row.onOpen = { [weak self] in
                self?.onOpen?(hit.summary.id)
                self?.window?.orderOut(nil)
            }
            row.translatesAutoresizingMaskIntoConstraints = false
            results.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: results.widthAnchor).isActive = true
        }
    }
}
