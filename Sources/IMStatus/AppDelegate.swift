import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var observer: InputMethodObserver?
    private var statusWindow: StatusWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusWindow = StatusWindow()
        observer = InputMethodObserver(statusWindow: statusWindow!)
        
        requestAccessibilityPermission()
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
} 