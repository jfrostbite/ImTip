import Cocoa
import InputMethodKit

class InputMethodObserver: NSObject {
    private var statusItem: NSStatusItem?
    private var lastInputSource: TISInputSource?
    private var statusWindow: StatusWindow?
    
    override init() {
        super.init()
        statusWindow = StatusWindow()
        setupMenuBar()
        startObservingInputMethod()
        startObservingTextInput()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
        }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
    }
    
    private func startObservingInputMethod() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }
    
    private func startObservingTextInput() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.checkInputMethod()
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let window = self?.statusWindow, window.isVisible {
                window.orderOut(nil)
            }
        }
    }
    
    private func checkInputMethod() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        let name = getInputSourceName(source)
        
        // 获取当前光标位置
        if let position = getCurrentCaretPosition() {
            showFloatingStatus(name, at: position)
        }
    }
    
    private func getCurrentCaretPosition() -> NSPoint? {
        if let app = NSWorkspace.shared.frontmostApplication {
            let pid = app.processIdentifier
            
            let axApp = AXUIElementCreateApplication(pid)
            var focusedElement: AXUIElement?
            var position = NSPoint.zero
            var size = NSSize.zero
            
            AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement as UnsafeMutablePointer<CFTypeRef?>)
            
            if let element = focusedElement {
                var value: AnyObject?
                AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
                if let positionValue = value as? AXValue {
                    AXValueGetValue(positionValue, .cgPoint, &position)
                }
                
                AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
                if let sizeValue = value as? AXValue {
                    AXValueGetValue(sizeValue, .cgSize, &size)
                }
                
                // 返回输入框上方的位置
                return NSPoint(x: position.x, y: position.y + size.height)
            }
        }
        return nil
    }
    
    @objc private func inputSourceChanged() {
        checkInputMethod()
    }
    
    private func getInputSourceName(_ source: TISInputSource) -> String {
        let cfName = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        return (Unmanaged<CFString>.fromOpaque(cfName!).takeUnretainedValue() as String)
    }
    
    private func showFloatingStatus(_ text: String, at point: NSPoint) {
        statusWindow?.show(text: text, at: point)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
} 