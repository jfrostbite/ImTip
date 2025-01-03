import Cocoa

if CommandLine.arguments.contains("--generate-icon") {
    IconGenerator.saveIcon()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 