import Cocoa
import InputMethodKit
import Carbon

class InputMethodObserver: NSObject {
    private var statusItem: NSStatusItem?
    private var lastInputSource: TISInputSource?
    private weak var statusWindow: StatusWindow?
    private var focusObserver: AXObserver?
    private var lastFocusedElement: AXUIElement?
    private var lastShowTime: Date = .distantPast
    private var isTyping: Bool = false
    private var typingTimer: Timer?
    
    init(statusWindow: StatusWindow) {
        self.statusWindow = statusWindow
        super.init()
        setupMenuBar()
        setupFocusObserver()
        startObservingInputMethod()
        
        // 监听键盘事件来检测输入间隔
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown()
            return event
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⌨️"
        
        let menu = NSMenu()
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
        _ = Unmanaged.passRetained(self)
        
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
    
    private func handleKeyDown() {
        isTyping = true
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.isTyping = false
        }
    }
    
    private func handleFocusChange() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let focusedElement = getFocusedElement(for: app) else { return }
        
        // 检查是否是新的焦点元素
        let isSameElement = lastFocusedElement.map { element -> Bool in
            var isEqual: DarwinBoolean = false
            AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isEqual)
            return CFEqual(element, focusedElement)
        } ?? false
        
        lastFocusedElement = focusedElement
        
        // 检查是否是文本输入区域
        var isTextInput: DarwinBoolean = false
        AXUIElementIsAttributeSettable(focusedElement, kAXValueAttribute as CFString, &isTextInput)
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String
        
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        let isTextArea = isTextInput.boolValue || (roleStr != nil && textRoles.contains(roleStr!))
        
        // 决定是否显示提示
        let now = Date()
        let timeSinceLastShow = now.timeIntervalSince(lastShowTime)
        
        let shouldShow = isTextArea && (
            !isSameElement || // 新的输入框
            (timeSinceLastShow > 2.0 && !isTyping) || // 同一输入框但停顿超过2秒
            (timeSinceLastShow > 10.0) // 无论如何，每10秒至少提示一次
        )
        
        if shouldShow {
            if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                let name = getInputSourceName(source)
                showFloatingStatus(name)
                lastShowTime = now
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
        if let app = NSWorkspace.shared.frontmostApplication,
           let focusedElement = getFocusedElement(for: app) {
            
            // 尝试获取选择范围和插入点位置
            var selectionRange: CFTypeRef?
            var textPosition: CFTypeRef?
            
            if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectionRange) == .success,
               AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &textPosition) == .success {
                
                // 获取文本框的位置和大小
                var position: CFTypeRef?
                var bounds: CFTypeRef?
                
                if AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute as CFString, &position) == .success,
                   AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute as CFString, &bounds) == .success {
                    
                    var point = CGPoint.zero
                    var size = CGSize.zero
                    
                    if AXValueGetValue(position as! AXValue, .cgPoint, &point),
                       AXValueGetValue(bounds as! AXValue, .cgSize, &size) {
                        
                        // 获取窗口位置
                        var windowRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(focusedElement, kAXWindowAttribute as CFString, &windowRef) == .success,
                           CFGetTypeID(windowRef!) == AXUIElementGetTypeID() {
                            let windowElement = windowRef as! AXUIElement
                            
                            var windowPosition: CFTypeRef?
                            if AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &windowPosition) == .success {
                                
                                var windowPoint = CGPoint.zero
                                if AXValueGetValue(windowPosition as! AXValue, .cgPoint, &windowPoint) {
                                    // 计算相对于窗口的位置
                                    let relativePoint = CGPoint(
                                        x: point.x - windowPoint.x,
                                        y: point.y - windowPoint.y
                                    )
                                    
                                    // 使用固定的行高
                                    let lineHeight: CGFloat = 20
                                    
                                    // 计算最终屏幕坐标
                                    let screenPoint = NSPoint(
                                        x: windowPoint.x + relativePoint.x,
                                        y: windowPoint.y + relativePoint.y + lineHeight
                                    )
                                    
                                    statusWindow?.show(text: text, at: screenPoint)
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 如果无法获取准确位置，使用鼠标位置作为备选
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