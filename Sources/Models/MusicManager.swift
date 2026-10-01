import Foundation
import Combine
import AppKit
import AVFoundation
import SwiftUI

struct LyricWord: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
    var endTime: TimeInterval { startTime + duration }
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
    let words: [LyricWord]
    
    init(timestamp: TimeInterval, text: String, words: [LyricWord] = []) {
        self.timestamp = timestamp
        self.text = text
        self.words = words
    }
}

struct Song: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let albumArtName: String
    let localFileName: String
    let lyrics: [LyricLine]
    let duration: TimeInterval
}

class MusicManager: ObservableObject {
    static let shared = MusicManager()
    
    @Published var isPlaying: Bool = true
    @Published var currentSong: Song
    @Published var playbackTime: TimeInterval = 0.0
    @Published var currentLyricIndex: Int = 0
    @Published var volume: Float = 0.8
    
    /// 当前活跃播放器来源 (SPlayer, Apple Music, 网易云音乐, QQ音乐)
    @Published var activeSource: MusicPlayerSource = .splayer
    @Published var isPreviewMode: Bool = false
    
    @Published var isSPlayerConnected: Bool = true
    @Published var externalArtwork: NSImage? = nil
    @Published var lyricOffset: TimeInterval = -0.15 // 默认 150ms AirPods/蓝牙音频输出延迟自动微调补偿
    
    // 高精度双参考时钟引擎 (Commercial Grade High-Precision Reference Clock Engine)
    private var referenceElapsedTime: TimeInterval = 0.0
    private var referenceHostTime: TimeInterval = CACurrentMediaTime()
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSPlayerTitle: String = ""
    
    /// 模拟预览各播放器在灵动岛上的呈现效果 (无需用户单独下载安装)
    func previewPlayerSource(_ source: MusicPlayerSource) {
        self.isPreviewMode = true
        self.activeSource = source
        let demoSong: (title: String, artist: String)
        switch source {
        case .netease:
            demoSong = ("晴天", "周杰伦")
        case .qqMusic:
            demoSong = ("七里香", "周杰伦")
        case .appleMusic:
            demoSong = ("Cruel Summer", "Taylor Swift")
        case .splayer:
            demoSong = ("原来你也在这里", "刘若英")
        case .system:
            demoSong = ("音乐播放中", "Mac 灵动岛")
        }
        
        self.isPlaying = true
        self.externalArtwork = nil
        self.currentLyricIndex = -1
        self.referenceElapsedTime = 0.0
        self.referenceHostTime = CACurrentMediaTime()
        self.playbackTime = 0.0
        self.lastSPlayerTitle = demoSong.title
        
        NotificationManager.shared.showNotification(
            icon: source.iconName,
            iconColor: source.themeColor,
            title: "\(source.displayName) 已接入",
            subtitle: "《\(demoSong.title)》- \(demoSong.artist)"
        )
        
        // 自动拉取该歌曲的真实原装逐字/逐行歌词与封面
        LyricFetcher.shared.fetchLyrics(for: demoSong.title, artist: demoSong.artist)
        ArtworkFetcher.shared.fetchArtwork(for: demoSong.title, artist: demoSong.artist)
        
        self.currentSong = Song(
            title: demoSong.title,
            artist: demoSong.artist,
            albumArtName: "music_cover1",
            localFileName: "",
            lyrics: LyricFetcher.shared.getLyricsForTitle(demoSong.title, sourceName: source.displayName),
            duration: 270.0
        )
    }
    
    /// 退出预览模式，恢复系统实时自动检测
    func exitPreviewMode() {
        self.isPreviewMode = false
        SystemMediaRemoteManager.shared.fetchNowPlayingInfo()
    }
    
    var exactPlaybackTime: TimeInterval {
        guard isPlaying else { return referenceElapsedTime }
        let now = CACurrentMediaTime()
        let delta = max(0, now - referenceHostTime)
        return max(0, referenceElapsedTime + delta)
    }
    
