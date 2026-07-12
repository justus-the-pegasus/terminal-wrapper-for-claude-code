import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.mainMenu = buildMainMenu(target: delegate)
app.setActivationPolicy(.regular)
app.run()
