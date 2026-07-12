import Cocoa

struct RecentChatSession {
    let sessionId: String
    let projectPath: String
    let title: String
    let modifiedAt: Date
}

enum RecentChatsStore {
    private static let peekByteLimit = 32 * 1024

    static func recentSessions(limit: Int = 30) -> [RecentChatSession] {
        let fm = FileManager.default
        let projectsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        guard let projectDirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var sessions: [RecentChatSession] = []
        for projectDir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? fm.attributesOfItem(atPath: file.path),
                      let modDate = attrs[.modificationDate] as? Date else { continue }
                guard let peeked = peekSession(url: file) else { continue }
                let sessionId = file.deletingPathExtension().lastPathComponent
                sessions.append(RecentChatSession(
                    sessionId: sessionId,
                    projectPath: peeked.cwd,
                    title: peeked.title,
                    modifiedAt: modDate
                ))
            }
        }
        sessions.sort { $0.modifiedAt > $1.modifiedAt }
        return Array(sessions.prefix(limit))
    }

    private static func peekSession(url: URL) -> (cwd: String, title: String)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: peekByteLimit), let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var cwd: String?
        var aiTitle: String?
        var firstUserMessage: String?

        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            if cwd == nil, let c = obj["cwd"] as? String {
                cwd = c
            }
            if aiTitle == nil, obj["type"] as? String == "ai-title", let title = obj["aiTitle"] as? String {
                aiTitle = title
            }
            if firstUserMessage == nil,
               obj["isMeta"] as? Bool != true,
               let message = obj["message"] as? [String: Any],
               message["role"] as? String == "user",
               let content = message["content"] as? String,
               !content.hasPrefix("<") {
                firstUserMessage = content
            }
        }

        guard let finalCwd = cwd else { return nil }
        let title = aiTitle ?? firstUserMessage.map { String($0.prefix(120)) } ?? "(untitled session)"
        return (finalCwd, title)
    }
}

final class AccentSelectionRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        TerminalTheme.accentColor.setFill()
        bounds.fill()
    }
}

final class RecentChatsController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var sessions: [RecentChatSession] = []
    let tableView = NSTableView()
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
    var onSelect: ((RecentChatSession) -> Void)?

    var view: NSView { scrollView }

    override init() {
        super.init()
        setupTableView()
        reload()
    }

    private func setupTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ChatColumn"))
        column.title = "Recent Chats"
        column.width = scrollView.frame.width
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.style = .plain
        tableView.backgroundColor = TerminalTheme.backgroundColor
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = TerminalTheme.rowHeight
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        tableView.target = self
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.autoresizingMask = [.width, .height]

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = TerminalTheme.backgroundColor
    }

    @objc func reload() {
        sessions = RecentChatsStore.recentSessions()
        tableView.reloadData()
    }

    @objc private func handleDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < sessions.count else { return }
        onSelect?(sessions[row])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        AccentSelectionRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let session = sessions[row]
        let identifier = NSUserInterfaceItemIdentifier("ChatCell")
        let cellView: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }
        cellView.textField?.stringValue = session.title
        cellView.textField?.font = TerminalTheme.font
        cellView.textField?.textColor = TerminalTheme.textColor
        let projectName = URL(fileURLWithPath: session.projectPath).lastPathComponent
        let formatter = RelativeDateTimeFormatter()
        let relativeTime = formatter.localizedString(for: session.modifiedAt, relativeTo: Date())
        cellView.toolTip = "\(projectName) — \(relativeTime)\n\(session.projectPath)"
        return cellView
    }
}
