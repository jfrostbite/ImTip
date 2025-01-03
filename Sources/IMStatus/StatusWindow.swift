import Cocoa

class StatusWindow: NSWindow {
    private let label = NSTextField()
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setup()
    }
    
    private func setup() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        contentView = NSView()
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        contentView?.layer?.cornerRadius = 6
        
        if let contentView = contentView {
            label.frame = contentView.bounds.insetBy(dx: 10, dy: 5)
            contentView.addSubview(label)
        }
    }
    
    func show(text: String, at point: NSPoint) {
        label.stringValue = text
        setFrameOrigin(point)
        orderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.orderOut(nil)
        }
    }
} 