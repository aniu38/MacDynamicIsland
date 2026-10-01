import Foundation
import AppKit

/// 统一多音乐播放器控制与桥接器 (Multi-Player Unified Bridge)
/// 支持 SPlayer、网易云音乐、QQ音乐、Apple Music 的统一指令分发与状态监听
public class MultiPlayerBridge {
    public static let shared = MultiPlayerBridge()
    
    // MARK: - 统一控制指令分发
    
    /// 播放/暂停
    public func togglePlayPause(for source: MusicPlayerSource) {
        switch source {
        case .splayer:
            if SPlayerNativeService.shared.isConnected {
                SPlayerNativeService.shared.toggle()
            } else {
                SPlayerBridge.shared.togglePlayPause()
            }
            
        case .appleMusic:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to playpause
            end if
            """)
            
        case .netease:
            let success = runAppleScript("""
            if application "NeteaseMusic" is running then
                tell application "NeteaseMusic" to playpause
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(2)
            }
            
        case .qqMusic:
            let success = runAppleScript("""
            if application "QQMusic" is running then
                tell application "QQMusic" to playpause
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(2)
            }
            
        case .system:
            SystemMediaRemoteManager.shared.sendMediaCommand(2)
        }
    }
    
    /// 下一曲
    public func nextTrack(for source: MusicPlayerSource) {
        switch source {
        case .splayer:
            if SPlayerNativeService.shared.isConnected {
                SPlayerNativeService.shared.nextTrack()
            } else {
                SPlayerBridge.shared.nextTrack()
            }
            
        case .appleMusic:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to next track
            end if
            """)
            
        case .netease:
            let success = runAppleScript("""
            if application "NeteaseMusic" is running then
                tell application "NeteaseMusic" to next track
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(4)
            }
            
        case .qqMusic:
            let success = runAppleScript("""
            if application "QQMusic" is running then
                tell application "QQMusic" to next track
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(4)
            }
            
        case .system:
            SystemMediaRemoteManager.shared.sendMediaCommand(4)
        }
    }
    
    /// 上一曲
    public func previousTrack(for source: MusicPlayerSource) {
        switch source {
        case .splayer:
            if SPlayerNativeService.shared.isConnected {
                SPlayerNativeService.shared.previousTrack()
            } else {
                SPlayerBridge.shared.previousTrack()
            }
            
        case .appleMusic:
            runAppleScript("""
            if application "Music" is running then
                tell application "Music" to previous track
            end if
            """)
            
        case .netease:
            let success = runAppleScript("""
            if application "NeteaseMusic" is running then
                tell application "NeteaseMusic" to previous track
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(5)
            }
            
        case .qqMusic:
            let success = runAppleScript("""
            if application "QQMusic" is running then
                tell application "QQMusic" to previous track
                return true
            end if
            return false
            """)
            if !success {
                SystemMediaRemoteManager.shared.sendMediaCommand(5)
            }
            
        case .system:
            SystemMediaRemoteManager.shared.sendMediaCommand(5)
        }
    }
    
    // MARK: - Apple Music 原生状态深层轮询器
    public struct AppleMusicTrackInfo {
        public let isPlaying: Bool
        public let title: String
        public let artist: String
        public let album: String
        public let position: TimeInterval
        public let duration: TimeInterval
    }
    
    /// 获取当前 Apple Music 的播放详情 (极速 AppleScript 探测，无感低开销)
    public func fetchAppleMusicInfo() -> AppleMusicTrackInfo? {
        let scriptSource = """
        if application "Music" is running then
            tell application "Music"
                set pState to (player state as string)
                if pState is not "stopped" then
                    try
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tAlbum to album of current track
                        set tPos to player position
                        set tDur to duration of current track
                        return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tPos as string) & "|||" & (tDur as string)
                    on error
                        return "error"
                    end try
                end if
            end tell
        end if
        return "none"
        """
        
        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        guard let output = descriptor.stringValue, output != "none", output != "error" else { return nil }
        
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = (parts[0].lowercased() == "playing")
        let title = parts[1].trimmingCharacters(in: .whitespaces)
        let artist = parts[2].trimmingCharacters(in: .whitespaces)
        let album = parts[3].trimmingCharacters(in: .whitespaces)
        let pos = Double(parts[4]) ?? 0.0
        let dur = Double(parts[5]) ?? 300.0
        
        guard !title.isEmpty else { return nil }
        
        return AppleMusicTrackInfo(
            isPlaying: isPlaying,
            title: title,
            artist: artist.isEmpty ? "Apple Music" : artist,
            album: album,
            position: pos,
            duration: dur
        )
    }
    
    // MARK: - 辅助方法
    
    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let res = script.executeAndReturnError(&error)
            if error == nil {
                if res.descriptorType == typeBoolean {
                    return res.booleanValue
                }
                return true
            }
        }
        return false
    }
    
    private func sendSystemEventsKey(processName: String, keyCode: UInt16, modifiers: String = "") {
        let script = """
        tell application "System Events"
            if exists process "\(processName)" then
                tell process "\(processName)"
                    key code \(keyCode) \(modifiers)
                end tell
            end if
        end tell
        """
        runAppleScript(script)
    }
}
