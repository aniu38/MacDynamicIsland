import Foundation
import Combine
import AppKit

class SystemMediaRemoteManager: ObservableObject {
    static let shared = SystemMediaRemoteManager()
    
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = "SPlayer"
    @Published var currentElapsedTime: TimeInterval = 0.0
    @Published var currentDuration: TimeInterval = 300.0
    @Published var isPlaying: Bool = true
    @Published var artworkImage: NSImage? = nil
    
    // 当前媒体源识别信息
    @Published var currentSource: MusicPlayerSource = .splayer
    @Published var currentBundleIdentifier: String = ""
    @Published var currentAppName: String = ""
    
    private var timer: Timer?
    private var mrHandle: UnsafeMutableRawPointer?
    
    private typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRSendCommandFunc = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias MRGetPIDFunc = @convention(c) (DispatchQueue, @escaping (pid_t) -> Void) -> Void
    
    private var getInfoFunc: MRGetInfoFunc?
    private var sendCommandFunc: MRSendCommandFunc?
    private var registerFunc: MRRegisterFunc?
    private var getPIDFunc: MRGetPIDFunc?
    
    init() {
        setupMediaRemote()
        startPolling()
    }
    
    private func setupMediaRemote() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        self.mrHandle = handle
        
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            self.registerFunc = unsafeBitCast(sym, to: MRRegisterFunc.self)
            self.registerFunc?(DispatchQueue.main)
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            self.getInfoFunc = unsafeBitCast(sym, to: MRGetInfoFunc.self)
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            self.sendCommandFunc = unsafeBitCast(sym, to: MRSendCommandFunc.self)
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            self.getPIDFunc = unsafeBitCast(sym, to: MRGetPIDFunc.self)
        }
        
        let center = NotificationCenter.default
        let notificationName = NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
        center.addObserver(self, selector: #selector(handleNotification), name: notificationName, object: nil)
    }
    
    @objc private func handleNotification() {
        fetchNowPlayingInfo()
    }
    
    func startPolling() {
        timer?.invalidate()
        // 0.1秒极高频扫描，保证 SPlayer 播放状态0延迟输入
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }
    
    func fetchNowPlayingInfo() {
        // 1. 尝试获取当前播放应用的 PID
        if let getPIDFunc = getPIDFunc {
            getPIDFunc(DispatchQueue.main) { [weak self] pid in
                guard let self = self, pid > 0 else { return }
                if let app = NSRunningApplication(processIdentifier: pid) {
                    let bId = app.bundleIdentifier ?? ""
                    let name = app.localizedName ?? ""
                    let detected = MusicPlayerSource.detect(bundleID: bId, appName: name)
                    self.currentSource = detected
                    self.currentBundleIdentifier = bId
                    self.currentAppName = name
                }
            }
        }
        
        guard let getInfoFunc = getInfoFunc else { return }
        
        getInfoFunc(DispatchQueue.main) { [weak self] infoDict in
            guard let self = self else { return }
            
            var title = (infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
            var artist = (infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
            
            // 如果为空，且 SPlayer 在线，回退到 SPlayer 进程文件及窗口标题
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                if let lsofTitle = SPlayerTracker.shared.getSPlayerPlayingFileName(), !lsofTitle.isEmpty {
                    title = lsofTitle
                    artist = "SPlayer"
                    self.currentSource = .splayer
                } else if let winTitle = SPlayerBridge.shared.fetchSPlayerWindowTitle(), !winTitle.isEmpty {
                    title = winTitle
                    artist = "SPlayer"
                    self.currentSource = .splayer
                }
            }
            
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            
            // 清理各播放器特有的标题后缀
            title = MusicManager.cleanSongTitle(title)
            if artist.isEmpty {
                artist = self.currentSource.displayName
            }
            
            var elapsedTime = (infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0.0
            let duration = (infoDict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 300.0
            let rate = (infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 1.0
            let isPlayingStatus = rate > 0.0
            
            if isPlayingStatus {
                if let timestampDate = infoDict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                    let delta = Date().timeIntervalSince(timestampDate)
                    if delta > 0 && delta < 3600 {
                        elapsedTime += delta * rate
                    }
                }
            }
            
            var image: NSImage? = nil
            if let imageData = infoDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                image = NSImage(data: imageData)
            }
            
            DispatchQueue.main.async {
                self.currentTitle = title
                self.currentArtist = artist
                self.currentElapsedTime = elapsedTime
                self.currentDuration = duration
                self.isPlaying = isPlayingStatus
                if let image = image {
                    self.artworkImage = image
                }
            }
        }
    }
    
    func sendMediaCommand(_ commandID: Int32) {
        if let sendCommandFunc = sendCommandFunc {
            _ = sendCommandFunc(commandID, nil)
        }
    }
    
    func togglePlayPause() {
        MultiPlayerBridge.shared.togglePlayPause(for: currentSource)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.fetchNowPlayingInfo()
        }
    }
    
    func nextTrack() {
        MultiPlayerBridge.shared.nextTrack(for: currentSource)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.fetchNowPlayingInfo()
        }
    }
    
    func previousTrack() {
        MultiPlayerBridge.shared.previousTrack(for: currentSource)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.fetchNowPlayingInfo()
        }
    }
    
    deinit {
        timer?.invalidate()
        if let handle = mrHandle {
            dlclose(handle)
        }
    }
}