    init() {
        let defaultSong = Song(
            title: "侧脸",
            artist: "魏语诺",
            albumArtName: "music_cover1",
            localFileName: "",
            lyrics: LyricFetcher.shared.getLyricsForTitle("侧脸"),
            duration: 300.0
        )
        
        self.currentSong = defaultSong
        setupNativeSPlayerBinding()
        setupSPlayerBinding()
        startTimer()
        startPeriodicAppCheck()
        
        SystemMediaRemoteManager.shared.fetchNowPlayingInfo()
    }
    
    // MARK: - SPlayer 原生内核专用高精度直连通道 (Priority #0)
    private func setupNativeSPlayerBinding() {
        let native = SPlayerNativeService.shared
        
        // 1. 播放/暂停状态直连同步
        native.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard let self = self, native.isConnected, !self.isPreviewMode else { return }
                if playing != self.isPlaying {
                    if playing {
                        // 恢复播放：重置基准宿主时间戳，继承当前参考进度
                        self.activeSource = .splayer
                        self.referenceHostTime = CACurrentMediaTime()
                    } else {
                        // 暂停播放：定格并锁定当前时间戳
                        let pausedTime = self.exactPlaybackTime
                        self.referenceElapsedTime = pausedTime
                        self.playbackTime = pausedTime
                    }
                    self.isPlaying = playing
                }
            }
            .store(in: &cancellables)
            
