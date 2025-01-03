import Cocoa
import CoreGraphics

class IconGenerator {
    static func generateIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 设置背景
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        // 绘制键盘图标
        let keyboardPath = NSBezierPath()
        let rect = NSRect(x: 50, y: 100, width: 412, height: 312)
        keyboardPath.appendRoundedRect(rect, xRadius: 30, yRadius: 30)
        
        // 键盘颜色
        NSColor.white.set()
        keyboardPath.fill()
        
        NSColor.black.withAlphaComponent(0.8).set()
        keyboardPath.lineWidth = 8
        keyboardPath.stroke()
        
        // 绘制按键
        let keys = [
            NSRect(x: 80, y: 320, width: 40, height: 40),
            NSRect(x: 130, y: 320, width: 40, height: 40),
            NSRect(x: 180, y: 320, width: 40, height: 40),
            NSRect(x: 230, y: 320, width: 40, height: 40),
            NSRect(x: 280, y: 320, width: 40, height: 40),
            NSRect(x: 330, y: 320, width: 40, height: 40),
            NSRect(x: 380, y: 320, width: 40, height: 40),
            
            NSRect(x: 100, y: 270, width: 40, height: 40),
            NSRect(x: 150, y: 270, width: 40, height: 40),
            NSRect(x: 200, y: 270, width: 40, height: 40),
            NSRect(x: 250, y: 270, width: 40, height: 40),
            NSRect(x: 300, y: 270, width: 40, height: 40),
            NSRect(x: 350, y: 270, width: 40, height: 40),
            
            NSRect(x: 120, y: 220, width: 40, height: 40),
            NSRect(x: 170, y: 220, width: 40, height: 40),
            NSRect(x: 220, y: 220, width: 40, height: 40),
            NSRect(x: 270, y: 220, width: 40, height: 40),
            NSRect(x: 320, y: 220, width: 40, height: 40),
            
            NSRect(x: 140, y: 170, width: 200, height: 40)
        ]
        
        for keyRect in keys {
            let path = NSBezierPath(roundedRect: keyRect, xRadius: 5, yRadius: 5)
            NSColor.black.withAlphaComponent(0.1).set()
            path.fill()
            NSColor.black.withAlphaComponent(0.3).set()
            path.lineWidth = 2
            path.stroke()
        }
        
        image.unlockFocus()
        return image
    }
    
    static func saveIcon() {
        let image = generateIcon()
        let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let pngData = imageRep.representation(using: .png, properties: [:])!
        
        // 保存不同尺寸的图标
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        
        for size in sizes {
            let sizedImage = NSImage(size: NSSize(width: size, height: size))
            sizedImage.lockFocus()
            image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            sizedImage.unlockFocus()
            
            if let tiffData = sizedImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: "icon_\(size).png"))
            }
        }
    }
} 