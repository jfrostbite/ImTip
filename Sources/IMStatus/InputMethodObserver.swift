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
            let this = Unmanaged<InputMethodObserver>.fromOpaque(refcon!).takeUnretainedValue()
            DispatchQueue.main.async {
                this.handleFocusChange()
            }
        }, &observer)
        
        guard error == .success, let observer = observer else { return }
        
        focusObserver = observer
        let retained = Unmanaged.passRetained(self)
        
        // 监听更多的焦点相关事件
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // 监听文本输入变化
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleFocusChange()
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleFocusChange()
        }
        
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
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = getFocusedElement(for: app) else { return }
        
        // 检查更多的文本输入相关属性
        var isTextInput: DarwinBoolean = false
        AXUIElementIsAttributeSettable(focusedElement, kAXValueAttribute as CFString, &isTextInput)
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String
        
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        
        if isTextInput.boolValue || (roleStr != nil && textRoles.contains(roleStr!)) {
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
        // 尝试获取插入点位置
        if let app = NSWorkspace.shared.frontmostApplication,
           let focusedElement = getFocusedElement(for: app) {
            
            // 先尝试获取插入点位置
            var caretPosition: CFTypeRef?
            if AXUIElementCopyAttributeValue(focusedElement, kAXInsertionPointLineNumberAttribute as CFString, &caretPosition) == .success {
                var bounds: CFTypeRef?
                if AXUIElementCopyAttributeValue(focusedElement, kAXBoundsAttribute as CFString, &bounds) == .success {
                    var rect = CGRect.zero
                    AXValueGetValue(bounds as! AXValue, .cgRect, &rect)
                    
                    // 获取窗口位置
                    var windowElement: AXUIElement?
                    var position = CGPoint.zero
                    if AXUIElementCopyAttributeValue(focusedElement, kAXWindowAttribute as CFString, &windowElement) == .success,
                       let window = windowElement,
                       AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &bounds) == .success {
                        AXValueGetValue(bounds as! AXValue, .cgPoint, &position)
                        
                        // 计算屏幕坐标
                        let screenPoint = NSPoint(
                            x: position.x + rect.origin.x,
                            y: position.y + rect.origin.y + rect.height + 5
                        )
                        statusWindow?.show(text: text, at: screenPoint)
                        return
                    }
                }
            }
        }
        
        // 如果无法获取插入点位置，则使用鼠标位置但稍微调整
        let mouseLocation = NSEvent.mouseLocation
        let screenPoint = NSPoint(x: mouseLocation.x, y: mouseLocation.y + 25)
        statusWindow?.show(text: text, at: screenPoint)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        if let observer = focusObserver {
            CFRunLoopRemoveSource(
                RunLoop.current.getCFRunLoop(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
    }
} 