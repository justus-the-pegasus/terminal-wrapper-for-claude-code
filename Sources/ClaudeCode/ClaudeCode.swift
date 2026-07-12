import Cocoa
import SwiftTerm

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var activeTerminalView: LocalProcessTerminalView?
    var fileExplorerController: FileExplorerController?
    var splitView: NSSplitView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NSOpenPanel()
        panel.title = "Choose a project directory"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Unleash Claude"

        let response = panel.runModal()

        guard response == .OK, let chosenURL = panel.url else {
            NSApp.terminate(nil)
            return
        }

        let chosenPath = chosenURL.path

        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        terminalView.allowMouseReporting = false
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

        self.activeTerminalView = terminalView

        let explorer = FileExplorerController(rootURL: chosenURL)
        self.fileExplorerController = explorer

        let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1120, height: 600))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addArrangedSubview(explorer.view)
        splitView.addArrangedSubview(terminalView)
        splitView.setHoldingPriority(.defaultLow + 1, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        self.splitView = splitView

        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 1120, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Code — \(chosenURL.lastPathComponent)"
        window.contentView = splitView
        splitView.setPosition(220, ofDividerAt: 0)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(terminalView)
    }

    @objc func sendExit() {
        activeTerminalView?.send(txt: "/exit\r")
    }

    @objc func toggleFileExplorer() {
        guard let sidebar = fileExplorerController?.view else { return }
        sidebar.isHidden.toggle()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func shellEscape(_ path: String) -> String {
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    var launchClaudeCommand: String {
        let fallbackPaths = [
            "$HOME/.local/bin/claude",
            "$HOME/.claude/local/claude",
            "$HOME/.npm-global/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        let fallbackChecks = fallbackPaths
            .map { "elif [ -x \"\($0)\" ]; then exec \"\($0)\"" }
            .joined(separator: "\n            ")
        return """
        if command -v claude >/dev/null 2>&1; then
            exec claude
        \(fallbackChecks)
        else
            echo "Claude Code isn't installed yet — installing it now..."
            echo
            curl -fsSL https://claude.ai/install.sh | bash
            echo
            if [ -x "$HOME/.local/bin/claude" ]; then
                exec "$HOME/.local/bin/claude"
            elif command -v claude >/dev/null 2>&1; then
                exec claude
            else
                echo "Install failed. Install Claude Code manually: https://docs.claude.com/claude-code"
                exec zsh
            fi
        fi
        """
    }
}

extension AppDelegate: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        160
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        400
    }
}

func buildMainMenu(target: AppDelegate) -> NSMenu {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu
    let appName = ProcessInfo.processInfo.processName
    appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let editMenuItem = NSMenuItem()
    mainMenu.addItem(editMenuItem)
    let editMenu = NSMenu(title: "Edit")
    editMenuItem.submenu = editMenu
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")

    let viewMenuItem = NSMenuItem()
    mainMenu.addItem(viewMenuItem)
    let viewMenu = NSMenu(title: "View")
    viewMenuItem.submenu = viewMenu
    let toggleExplorerItem = NSMenuItem(title: "Toggle File Browser", action: #selector(AppDelegate.toggleFileExplorer), keyEquivalent: "b")
    toggleExplorerItem.target = target
    viewMenu.addItem(toggleExplorerItem)

    let windowMenuItem = NSMenuItem()
    mainMenu.addItem(windowMenuItem)
    let windowMenu = NSMenu(title: "Window")
    windowMenuItem.submenu = windowMenu
    windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

    return mainMenu
}