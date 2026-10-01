import Foundation
import AppKit
import Combine

class SPlayerTracker {
    static let shared = SPlayerTracker()
    
    func getSPlayerPID() -> pid_t? {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName?.lowercased().contains("splayer") == true
        }
        return apps.first?.processIdentifier
    }
    
    // 追踪 SPlayer 正在打开播放的音轨文件
    func getSPlayerPlayingFileName() -> String? {
        // 1. 优先获取 SPlayer 窗口标题
        if let winTitle = SPlayerBridge.shared.fetchSPlayerWindowTitle(), !winTitle.isEmpty {
            return cleanSongTitle(winTitle)
        }
        
        // 2. 如果窗口无标题，通过 PID 查询 lsof 进程打开的音轨文件
        guard let pid = getSPlayerPID() else { return nil }
        
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-p", "\(pid)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines.reversed() { // 倒序看最新打开的文件
                    if line.contains(".mp3") || line.contains(".flac") || line.contains(".m4a") || line.contains(".wav") || line.contains(".aac") {
                        if let pathIndex = line.range(of: "/")?.lowerBound {
                            let fullPath = String(line[pathIndex...])
                            let fileName = (fullPath as NSString).lastPathComponent
                            return cleanSongTitle(fileName)
                        }
                    }
                }
            }
        } catch {
            print("lsof 进程查询失败: \(error)")
        }
        
        return nil
    }
    
    private func cleanSongTitle(_ raw: String) -> String {
        var clean = raw.replacingOccurrences(of: "\\.(mp3|flac|m4a|wav|aac|mp4|mkv)$", with: "", options: [.regularExpression, .caseInsensitive])
        clean = clean.replacingOccurrences(of: " - SPlayer", with: "")
        clean = clean.replacingOccurrences(of: "SPlayer - ", with: "")
        return clean.trimmingCharacters(in: .whitespaces)
    }
}
