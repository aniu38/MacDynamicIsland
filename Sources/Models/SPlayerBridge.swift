import AppKit
import Foundation

class SPlayerBridge {
    static let shared = SPlayerBridge()
    
    // 强制向 SPlayer 进程发送系统键盘切歌/播放按键
    func sendSPlayerKey(keyCode: UInt16, modifiers: String = "using {command down}") {
        let scriptSource = """
        tell application "System Events"
            if exists process "SPlayer" then
                tell process "SPlayer"
                    key code \(keyCode) \(modifiers)
                end tell
            end if
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
            if let error = error {
                print("⚠️ SPlayer Key Error: \(error)")
            } else {
                print("✅ 成功向 SPlayer 发送 KeyCode \(keyCode)")
            }
        }
    }
    
    func nextTrack() {
        // Cmd + Right Arrow (KeyCode 124)
        sendSPlayerKey(keyCode: 124, modifiers: "using {command down}")
    }
    
    func previousTrack() {
        // Cmd + Left Arrow (KeyCode 123)
        sendSPlayerKey(keyCode: 123, modifiers: "using {command down}")
    }
    
    func togglePlayPause() {
        // Space (KeyCode 49)
        sendSPlayerKey(keyCode: 49, modifiers: "")
    }
    
    // 抓取 SPlayer 的主窗口标题（如果媒体扩展未暴露，可以直接从 Window Title 获取播放文件名）
    func fetchSPlayerWindowTitle() -> String? {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        for win in windowList {
            if let owner = win["kCGWindowOwnerName"] as? String, owner.lowercased().contains("splayer") {
                if let title = win["kCGWindowName"] as? String, !title.isEmpty {
                    // 清理扩展名如 .mp3, .flac, .m4a
                    var cleanTitle = title.replacingOccurrences(of: "\\.(mp3|flac|m4a|wav|mp4|mkv)$", with: "", options: [.regularExpression, .caseInsensitive])
                    cleanTitle = cleanTitle.replacingOccurrences(of: " - SPlayer", with: "")
                    return cleanTitle.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }
}
