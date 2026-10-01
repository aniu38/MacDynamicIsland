import Foundation

class SPlayerLocalLyricReader {
    static let shared = SPlayerLocalLyricReader()
    
    // 尝试寻找与音轨同名的本地 .lrc / .srt 文件
    func findLocalLyricFile(for audioPath: String) -> String? {
        guard !audioPath.isEmpty else { return nil }
        
        let fileManager = FileManager.default
        let NSStringPath = audioPath as NSString
        let baseName = NSStringPath.deletingPathExtension
        
        let possibleExtensions = ["lrc", "LRC", "srt", "SRT", "txt"]
        for ext in possibleExtensions {
            let lyricPath = "\(baseName).\(ext)"
            if fileManager.fileExists(atPath: lyricPath) {
                do {
                    return try String(contentsOfFile: lyricPath, encoding: .utf8)
                } catch {
                    print("读取本地歌词文件失败: \(error)")
                }
            }
        }
        return nil
    }
}
