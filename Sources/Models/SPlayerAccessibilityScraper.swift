import AppKit
import ApplicationServices
import Foundation

class SPlayerAccessibilityScraper {
    static let shared = SPlayerAccessibilityScraper()
    
    // 寻找 SPlayer 进程 PID
    func getSPlayerPID() -> pid_t? {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName?.lowercased().contains("splayer") == true
        }
        return apps.first?.processIdentifier
    }
    
    // 从 SPlayer 的界面 UI 树中直接读取歌名与字幕文本
    func scrapeSPlayerUI() -> (title: String?, lyric: String?) {
        guard let pid = getSPlayerPID() else { return (nil, nil) }
        
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return (nil, nil)
        }
        
        var scrapedTitle: String? = nil
        var scrapedLyric: String? = nil
        
        for window in windows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let winTitle = titleRef as? String, !winTitle.isEmpty {
                scrapedTitle = cleanTitle(winTitle)
            }
            
            // 遍历窗口内的所有文本标签（抓取字幕/歌词）
            let texts = extractAllTextElements(from: window)
            for text in texts {
                if isLyricLike(text) {
                    scrapedLyric = text
                    break
                }
            }
        }
        
        return (scrapedTitle, scrapedLyric)
    }
    
    private func extractAllTextElements(from element: AXUIElement) -> [String] {
        var results: [String] = []
        var childrenRef: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueRef) == .success,
                   let valStr = valueRef as? String, !valStr.isEmpty {
                    results.append(valStr)
                }
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let titleStr = titleRef as? String, !titleStr.isEmpty {
                    results.append(titleStr)
                }
                
                // 深度遍历
                results.append(contentsOf: extractAllTextElements(from: child))
            }
        }
        return results
    }
    
    private func isLyricLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2 && trimmed.count < 60 else { return false }
        // 排除常见的菜单按钮词汇
        let ignoreList = ["splayer", "播放", "暂停", "窗口", "文件", "设置", "退出", "主界面", "00:", "01:"]
        for word in ignoreList {
            if trimmed.lowercased() == word { return false }
        }
        return true
    }
    
    private func cleanTitle(_ raw: String) -> String {
        var clean = raw.replacingOccurrences(of: "\\.(mp3|flac|m4a|wav|aac|mp4|mkv)$", with: "", options: [.regularExpression, .caseInsensitive])
        clean = clean.replacingOccurrences(of: " - SPlayer", with: "")
        clean = clean.replacingOccurrences(of: "SPlayer - ", with: "")
        return clean.trimmingCharacters(in: .whitespaces)
    }
}
