# IMStatus

IMStatus 是一个 macOS 输入法状态提示工具，它会在你需要输入文字时自动显示当前输入法状态，帮助你提前确认输入法，避免输入错误。

## 功能特点

- 自动检测文本输入区域
- 智能显示输入法状态
- 在光标位置附近显示提示
- 支持 Intel 和 Apple Silicon 芯片
- 轻量级系统托盘应用
- 无需配置，即装即用

## 安装方法

1. 下载最新的 DMG 文件
2. 打开 DMG 文件
3. 将 IMStatus.app 拖到 Applications 文件夹
4. 首次运行时需要授予辅助功能权限

## 使用说明

- 程序启动后会在系统菜单栏显示一个键盘图标 ⌨️
- 当你点击文本输入区域时，会自动显示当前输入法状态
- 在同一输入区域停顿超过 2 秒后继续输入时会再次提示
- 每 10 秒最多提示一次，避免打扰
- 点击菜单栏图标可以退出程序

## 系统要求

- macOS 12.0 或更高版本
- 需要辅助功能权限

## 开发说明

本项目使用 Swift 开发，依赖以下框架：

- Cocoa
- InputMethodKit
- Carbon

构建项目：

```bash
swift build
```

生成 Xcode 项目：

```bash
swift package generate-xcodeproj
```

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 致谢

本项目受 [ImTip](https://github.com/aardio/ImTip) 启发。