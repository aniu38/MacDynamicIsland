import AppKit
import SwiftUI

class CustomIslandPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    private var initialMouseScreenLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    private var isDragging: Bool = false
    
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            initialMouseScreenLocation = NSEvent.mouseLocation
            initialWindowOrigin = self.frame.origin
            isDragging = false
            super.sendEvent(event)
            
        case .leftMouseDragged:
            let currentLocation = NSEvent.mouseLocation
            let dx = currentLocation.x - initialMouseScreenLocation.x
            let dy = currentLocation.y - initialMouseScreenLocation.y
            let dist = hypot(dx, dy)
            
            // 超过 3 像素位移，立即进入拖拽模式，以 120Hz 毫无延迟地移动窗口
            if dist > 3 || isDragging {
                isDragging = true
                let newOrigin = NSPoint(x: initialWindowOrigin.x + dx, y: initialWindowOrigin.y + dy)
                self.setFrameOrigin(newOrigin)
                return
            }
            super.sendEvent(event)
            
        case .leftMouseUp:
            if isDragging {
                isDragging = false
                NSLog("[IslandPanel] 拖拽松开完成，当前窗口原点: \(self.frame.origin)")
                DispatchQueue.main.async {
                    IslandPanelManager.shared.snapToNearestEdgeIfNeeded()
                }
                return // 消费该 mouseUp 事件，防止误触发点击展开或误触控件
            }
            super.sendEvent(event)
            
        default:
            super.sendEvent(event)
        }
    }
}

class IslandPanelManager: NSObject {
    static let shared = IslandPanelManager()
    
