import Foundation
import SwiftUI

/// 支持的音乐播放器来源
public enum MusicPlayerSource: String, CaseIterable, Identifiable {
    case splayer = "SPlayer"
    case appleMusic = "Apple Music"
    case netease = "网易云音乐"
    case qqMusic = "QQ音乐"
    case system = "系统播放器"
    
    public var id: String { rawValue }
    
    /// 界面呈现的友好名称
    public var displayName: String {
        switch self {
        case .splayer: return "SPlayer"
        case .appleMusic: return "Apple Music"
        case .netease: return "网易云音乐"
        case .qqMusic: return "QQ音乐"
        case .system: return "正在播放"
        }
    }
    
    /// 品牌专属主题色 (保持 Apple Music 灵动岛原装高级质感)
    public var themeColor: Color {
        switch self {
        case .splayer:
            return .cyan
        case .appleMusic:
            // Apple Music 标志性桃粉紫红
            return Color(red: 0.98, green: 0.28, blue: 0.48)
        case .netease:
            // 网易云音乐 经典中国红
            return Color(red: 0.95, green: 0.22, blue: 0.22)
        case .qqMusic:
            // QQ音乐 活力翡翠绿
            return Color(red: 0.18, green: 0.82, blue: 0.45)
        case .system:
            return .cyan
        }
    }
    
    /// 标签背景透明度胶囊
    public var tagBackgroundColor: Color {
        themeColor.opacity(0.25)
    }
    
    /// SF Symbol 对应图标
    public var iconName: String {
        switch self {
        case .splayer: return "play.circle.fill"
        case .appleMusic: return "apple.logo"
        case .netease: return "music.note.list"
        case .qqMusic: return "waveform.circle.fill"
        case .system: return "music.note"
        }
    }
    
    /// 根据 Bundle Identifier 或应用程序名称智能识别播放器
    public static func detect(bundleID: String?, appName: String?) -> MusicPlayerSource {
        let b = bundleID?.lowercased() ?? ""
        let n = appName?.lowercased() ?? ""
        
        if b.contains("splayer") || n.contains("splayer") {
            return .splayer
        }
        if b.contains("apple.music") || b == "com.apple.music" || n == "music" || (b.contains("apple") && n.contains("音乐")) {
            return .appleMusic
        }
        if b.contains("netease") || b.contains("163music") || n.contains("netease") || n.contains("网易云") {
            return .netease
        }
        if b.contains("qqmusic") || b.contains("tencent.qqmusic") || n.contains("qqmusic") || n.contains("qq音乐") {
            return .qqMusic
        }
        return .system
    }
}
