import Foundation
import AppKit
import Combine

/// SPlayer 原生专用对接服务 (Direct IPC / HTTP Integration)
/// 通过 SPlayer 官方常驻 25884 端口，实现毫秒级精准对齐与原装逐字歌词同步
class SPlayerNativeService: ObservableObject {
    static let shared = SPlayerNativeService()
    
    @Published var isConnected: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var currentLyricIndex: Int = -1
    @Published var songTitle: String = ""
    @Published var artistName: String = ""
    @Published var coverURL: String = ""
    @Published var lyrics: [LyricLine] = []
    
    private let baseURL = "http://127.0.0.1:25884"
    private var syncTimer: Timer?
    private var isSyncing = false
    private var lastLoadedSongIdentifier: String = ""
    private var lastCoverURL: String = ""
    
    // 快速轻量网络会话（仅访问本地回环 127.0.0.1，超时时间极短）
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.6
        config.timeoutIntervalForResource = 0.6
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    init() {
        startHeartbeat()
    }
    
    func startHeartbeat() {
        syncTimer?.invalidate()
        // 3.3Hz (每 300ms) 轮询一次 SPlayer 原生播放内核，响应通常仅 4ms，耗能极低
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollSongInfo()
        }
    }
    
    func stopHeartbeat() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - 实时拉取 SPlayer 内核播放信息
    private func pollSongInfo() {
        guard !isSyncing else { return }
        guard let url = URL(string: "\(baseURL)/api/control/song-info") else { return }
        
        isSyncing = true
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { self.isSyncing = false }
            
            if error != nil || data == nil {
                if self.isConnected {
                    DispatchQueue.main.async {
                        self.isConnected = false
                    }
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let code = json["code"] as? Int, code == 200,
                  let trackData = json["data"] as? [String: Any] else {
                return
            }
            
            self.processTrackData(trackData)
        }.resume()
    }
    
    // MARK: - 数据解析与高精度派发
    private func processTrackData(_ data: [String: Any]) {
        let playStatus = data["playStatus"] as? Bool ?? false
        let currentTimeMs = (data["currentTime"] as? Double) ?? (data["currentTime"] as? Int).map { Double($0) } ?? 0.0
        let durationMs = (data["duration"] as? Double) ?? (data["duration"] as? Int).map { Double($0) } ?? 0.0
        let lyricIdx = data["lyricIndex"] as? Int ?? -1
        let title = (data["playName"] as? String) ?? (data["name"] as? String) ?? ""
        let artist = data["artistName"] as? String ?? ""
        let cover = data["cover"] as? String ?? ""
        let songId = (data["id"] as? Int).map { String($0) } ?? ""
        
        let timeInSec = max(0, currentTimeMs / 1000.0)
        let durInSec = max(0, durationMs / 1000.0)
        let songIdentifier = songId.isEmpty ? "\(title)_\(artist)" : "\(songId)_\(title)"
        
        // 检查歌曲是否发生切换
        let isSongChanged = (songIdentifier != self.lastLoadedSongIdentifier) && !title.isEmpty
        
        var parsedLyrics: [LyricLine]? = nil
        if isSongChanged || (self.lyrics.isEmpty && !title.isEmpty) {
            // 解析原装歌词
            parsedLyrics = self.extractLyrics(from: data, duration: durInSec)
        }
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.isPlaying = playStatus
            self.currentTime = timeInSec
            self.duration = durInSec
            self.currentLyricIndex = lyricIdx
            self.songTitle = title
            self.artistName = artist
            self.coverURL = cover
            
            if let newLyrics = parsedLyrics, !newLyrics.isEmpty {
                self.lyrics = newLyrics
                self.lastLoadedSongIdentifier = songIdentifier
            }
            
            // 封面下载同步
            if !cover.isEmpty && cover != self.lastCoverURL {
                self.lastCoverURL = cover
                self.fetchCoverImage(urlStr: cover)
            }
        }
    }
    
    // MARK: - 智能逐字歌词提取器 (Smart Word-by-Word Generator)
    private func extractLyrics(from data: [String: Any], duration: TimeInterval) -> [LyricLine] {
        // 1. 优先提取 SPlayer 原装 yrcData (网易云逐字歌词数据)
        if let yrcList = data["yrcData"] as? [[String: Any]], !yrcList.isEmpty {
            var lines: [LyricLine] = []
            for item in yrcList {
                let startMs = (item["startTime"] as? Double) ?? (item["startTime"] as? Int).map { Double($0) } ?? 0.0
                let wordsRaw = item["words"] as? [[String: Any]] ?? []
                
                var words: [LyricWord] = []
                var fullLineText = ""
                
                for w in wordsRaw {
                    let wStartMs = (w["startTime"] as? Double) ?? (w["startTime"] as? Int).map { Double($0) } ?? startMs
                    let wEndMs = (w["endTime"] as? Double) ?? (w["endTime"] as? Int).map { Double($0) } ?? wStartMs
                    let wordText = w["word"] as? String ?? ""
                    
                    fullLineText += wordText
                    let wDuration = max(0.04, (wEndMs - wStartMs) / 1000.0)
                    words.append(LyricWord(
                        text: wordText,
                        startTime: wStartMs / 1000.0,
                        duration: wDuration
                    ))
                }
                
                let lineTimestamp = startMs / 1000.0
                let trimmed = fullLineText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append(LyricLine(timestamp: lineTimestamp, text: fullLineText, words: words))
                }
            }
            if !lines.isEmpty {
                return lines
            }
        }
        
        // 2. 若无原生 yrcData，使用 lrcData 自动执行 Smart LRC Word Splitting
        // 彻底解决“逐字功能时不时会消失”的问题，为所有普通歌词自动生成 Apple Music 级别的逐字推进
        if let lrcList = data["lrcData"] as? [[String: Any]], !lrcList.isEmpty {
            var lines: [LyricLine] = []
            for (idx, item) in lrcList.enumerated() {
                let startMs = (item["startTime"] as? Double) ?? (item["startTime"] as? Int).map { Double($0) } ?? 0.0
                let endMs = (item["endTime"] as? Double) ?? (item["endTime"] as? Int).map { Double($0) } ?? 0.0
                
                let startSec = startMs / 1000.0
                var endSec = endMs / 1000.0
                if endSec <= startSec {
                    if idx + 1 < lrcList.count,
                       let nextStart = (lrcList[idx + 1]["startTime"] as? Double) ?? (lrcList[idx + 1]["startTime"] as? Int).map({ Double($0) }) {
                        endSec = nextStart / 1000.0
                    } else {
                        endSec = startSec + 3.5
                    }
                }
                
                let lineDuration = max(0.8, endSec - startSec)
                
                // 获取这句的文本
                var lineText = ""
                if let wordsRaw = item["words"] as? [[String: Any]], !wordsRaw.isEmpty {
                    lineText = wordsRaw.compactMap { $0["word"] as? String }.joined()
                }
                if lineText.isEmpty {
                    lineText = item["lineLyric"] as? String ?? ""
                }
                
                let clean = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { continue }
                
                // 将文本拆分为字符/单词，均分时间
                let words = self.splitLineIntoWords(text: clean, lineStart: startSec, totalDuration: lineDuration)
                lines.append(LyricLine(timestamp: startSec, text: clean, words: words))
            }
            if !lines.isEmpty {
                return lines
            }
        }
        
        return []
    }
    
    // MARK: - 智能字符音节均分算法 (Smart Word-by-Word Interpolator)
    private func splitLineIntoWords(text: String, lineStart: TimeInterval, totalDuration: TimeInterval) -> [LyricWord] {
        var tokens: [String] = []
        var currentLatin = ""
        
        for char in text {
            if char.isASCII && (char.isLetter || char.isNumber) {
                currentLatin.append(char)
            } else {
                if !currentLatin.isEmpty {
                    tokens.append(currentLatin)
                    currentLatin = ""
                }
                tokens.append(String(char))
            }
        }
        if !currentLatin.isEmpty {
            tokens.append(currentLatin)
        }
        
        guard !tokens.isEmpty else { return [] }
        
        // 计算每个 token 的权重 (中文字符权重 1.0，空格 0.2，英文单词按长度开方加权)
        var weights: [Double] = []
        for t in tokens {
            if t == " " {
                weights.append(0.2)
            } else if t.count > 1 {
                weights.append(max(1.0, sqrt(Double(t.count)) * 0.9))
            } else {
                weights.append(1.0)
            }
        }
        let totalWeight = max(0.001, weights.reduce(0, +))
        
        var words: [LyricWord] = []
        var currentTokenStart = lineStart
        
        for (i, t) in tokens.enumerated() {
            let dur = (weights[i] / totalWeight) * totalDuration
            words.append(LyricWord(
                text: t,
                startTime: currentTokenStart,
                duration: max(0.04, dur)
            ))
            currentTokenStart += dur
        }
        
        return words
    }
    
    // MARK: - 封面下载缓存
    private func fetchCoverImage(urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        
        session.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                MusicManager.shared.externalArtwork = image
            }
        }.resume()
    }
    
    // MARK: - 媒体控制指令 (Direct HTTP Remote Control)
    func play() { sendCommand("/api/control/play") }
    func pause() { sendCommand("/api/control/pause") }
    func toggle() { sendCommand("/api/control/toggle") }
    func nextTrack() { sendCommand("/api/control/next") }
    func previousTrack() { sendCommand("/api/control/prev") }
    
    private func sendCommand(_ path: String) {
        guard let url = URL(string: "\(baseURL)\(path)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        session.dataTask(with: req).resume()
    }
}
