import Cocoa

final class FileSystemItem {
    let url: URL
    let isDirectory: Bool
    private var cachedChildren: [FileSystemItem]?

    init(url: URL) {
        self.url = url
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
    }

    var name: String { url.lastPathComponent }

    var children: [FileSystemItem] {
        if let cachedChildren { return cachedChildren }
        guard isDirectory else {
            cachedChildren = []
            return []
        }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
        let sorted = contents.sorted { a, b in
            let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if aDir != bDir { return aDir && !bDir }
            return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
        }
        let items = sorted.map { FileSystemItem(url: $0) }
        cachedChildren = items
        return items
    }

    func invalidateChildren() {
        cachedChildren = nil
    }
}

final class FileExplorerController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    let rootItem: FileSystemItem
    let outlineView = NSOutlineView()
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))

    var view: NSView { scrollView }

    init(rootURL: URL) {
        self.rootItem = FileSystemItem(url: rootURL)
        super.init()
        setupOutlineView()
        outlineView.reloadData()
    }

    private func setupOutlineView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = "Name"
        column.width = scrollView.frame.width
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.style = .plain
        outlineView.backgroundColor = TerminalTheme.backgroundColor
        outlineView.selectionHighlightStyle = .regular
        outlineView.rowHeight = TerminalTheme.rowHeight
        outlineView.autoresizesOutlineColumn = true
        outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outlineView.autoresizingMask = [.width, .height]
        outlineView.doubleAction = #selector(handleDoubleClick(_:))
        outlineView.target = self
        outlineView.menu = makeContextMenu()

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = TerminalTheme.backgroundColor
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh(_:)), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        return menu
    }

    @objc private func handleDoubleClick(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0, let node = sender.item(atRow: row) as? FileSystemItem else { return }
        if node.isDirectory {
            if sender.isItemExpanded(node) {
                sender.collapseItem(node)
            } else {
                sender.expandItem(node)
            }
        } else {
            NSWorkspace.shared.open(node.url)
        }
    }

    @objc private func revealInFinder(_ sender: Any) {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileSystemItem else {
            NSWorkspace.shared.activateFileViewerSelecting([rootItem.url])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    @objc private func refresh(_ sender: Any) {
        let row = outlineView.clickedRow
        let node = (row >= 0 ? outlineView.item(atRow: row) as? FileSystemItem : nil) ?? rootItem
        node.invalidateChildren()
        if node === rootItem {
            outlineView.reloadData()
        } else {
            outlineView.reloadItem(node, reloadChildren: true)
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = (item as? FileSystemItem) ?? rootItem
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = (item as? FileSystemItem) ?? rootItem
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileSystemItem)?.isDirectory ?? false
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileSystemItem else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("FileCell")
        let cellView: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle

            cellView.addSubview(imageView)
            cellView.addSubview(textField)
            cellView.imageView = imageView
            cellView.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }
        cellView.textField?.stringValue = node.name
        cellView.textField?.font = TerminalTheme.font
        cellView.textField?.textColor = TerminalTheme.textColor
        cellView.imageView?.image = NSWorkspace.shared.icon(forFile: node.url.path)
        return cellView
    }
}
