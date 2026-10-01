import Foundation
import Combine
import AppKit

struct SPlayerLogTrackInfo {
    var title: String
    var artist: String
    var album: String
    var ncmID: String?
    var isPlaying: Bool
}

class SPlayerLogMonitor: ObservableObject {
    static let shared = SPlayerLogMonitor()
    
    @Published var trackInfo: SPlayerLogTrackInfo?
    private var timer: Timer?
    private var lastParsedLine: String = ""
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer?.invalidate()
        // 0.1秒极高频扫描 SPlayer 日志
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.readLatestLog()
        }
    }
    
    func readLatestLog() {
        // 0. 优先检测 SPlayer 进程是否存活，如果 SPlayer 已退出，立刻重置状态停止歌词滚动！
        guard SPlayerTracker.shared.getSPlayerPID() != nil else {
            if self.trackInfo != nil {
                self.lastParsedLine = ""
                DispatchQueue.main.async {
                    self.trackInfo = nil
                }
            }
            return
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let logDir = "\(home)/Library/Application Support/SPlayer/logs/external-media-integration"
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: logDir) else { return }
        let logFiles = files.filter { $0.endsWith(".log") || $0.hasSuffix(".log") }
            .map { "\(logDir)/\($0)" }
            .sorted { (path1, path2) -> Bool in
                let attr1 = try? FileManager.default.attributesOfItem(atPath: path1)
                let attr2 = try? FileManager.default.attributesOfItem(atPath: path2)
                let date1 = (attr1?[.modificationDate] as? Date) ?? Date.distantPast
                let date2 = (attr2?[.modificationDate] as? Date) ?? Date.distantPast
                return date1 < date2
            }
        
        guard let latestLogPath = logFiles.last else { return }
        
        guard let content = try? String(contentsOfFile: latestLogPath, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines)
        
        var currentTitle: String?
        var currentArtist: String?
        var currentAlbum: String?
        var currentNcmID: String?
        var isPlaying: Bool = true
        
        var foundStatus = false
        var foundMetadata = false
        
        for line in lines.reversed() {
            if !foundStatus {
                if line.contains("new_status=Paused") {
                    isPlaying = false
                    foundStatus = true
                } else if line.contains("new_status=Playing") {
                    isPlaying = true
                    foundStatus = true
                }
            }
            
            if !foundMetadata && line.contains("正在更新 macOS NowPlayingInfo 元数据") {
                if let tMatch = matchRegex(pattern: "title=(.*?) artist=", in: line) {
                    currentTitle = tMatch
                } else if let tMatch = matchRegex(pattern: "title=([^\\s]+)", in: line) {
                    currentTitle = tMatch
                }
                
                if let aMatch = matchRegex(pattern: "artist=(.*?) album=", in: line) {
                    currentArtist = aMatch
                } else if let aMatch = matchRegex(pattern: "artist=([^\\s]+)", in: line) {
                    currentArtist = aMatch
                }
                
                if let alMatch = matchRegex(pattern: "album=(.*?) ncm_id=", in: line) {
                    currentAlbum = alMatch
                } else if let alMatch = matchRegex(pattern: "album=([^\\s]+)", in: line) {
                    currentAlbum = alMatch
                }
                
                if let ncmMatch = matchRegex(pattern: "ncm_id=Some\\((\\d+)\\)", in: line) {
                    currentNcmID = ncmMatch
                }
                foundMetadata = true
            }
            
            if foundStatus && foundMetadata {
                break
            }
        }
        
        guard let title = currentTitle, !title.isEmpty else { return }
        
        let infoKey = "\(title)-\(currentArtist ?? "")-\(isPlaying)"
        if infoKey != lastParsedLine {
            lastParsedLine = infoKey
            
            DispatchQueue.main.async {
                self.trackInfo = SPlayerLogTrackInfo(
                    title: title,
                    artist: currentArtist ?? "SPlayer",
                    album: currentAlbum ?? "SPlayer",
                    ncmID: currentNcmID,
                    isPlaying: isPlaying
                )
            }
        }
    }
    
    private func matchRegex(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            if match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        return nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

extension String {
    func endsWith(_ suffix: String) -> Bool {
        return self.hasSuffix(suffix)
    }
}
