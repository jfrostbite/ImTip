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
        
        if let position = getCurrentCaretPosition() {
            showFloatingStatus(name, at: position)
        }
    }
    
    private func getCurrentCaretPosition() -> NSPoint? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        
        let axApp = AXUIElementCreateApplication(pid)
        var element: AnyObject?
        
        // 获取焦点元素
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &element)
        guard result == .success, let focusedElement = element else { return nil }
        
        var position = NSPoint.zero
        var size = NSSize.zero
        
        // 获取位置
        var posValue: AnyObject?
        AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXPositionAttribute as CFString, &posValue)
        if let positionValue = posValue {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }
        
        // 获取大小
        var sizeValue: AnyObject?
        AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue)
        if let sizeVal = sizeValue {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }
        
        // 返回输入框上方的位置
        return NSPoint(x: position.x, y: position.y + size.height)
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