    private(set) var window: NSPanel?
    private var statusBarItem: NSStatusItem?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    func setupWindow() {
        let initialWidth: CGFloat = 380
        let initialHeight: CGFloat = 42
        
        let panel = CustomIslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 置顶在系统 MenuBar 与 Notch 层，彻底禁用 AppKit 窗口背景渲染
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        let contentView = NSHostingView(rootView: DynamicIslandView())
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false
        panel.contentView = contentView
        
        self.window = panel
        
        positionAtTopCenter(width: initialWidth, height: initialHeight)
        panel.orderFrontRegardless()
        
        setupStatusBarItem()
        setupGlobalHotkey()
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handlePreviewNotification(_:)),
            name: NSNotification.Name("com.user.MacDynamicIsland.previewPlayer"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExpandNotification(_:)),
            name: NSNotification.Name("com.user.MacDynamicIsland.toggleExpand"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOrientationNotification(_:)),
            name: NSNotification.Name("com.user.MacDynamicIsland.setOrientation"),
            object: nil
        )
    }
    
    @objc func handlePreviewNotification(_ notification: Notification) {
        let sourceName = (notification.object as? String) ?? ""
        DispatchQueue.main.async {
            switch sourceName.lowercased() {
            case "netease":
                self.previewNetease()
            case "qqmusic":
                self.previewQQMusic()
            case "applemusic":
                self.previewAppleMusic()
            case "splayer":
                self.previewSPlayer()
            default:
                self.restoreAutoDetect()
            }
        }
    }
    
    @objc func handleExpandNotification(_ notification: Notification) {
        let val = (notification.object as? String)?.lowercased()
        let target: Bool
        if val == "true" || val == "1" || val == "expand" {
            target = true
        } else if val == "false" || val == "0" || val == "collapse" {
            target = false
        } else {
            target = !DynamicIslandViewModel.shared.isExpanded
        }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                DynamicIslandViewModel.shared.isExpanded = target
                if target && MusicManager.shared.isPlaying {
                    DynamicIslandViewModel.shared.activePageIndex = 0
                }
                self.updateWindowFrameForState(isExpanded: target)
            }
        }
    }
    
    @objc func handleOrientationNotification(_ notification: Notification) {
        // 竖版功能已根据用户要求暂时隐藏，固定保持横向模式
    }
    
    func positionAtTopCenter(width: CGFloat? = nil, height: CGFloat? = nil) {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let windowWidth = width ?? window.frame.size.width
        let windowHeight = height ?? window.frame.size.height
        
        // 精确靠顶，紧贴 Notch 刘海下方
        let topY = screenFrame.maxY - windowHeight - 2
        let centerX = screenFrame.midX - (windowWidth / 2)
        
        window.setFrame(NSRect(x: centerX, y: topY, width: windowWidth, height: windowHeight), display: true, animate: true)
        window.orderFrontRegardless()
    }
    
    func updateWindowFrameForState(isExpanded: Bool) {
        guard let window = window else { return }
        
        let targetWidth: CGFloat = isExpanded ? 740 : 380
        let targetHeight: CGFloat = isExpanded ? 135 : 42
        
        let currentFrame = window.frame
        let topY = currentFrame.maxY - targetHeight
        let centerX = currentFrame.midX - (targetWidth / 2)
        
        let newRect = NSRect(x: centerX, y: topY, width: targetWidth, height: targetHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newRect, display: true)
        }
    }
    
    func snapToNearestEdgeIfNeeded() {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let fullScreenFrame = screen.frame
        let visibleScreenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        let snapThreshold: CGFloat = 120.0
        let margin: CGFloat = 6.0
        
        var targetX = windowFrame.origin.x
        var targetY = windowFrame.origin.y
        var snapped = false
        
        // 1. 优先判定：顶端居中 Notch 刘海磁吸 (接近屏幕上方中央 200px、纵向 150px 范围内)
        let topCenterDistance = abs(windowFrame.midX - fullScreenFrame.midX)
        let topYDistance = abs(fullScreenFrame.maxY - windowFrame.maxY)
        if topCenterDistance < 200 && topYDistance < 150 {
            targetX = fullScreenFrame.midX - (windowFrame.width / 2)
            targetY = fullScreenFrame.maxY - windowFrame.height - 2
            snapped = true
        } else {
            // 2. 左边缘吸附
            if abs(windowFrame.minX - fullScreenFrame.minX) < snapThreshold {
                targetX = fullScreenFrame.minX + margin
                snapped = true
            }
            // 3. 右边缘吸附
            else if abs(fullScreenFrame.maxX - windowFrame.maxX) < snapThreshold {
                targetX = fullScreenFrame.maxX - windowFrame.width - margin
                snapped = true
            }
            
            // 4. 顶边缘吸附 (紧贴顶部 Notch 区域)
            if abs(fullScreenFrame.maxY - windowFrame.maxY) < snapThreshold {
                targetY = fullScreenFrame.maxY - windowFrame.height - 2
                snapped = true
            }
            // 5. 底边缘吸附 (紧贴 Dock / 底部)
            else if abs(windowFrame.minY - visibleScreenFrame.minY) < snapThreshold || abs(windowFrame.minY - fullScreenFrame.minY) < snapThreshold {
                targetY = visibleScreenFrame.minY + margin
                snapped = true
            }
        }
        
        NSLog("[IslandPanel] snapCheck: windowFrame=\(windowFrame), snapped=\(snapped), target=(\(targetX), \(targetY)), topCenterDist=\(topCenterDistance), topYDist=\(topYDistance)")
        
        if snapped {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
            }
            
            NotificationManager.shared.showNotification(
                icon: "magnet.fill",
                iconColor: .yellow,
                title: "屏幕边缘吸附成功",
                subtitle: "灵动岛已精准贴合至屏幕边缘"
            )
        }
    }
    
    func updateWindowSizeForOrientation() {
        guard window != nil else { return }
        positionAtTopCenter(width: 380, height: 42)
        updateStatusBarMenuText()
    }
    
    private func setupGlobalHotkey() {
        // 全局键盘监控：在任何系统应用下按下 Command + Option + R (⌥⌘R) 复位灵动岛位置
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.checkResetShortcut(event: event)
        }
        
        // 应用内键盘监控
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.checkResetShortcut(event: event) == true {
                return nil
            }
            return event
        }
    }
    
    @discardableResult
    private func checkResetShortcut(event: NSEvent) -> Bool {
        // 15 代表 'R' / 'r' 键
        if event.keyCode == 15 {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .option]) || flags.contains(.command) || flags.contains([.control, .command]) {
                DispatchQueue.main.async {
                    self.resetPosition()
                }
                return true
            }
        }
        return false
    }
    
    func setupStatusBarItem() {
        if statusBarItem == nil {
            statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusBarItem?.button {
                button.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Mac 灵动岛")
                button.title = " 灵动岛"
            }
        }
        
        updateStatusBarMenuText()
    }
    
    private func updateStatusBarMenuText() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "🏝️ Mac 灵动岛 (Dynamic Island)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🧲 居中对齐屏幕顶端 (⌥⌘R)", action: #selector(resetPosition), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        
        // 音乐播放器预览子菜单
        let playerMenu = NSMenu()
        playerMenu.addItem(NSMenuItem(title: "当前活跃: \(MusicManager.shared.activeSource.displayName)", action: nil, keyEquivalent: ""))
        playerMenu.addItem(NSMenuItem.separator())
        playerMenu.addItem(NSMenuItem(title: "🔴 预览网易云音乐效果 (周杰伦《晴天》)", action: #selector(previewNetease), keyEquivalent: "1"))
        playerMenu.addItem(NSMenuItem(title: "🟢 预览QQ音乐效果 (周杰伦《七里香》)", action: #selector(previewQQMusic), keyEquivalent: "2"))
        playerMenu.addItem(NSMenuItem(title: "🟣 预览Apple Music效果 (Taylor Swift)", action: #selector(previewAppleMusic), keyEquivalent: "3"))
        playerMenu.addItem(NSMenuItem(title: "🔵 预览SPlayer效果 (刘若英《原来你也在这里》)", action: #selector(previewSPlayer), keyEquivalent: "4"))
        playerMenu.addItem(NSMenuItem.separator())
        playerMenu.addItem(NSMenuItem(title: "🔄 恢复系统实时自动检测", action: #selector(restoreAutoDetect), keyEquivalent: "0"))
        playerMenu.items.forEach { $0.target = self }
        
        let playerItem = NSMenuItem(title: "🎵 音乐播放器接入与效果预览", action: nil, keyEquivalent: "")
        playerItem.submenu = playerMenu
        menu.addItem(playerItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "播放/暂停音乐 (有声)", action: #selector(togglePlay), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "切换下一首歌曲", action: #selector(nextSong), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "发送测试设备通知", action: #selector(testNotification), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出灵动岛", action: #selector(quitApp), keyEquivalent: "q"))
        
        menu.items.forEach { $0.target = self }
        statusBarItem?.menu = menu
    }
    
    @objc func previewNetease() {
        MusicManager.shared.previewPlayerSource(.netease)
    }
    
    @objc func previewQQMusic() {
        MusicManager.shared.previewPlayerSource(.qqMusic)
    }
    
    @objc func previewAppleMusic() {
        MusicManager.shared.previewPlayerSource(.appleMusic)
    }
    
    @objc func previewSPlayer() {
        MusicManager.shared.previewPlayerSource(.splayer)
    }
    
    @objc func restoreAutoDetect() {
        MusicManager.shared.exitPreviewMode()
    }
    
    @objc func resetPosition() {
        positionAtTopCenter(width: 380, height: 42)
        window?.orderFrontRegardless()
        
        NotificationManager.shared.showNotification(
            icon: "arrow.counterclockwise.circle.fill",
            iconColor: .cyan,
            title: "灵动岛已复位",
            subtitle: "快捷键 ⌥⌘R / ⌘R 已成功居中屏幕顶端"
        )
    }
    
    @objc func nextSong() {
        MusicManager.shared.nextTrack()
    }
    
    @objc func togglePlay() {
        MusicManager.shared.togglePlayPause()
    }
    
    @objc func testNotification() {
        NotificationManager.shared.showNotification(
            icon: "airpodspro",
            iconColor: .white,
            title: "AirPods Pro 已连接",
            subtitle: "电量 100% · 降噪模式已开启"
        )
    }
    
    @objc func quitApp() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        NSApplication.shared.terminate(nil)
    }
}
