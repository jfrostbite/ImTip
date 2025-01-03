import Cocoa

class IconGenerator {
    static func generateAppIcon() -> NSImage {
        let size = NSSize(width: 1024, height: 1024)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 绘制渐变背景
        let gradient = NSGradient(colors: [
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        ])!
        gradient.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // 绘制键盘图标
        let text = "⌨️"
        let font = NSFont.systemFont(ofSize: 512)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
} 