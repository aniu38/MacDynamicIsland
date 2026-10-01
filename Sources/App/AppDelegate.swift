import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为后台常驻 Accessory 应用（无 Dock 大图标，纯顶部灵动岛与 MenuBar 控制）
        NSApp.setActivationPolicy(.accessory)
        
        IslandPanelManager.shared.setupWindow()
    }
}
