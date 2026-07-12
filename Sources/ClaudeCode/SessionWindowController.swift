import Cocoa
import SwiftTerm

final class SessionWindowController: NSWindowController {
    let rootURL: URL
    let resumeSessionId: String?
    weak var appDelegate: AppDelegate?

    var terminalView: LocalProcessTerminalView!
    var explorer: FileExplorerController!
    var recentChats: RecentChatsController!
    private var mainSplitView: NSSplitView!

    init(rootURL: URL, appDelegate: AppDelegate, resumeSessionId: String? = nil) {
        self.rootURL = rootURL
        self.appDelegate = appDelegate
        self.resumeSessionId = resumeSessionId

        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 1520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        let chosenPath = rootURL.path

        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        terminalView.allowMouseReporting = false
        terminalView.nativeBackgroundColor = TerminalTheme.backgroundColor
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l", "-c", "cd \(shellEscape(chosenPath)) && \(launchClaudeCommand)"],
            environment: nil,
            execName: "-zsh"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(NSMenuItem.separator())
        let exitItem = NSMenuItem(title: "Exit Claude", action: #selector(sendExit), keyEquivalent: "")
        exitItem.target = self
        menu.addItem(exitItem)
        terminalView.menu = menu
        self.terminalView = terminalView

        let explorer = FileExplorerController(rootURL: rootURL)
        self.explorer = explorer

        let recentChats = RecentChatsController()
        recentChats.onSelect = { [weak self] session in
            self?.appDelegate?.openSession(for: URL(fileURLWithPath: session.projectPath), resumeSessionId: session.sessionId)
        }
        self.recentChats = recentChats

        let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1520, height: 600))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addArrangedSubview(explorer.view)
        splitView.addArrangedSubview(terminalView)
        splitView.addArrangedSubview(recentChats.view)
        splitView.setHoldingPriority(.defaultLow + 2, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        splitView.setHoldingPriority(.defaultLow + 1, forSubviewAt: 2)
        self.mainSplitView = splitView

        window?.title = "Claude Code — \(rootURL.lastPathComponent)"
        window?.contentView = splitView
        splitView.layoutSubtreeIfNeeded()
        splitView.setPosition(300, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        splitView.setPosition(splitView.bounds.width - 300, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()
    }

    func presentWindow() {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(terminalView)
    }

    @objc func sendExit() {
        terminalView.send(txt: "/exit\r")
    }

    @objc func toggleFileExplorer() {
        explorer.view.isHidden.toggle()
    }

    @objc func toggleRecentChats() {
        recentChats.view.isHidden.toggle()
    }

    private func shellEscape(_ path: String) -> String {
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private var launchClaudeCommand: String {
        let fallbackPaths = [
            "$HOME/.local/bin/claude",
            "$HOME/.claude/local/claude",
            "$HOME/.npm-global/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        let resumeArgs = resumeSessionId.map { " --resume \(shellEscape($0))" } ?? ""
        let fallbackChecks = fallbackPaths
            .map { "elif [ -x \"\($0)\" ]; then exec \"\($0)\"\(resumeArgs)" }
            .joined(separator: "\n            ")
        return """
        if command -v claude >/dev/null 2>&1; then
            exec claude\(resumeArgs)
        \(fallbackChecks)
        else
            echo "Claude Code isn't installed yet — installing it now..."
            echo
            curl -fsSL https://claude.ai/install.sh | bash
            echo
            if [ -x "$HOME/.local/bin/claude" ]; then
                exec "$HOME/.local/bin/claude"\(resumeArgs)
            elif command -v claude >/dev/null 2>&1; then
                exec claude\(resumeArgs)
            else
                echo "Install failed. Install Claude Code manually: https://docs.claude.com/claude-code"
                exec zsh
            fi
        fi
        """
    }
}

extension SessionWindowController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        switch dividerIndex {
        case 0: return 220
        case 1: return max(proposedMinimumPosition, splitView.frame.width - 500)
        default: return proposedMinimumPosition
        }
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        switch dividerIndex {
        case 0: return 500
        case 1: return splitView.frame.width - 220
        default: return proposedMaximumPosition
        }
    }
}
