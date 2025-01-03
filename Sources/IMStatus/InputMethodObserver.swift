import Cocoa
import InputMethodKit
import Carbon

class InputMethodObserver: NSObject {
    private var statusItem: NSStatusItem?
    private var lastInputSource: TISInputSource?
    private var statusWindow: StatusWindow?
    private var focusObserver: AXObserver?
    
    override init() {
        super.init()
        statusWindow = StatusWindow()
        setupMenuBar()
        setupFocusObserver()
        startObservingInputMethod()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⌨️"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    private func setupFocusObserver() {
        // 创建焦点观察器
        var observer: AXObserver?
        let error = AXObserverCreate(ProcessInfo.processInfo.processIdentifier, { (observer, element, notification, refcon) in
            guard let this = Unmanaged<InputMethodObserver>.fromOpaque(refcon!).takeUnretainedValue() else { return }
            this.handleFocusChange()
        }, &observer)
        
        guard error == .success, let observer = observer else { return }
        
        // 保存观察器引用
        focusObserver = observer
        
        // 添加全局焦点变化通知
        let applicationObserver = NSWorkspace.shared.notificationCenter
        applicationObserver.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // 启动观察器
        CFRunLoopAddSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }
    
    @objc private func applicationActivated(_ notification: Notification) {
        handleFocusChange()
    }
    
    private func handleFocusChange() {
        // 获取当前焦点元素
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = getFocusedElement(for: app) else { return }
        
        // 检查元素是否可以接受文本输入
        var isTextInput: DarwinBoolean = false
        AXUIElementIsAttributeSettable(focusedElement, kAXValueAttribute as CFString, &isTextInput)
        
        if isTextInput.boolValue {
            // 显示当前输入法状态
            if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                let name = getInputSourceName(source)
                showFloatingStatus(name)
            }
        }
    }
    
    private func getFocusedElement(for app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard error == .success else { return nil }
        return (focusedElement as! AXUIElement)
    }
    
    private func startObservingInputMethod() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }
    
    @objc private func inputSourceChanged() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        updateStatusDisplay(source)
        lastInputSource = source
    }
    
    private func updateStatusDisplay(_ source: TISInputSource) {
        let name = getInputSourceName(source)
        showFloatingStatus(name)
    }
    
    private func getInputSourceName(_ source: TISInputSource) -> String {
        let cfName = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        return (Unmanaged<CFString>.fromOpaque(cfName!).takeUnretainedValue() as String)
    }
    
    private func showFloatingStatus(_ text: String) {
        let mouseLocation = NSEvent.mouseLocation
        let screenPoint = NSPoint(x: mouseLocation.x, y: mouseLocation.y - 50)
        statusWindow?.show(text: text, at: screenPoint)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
} 