        // 2. 毫秒级播放进度直连同步与单调插值防漂移校准
        native.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] splayerTime in
                guard let self = self, native.isConnected, !self.isPreviewMode, splayerTime >= 0 else { return }
                let current = self.exactPlaybackTime
                // 仅当时间差 > 0.15 秒（如 Seek、切歌、暂停恢复）时硬校准，避免轮询微抖动破坏 60fps 平滑逐字流光
                if abs(current - splayerTime) > 0.15 {
                    self.referenceElapsedTime = splayerTime
                    self.referenceHostTime = CACurrentMediaTime()
                    self.playbackTime = splayerTime
                    self.updateLyricIndex()
                }
            }
            .store(in: &cancellables)
            
        // 3. 原装逐字歌词直接绑定 (彻底根治逐字消失和对齐问题)
        native.$lyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLyrics in
                guard let self = self, native.isConnected, !self.isPreviewMode, !newLyrics.isEmpty else { return }
                self.currentSong = Song(
                    title: native.songTitle.isEmpty ? self.currentSong.title : native.songTitle,
                    artist: native.artistName.isEmpty ? self.currentSong.artist : native.artistName,
                    albumArtName: self.currentSong.albumArtName,
                    localFileName: "",
                    lyrics: newLyrics,
                    duration: native.duration > 0 ? native.duration : self.currentSong.duration
                )
                self.updateLyricIndex()
            }
            .store(in: &cancellables)
            
        // 4. 歌曲元数据切换
        native.$songTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTitle in
                guard let self = self, native.isConnected, !newTitle.isEmpty, !self.isPreviewMode else { return }
                self.activeSource = .splayer
                let clean = MusicManager.cleanSongTitle(newTitle)
                if clean != self.lastSPlayerTitle {
                    self.lastSPlayerTitle = clean
                    self.currentLyricIndex = -1
                    self.referenceElapsedTime = native.currentTime
                    self.referenceHostTime = CACurrentMediaTime()
                    self.playbackTime = native.currentTime
                    
                    self.currentSong = Song(
                        title: clean,
                        artist: native.artistName,
                        albumArtName: "music_cover1",
                        localFileName: "",
                        lyrics: native.lyrics,
                        duration: native.duration > 0 ? native.duration : 300.0
                    )
                }
            }
            .store(in: &cancellables)
            
        // 5. 官方行索引校准
        native.$currentLyricIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] officialIdx in
                guard let self = self, native.isConnected, !self.isPreviewMode else { return }
                if officialIdx >= 0 && officialIdx < self.currentSong.lyrics.count {
                    // 若官方索引与本地索引不一致且属于前后相邻行，平滑校准为官方索引
                    if self.currentLyricIndex != officialIdx && abs(self.currentLyricIndex - officialIdx) <= 2 {
                        self.currentLyricIndex = officialIdx
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func syncPlaybackTime(_ newTime: TimeInterval, force: Bool = false) {
        guard newTime >= 0 else { return }
        // 若原生 SPlayer 服务在线且正在播放，以原生服务为最高优先级
        if SPlayerNativeService.shared.isConnected && SPlayerNativeService.shared.isPlaying && !force { return }
        
        let current = exactPlaybackTime
        // 主单调时钟过滤：当强制同步 (如切歌、暂停恢复) 或检测到 Seek/跳转 (进度突变 > 1.2 秒) 时才更动主时钟，彻底杜绝采样微噪导致的累积漂移
        if force || abs(current - newTime) > 1.2 {
            referenceElapsedTime = newTime
            referenceHostTime = CACurrentMediaTime()
            self.playbackTime = newTime
            self.updateLyricIndex()
        }
    }
    
    private func setupSPlayerBinding() {
        // 0. 备选兜底：绑定 SPlayer 实时日志监控服务
        SPlayerLogMonitor.shared.$trackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self = self, !self.isPreviewMode else { return }
                // 若原生直连服务已就绪，跳过日志层干扰
                if SPlayerNativeService.shared.isConnected { return }
                
                guard let info = info, SPlayerTracker.shared.getSPlayerPID() != nil else {
                    self.isPlaying = false
                    self.referenceElapsedTime = 0.0
                    self.referenceHostTime = CACurrentMediaTime()
                    self.playbackTime = 0.0
                    self.currentLyricIndex = -1
                    self.lastSPlayerTitle = ""
                    self.currentSong = Song(
                        title: "Mac 灵动岛",
                        artist: "SPlayer",
                        albumArtName: "music_cover1",
                        localFileName: "",
                        lyrics: [],
                        duration: 300.0
                    )
                    return
                }
                
                if info.isPlaying != self.isPlaying {
                    if info.isPlaying {
                        // 暂停后恢复播放：更新参考基准时间点，继承原有的 referenceElapsedTime
                        self.referenceHostTime = CACurrentMediaTime()
                    } else {
                        // 切换为暂停：锁定当前精准播放进度到 referenceElapsedTime
                        let pausedTime = self.exactPlaybackTime
                        self.referenceElapsedTime = pausedTime
                        self.playbackTime = pausedTime
                    }
                    self.isPlaying = info.isPlaying
                }
                
                let cleanTitle = MusicManager.cleanSongTitle(info.title)
                let validTitle = cleanTitle.isEmpty ? "侧脸" : cleanTitle
                let validArtist = info.artist.isEmpty ? "魏语诺" : info.artist
                
                if validTitle != self.lastSPlayerTitle {
                    self.lastSPlayerTitle = validTitle
                    self.currentLyricIndex = -1
                    self.syncPlaybackTime(0.0, force: true)
                    
                    NotificationManager.shared.showNotification(
                        icon: "music.note",
                        iconColor: .cyan,
                        title: "SPlayer 播放中",
                        subtitle: "\(validTitle)"
                    )
                    
                    if let ncmID = info.ncmID, !ncmID.isEmpty {
                        LyricFetcher.shared.fetchLyricsByNcmID(ncmID, title: validTitle)
                        ArtworkFetcher.shared.fetchArtworkByNcmID(ncmID, title: validTitle, artist: validArtist)
                    } else {
                        LyricFetcher.shared.fetchLyrics(for: validTitle, artist: validArtist)
                        ArtworkFetcher.shared.fetchArtwork(for: validTitle, artist: validArtist)
                    }
                } else if self.externalArtwork == nil {
                    if let ncmID = info.ncmID, !ncmID.isEmpty {
                        ArtworkFetcher.shared.fetchArtworkByNcmID(ncmID, title: validTitle, artist: validArtist)
                    } else {
                        ArtworkFetcher.shared.fetchArtwork(for: validTitle, artist: validArtist)
                    }
                }
                
                let lyrics = LyricFetcher.shared.currentLyrics.isEmpty ? LyricFetcher.shared.getLyricsForTitle(validTitle) : LyricFetcher.shared.currentLyrics
                
                self.currentSong = Song(
                    title: validTitle,
                    artist: validArtist,
                    albumArtName: "music_cover1",
                    localFileName: "",
                    lyrics: lyrics,
                    duration: 300.0
                )
            }
            .store(in: &cancellables)
            
        let sys = SystemMediaRemoteManager.shared
        
        // 1. 系统 MediaRemote 时间戳（快进/快退/ Seek/拖拽进度条时毫秒级精准拉回对齐）
        sys.$currentElapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sysTime in
                guard let self = self, sysTime > 0 else { return }
                self.syncPlaybackTime(sysTime)
            }
            .store(in: &cancellables)
            
        // 4. 封面图片
        sys.$artworkImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] img in
                if let img = img {
                    self?.externalArtwork = img
                }
            }
            .store(in: &cancellables)
            
        ArtworkFetcher.shared.$artworkImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] img in
                if let img = img {
                    self?.externalArtwork = img
                }
            }
            .store(in: &cancellables)
            
        // 5. 歌词抓取通知
        LyricFetcher.shared.$currentLyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLyrics in
                guard let self = self else { return }
                if !newLyrics.isEmpty {
                    self.currentSong = Song(
                        title: self.currentSong.title,
                        artist: self.currentSong.artist,
                        albumArtName: self.currentSong.albumArtName,
                        localFileName: "",
                        lyrics: newLyrics,
                        duration: self.currentSong.duration
                    )
                    self.updateLyricIndex()
                }
            }
            .store(in: &cancellables)
            
        // 6. 播放器来源自动同步 (网易云音乐 / QQ音乐 / Apple Music / SPlayer)
        sys.$currentSource
            .receive(on: DispatchQueue.main)
            .sink { [weak self] source in
                guard let self = self else { return }
                // 仅当 SPlayer 未在播放时，采纳系统检测到的活跃播放器源
                if !SPlayerNativeService.shared.isPlaying {
                    self.activeSource = source
                }
            }
            .store(in: &cancellables)
            
        // 7. 播放状态同步 (网易云音乐 / QQ音乐 / Apple Music)
        sys.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard let self = self else { return }
                if !SPlayerNativeService.shared.isPlaying {
                    if playing != self.isPlaying {
                        if playing {
                            self.referenceHostTime = CACurrentMediaTime()
                        } else {
                            let pausedTime = self.exactPlaybackTime
                            self.referenceElapsedTime = pausedTime
                            self.playbackTime = pausedTime
                        }
                        self.isPlaying = playing
                    }
                }
            }
            .store(in: &cancellables)
            
        // 8. 歌曲切换与歌词抓取 (网易云音乐 / QQ音乐 / Apple Music)
        sys.$currentTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTitle in
                guard let self = self, !self.isPreviewMode else { return }
                // 若 SPlayer 正在播放，跳过其他播放器
                if SPlayerNativeService.shared.isConnected && SPlayerNativeService.shared.isPlaying { return }
                
                let clean = MusicManager.cleanSongTitle(newTitle)
                guard !clean.isEmpty, clean != self.lastSPlayerTitle else { return }
                
                self.lastSPlayerTitle = clean
                self.currentLyricIndex = -1
                self.referenceElapsedTime = sys.currentElapsedTime
                self.referenceHostTime = CACurrentMediaTime()
                self.playbackTime = sys.currentElapsedTime
                
                let artist = sys.currentArtist.isEmpty ? self.activeSource.displayName : sys.currentArtist
                
                // 弹出对应播放器的灵动岛通知
                NotificationManager.shared.showNotification(
                    icon: self.activeSource.iconName,
                    iconColor: self.activeSource.themeColor,
                    title: "\(self.activeSource.displayName) 播放中",
                    subtitle: "\(clean) - \(artist)"
                )
                
                // 异步从云端抓取原装逐字/逐行歌词与封面
                LyricFetcher.shared.fetchLyrics(for: clean, artist: artist)
                if self.externalArtwork == nil {
                    ArtworkFetcher.shared.fetchArtwork(for: clean, artist: artist)
                }
                
                self.currentSong = Song(
                    title: clean,
                    artist: artist,
                    albumArtName: "music_cover1",
                    localFileName: "",
                    lyrics: LyricFetcher.shared.getLyricsForTitle(clean, sourceName: self.activeSource.displayName),
                    duration: sys.currentDuration > 0 ? sys.currentDuration : 300.0
                )
            }
            .store(in: &cancellables)
    }
    
    private var checkTimer: Timer?
    func startPeriodicAppCheck() {
        checkTimer?.invalidate()
        // 1.5 秒周期巡检 Apple Music 原生后台状态
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPreviewMode else { return }
            // 若 SPlayer 未在播放，主动探测 Apple Music 是否正在播放
            if !SPlayerNativeService.shared.isPlaying {
                if let amInfo = MultiPlayerBridge.shared.fetchAppleMusicInfo(), amInfo.isPlaying {
                    self.activeSource = .appleMusic
                    let clean = MusicManager.cleanSongTitle(amInfo.title)
                    if clean != self.lastSPlayerTitle {
                        self.lastSPlayerTitle = clean
                        self.currentLyricIndex = -1
                        self.syncPlaybackTime(amInfo.position, force: true)
                        self.isPlaying = true
                        
                        NotificationManager.shared.showNotification(
                            icon: self.activeSource.iconName,
                            iconColor: self.activeSource.themeColor,
                            title: "\(self.activeSource.displayName) 播放中",
                            subtitle: "\(clean) - \(amInfo.artist)"
                        )
                        
                        LyricFetcher.shared.fetchLyrics(for: clean, artist: amInfo.artist)
                        ArtworkFetcher.shared.fetchArtwork(for: clean, artist: amInfo.artist)
                        
                        self.currentSong = Song(
                            title: clean,
                            artist: amInfo.artist,
                            albumArtName: "music_cover1",
                            localFileName: "",
                            lyrics: LyricFetcher.shared.getLyricsForTitle(clean, sourceName: self.activeSource.displayName),
                            duration: amInfo.duration
                        )
                    }
                }
            }
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        // 20Hz (0.05 秒) 超高刷新率定时器，消除累积误差
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                let exactTime = self.exactPlaybackTime
                self.playbackTime = exactTime
                self.updateLyricIndex()
            }
        }
    }
    
    private func updateLyricIndex() {
        let lyrics = currentSong.lyrics
        guard !lyrics.isEmpty else {
            if currentLyricIndex != -1 { currentLyricIndex = -1 }
            return
        }
        
        let effectiveTime = max(0, playbackTime + lyricOffset)
        
        // 歌曲前奏阶段：如果时间在第一句歌词之前，设为 -1
        if effectiveTime < lyrics[0].timestamp {
            if currentLyricIndex != -1 {
                currentLyricIndex = -1
            }
            return
        }
        
        // 二分查找 (O(log N)) 毫秒级锁定当前活跃歌词行索引
        var low = 0
        var high = lyrics.count - 1
        var bestIndex = 0
        
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].timestamp <= effectiveTime {
                bestIndex = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        if bestIndex != currentLyricIndex {
            currentLyricIndex = bestIndex
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            let pausedTime = exactPlaybackTime
            referenceElapsedTime = pausedTime
            playbackTime = pausedTime
        } else {
            referenceHostTime = CACurrentMediaTime()
        }
        self.isPlaying.toggle()
        
        MultiPlayerBridge.shared.togglePlayPause(for: activeSource)
    }
    
    func nextTrack() {
        MultiPlayerBridge.shared.nextTrack(for: activeSource)
    }
    
    func previousTrack() {
        MultiPlayerBridge.shared.previousTrack(for: activeSource)
    }
    
    static func cleanSongTitle(_ rawTitle: String) -> String {
        var title = rawTitle.replacingOccurrences(of: "\\.(mp3|flac|m4a|wav|aac|mp4|mkv)$", with: "", options: [.regularExpression, .caseInsensitive])
        title = title.replacingOccurrences(of: "^\\d+[\\.\\s_\\-]+", with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: " - SPlayer", with: "")
        title = title.replacingOccurrences(of: "SPlayer - ", with: "")
        title = title.replacingOccurrences(of: " - 网易云音乐", with: "")
        title = title.replacingOccurrences(of: "网易云音乐 - ", with: "")
        title = title.replacingOccurrences(of: " - QQ音乐", with: "")
        title = title.replacingOccurrences(of: "QQ音乐 - ", with: "")
        title = title.replacingOccurrences(of: " - Music", with: "")
        title = title.replacingOccurrences(of: " - Apple Music", with: "")
        return title.trimmingCharacters(in: .whitespaces)
    }
    
    static func parseLRC(_ lrcString: String) -> [LyricLine] {
        var tempLines: [(timestamp: Double, text: String, words: [LyricWord])] = []
        var lrcOffset: Double = 0.0 // 秒
        
        let rawLines = lrcString.components(separatedBy: .newlines)
        
        // 1. 解析全局 offset 标签: [offset:1000] 或 [offset:-500]
        let offsetRegex = try? NSRegularExpression(pattern: "\\[offset:\\s*([+-]?\\d+)\\]", options: .caseInsensitive)
        for line in rawLines {
            let nsString = line as NSString
            if let match = offsetRegex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let offsetStr = nsString.substring(with: match.range(at: 1))
                if let val = Double(offsetStr) {
                    lrcOffset = val / 1000.0
                }
            }
        }
        
        // 2. 检测是否为 YRC 逐字歌词格式: [1234,500](0,200,0)这(200,300,0)是...
        let isYRC = lrcString.contains("](") && lrcString.contains(",")
        
        if isYRC {
            let yrcRegex = try? NSRegularExpression(pattern: "\\[(\\d+),(\\d+)\\](.*)")
            let wordRegex = try? NSRegularExpression(pattern: "\\((\\d+),(\\d+),\\d+\\)([^\\(]*)")
            
            for rawLine in rawLines {
                let nsLine = rawLine as NSString
                guard let match = yrcRegex?.firstMatch(in: rawLine, options: [], range: NSRange(location: 0, length: nsLine.length)) else { continue }
                
                let lineStartMs = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let content = nsLine.substring(with: match.range(at: 3))
                let lineStartSec = (lineStartMs / 1000.0) + lrcOffset
                
                let nsContent = content as NSString
                let wordMatches = wordRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length)) ?? []
                
                var words: [LyricWord] = []
                var fullText = ""
                
                for wMatch in wordMatches {
                    let wStartRel = Double(nsContent.substring(with: wMatch.range(at: 1))) ?? 0
                    let wDur = Double(nsContent.substring(with: wMatch.range(at: 2))) ?? 0
                    let wText = nsContent.substring(with: wMatch.range(at: 3))
                    
                    let wAbsStart = lineStartSec + (wStartRel / 1000.0)
                    let wAbsDur = max(0.05, wDur / 1000.0)
                    
                    fullText += wText
                    words.append(LyricWord(text: wText, startTime: wAbsStart, duration: wAbsDur))
                }
                
                if fullText.isEmpty { fullText = content }
                tempLines.append((timestamp: lineStartSec, text: fullText.trimmingCharacters(in: .whitespaces), words: words))
            }
        }
        
        // 3. 如果不是 YRC 或 YRC 解析为空，按标准 LRC 匹配
        if tempLines.isEmpty {
            let timeTagRegex = try? NSRegularExpression(pattern: "\\[(\\d{1,2}):(\\d{2})[\\.:](\\d{2,3})\\]")
            
            for rawLine in rawLines {
                let nsString = rawLine as NSString
                let matches = timeTagRegex?.matches(in: rawLine, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
                guard !matches.isEmpty else { continue }
                
                let text = timeTagRegex?.stringByReplacingMatches(
                    in: rawLine,
                    options: [],
                    range: NSRange(location: 0, length: nsString.length),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespaces) ?? ""
                
                for match in matches {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let msStr = nsString.substring(with: match.range(at: 3))
                    
                    let min = Double(minStr) ?? 0
                    let sec = Double(secStr) ?? 0
                    var ms = Double(msStr) ?? 0
                    if msStr.count == 2 {
                        ms /= 100.0
                    } else if msStr.count == 3 {
                        ms /= 1000.0
                    }
                    
                    let totalSeconds = max(0, min * 60.0 + sec + ms + lrcOffset)
                    tempLines.append((timestamp: totalSeconds, text: text, words: []))
                }
            }
        }
        
        // 4. 按时间戳升序排序
        tempLines.sort { $0.timestamp < $1.timestamp }
        
        // 5. 滤除连续空行，并为普通 LRC 智能补全 Apple Music 级别的逐字/逐词时间戳
        var finalLines: [LyricLine] = []
        for (index, item) in tempLines.enumerated() {
            if item.text.isEmpty {
                if let last = finalLines.last, last.text.isEmpty {
                    continue
                }
                finalLines.append(LyricLine(timestamp: item.timestamp, text: "", words: []))
                continue
            }
            
            var words = item.words
            if words.isEmpty {
                let nextTime = (index + 1 < tempLines.count) ? tempLines[index + 1].timestamp : nil
                words = generateWordsForLine(timestamp: item.timestamp, text: item.text, nextTimestamp: nextTime)
            }
            
            finalLines.append(LyricLine(timestamp: item.timestamp, text: item.text, words: words))
        }
        
        return finalLines
    }
    
    static func generateWordsForLine(timestamp: TimeInterval, text: String, nextTimestamp: TimeInterval?) -> [LyricWord] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        
        let lineDuration: TimeInterval
        if let next = nextTimestamp, next > timestamp {
            let gap = next - timestamp
            if gap > 8.0 {
                lineDuration = min(gap - 2.0, max(3.5, Double(trimmed.count) * 0.38))
            } else {
                lineDuration = max(1.2, gap - 0.15)
            }
        } else {
            lineDuration = max(2.5, Double(trimmed.count) * 0.35)
        }
        
        var rawTokens: [String] = []
        var currentToken = ""
        
        for char in trimmed {
            if char.isASCII && (char.isLetter || char.isNumber) {
                currentToken.append(char)
            } else {
                if !currentToken.isEmpty {
                    rawTokens.append(currentToken)
                    currentToken = ""
                }
                rawTokens.append(String(char))
            }
        }
        if !currentToken.isEmpty {
            rawTokens.append(currentToken)
        }
        
        guard !rawTokens.isEmpty else { return [] }
        
        let weights = rawTokens.map { token -> Double in
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return 0.04
            }
            if token.rangeOfCharacter(from: .punctuationCharacters) != nil || token.rangeOfCharacter(from: .symbols) != nil {
                return 0.2
            }
            return Double(max(1, token.count))
        }
        
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return [] }
        
        var words: [LyricWord] = []
        var currentStart = timestamp
        
        for (index, token) in rawTokens.enumerated() {
            let wordDuration = lineDuration * (weights[index] / totalWeight)
            words.append(LyricWord(text: token, startTime: currentStart, duration: wordDuration))
            currentStart += wordDuration
        }
        
        return words
    }
}
