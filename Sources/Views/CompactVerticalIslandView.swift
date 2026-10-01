import SwiftUI

/// 竖版单个字/字符正向垂直逐字流光组件 (始终正面朝向，自上而下充盈)
struct VerticalWordTokenView: View {
    let word: LyricWord
    let currentTime: TimeInterval
    let fontSize: CGFloat
    let isCurrentLine: Bool
    
    var progress: Double {
        guard isCurrentLine else { return 0.0 }
        if currentTime >= word.endTime { return 1.0 }
        if currentTime <= word.startTime { return 0.0 }
        let duration = max(0.04, word.duration)
        return min(1.0, max(0.0, (currentTime - word.startTime) / duration))
    }
    
    var body: some View {
        let isBeingSung = (progress > 0.0 && progress < 1.0)
        let isFullySung = (progress >= 1.0)
        let fillProgress = max(0.0, min(1.0, progress))
        
        Group {
            if isFullySung {
                // 1. 已唱完：正面正立纯白，绝对不旋转侧躺
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundColor(.white)
            } else if isBeingSung {
                // 2. 正在唱响：自上而下垂直扫光流淌 + 柔和纯白辉光
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: fillProgress),
                                .init(color: Color.white.opacity(0.35), location: min(1.0, fillProgress + 0.04))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.75), radius: 3.0, x: 0, y: 0)
            } else {
                // 3. 未唱到：正面正立半透白，通透雅致
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundColor(Color.white.opacity(isCurrentLine ? 0.35 : 0.45))
            }
        }
    }
}

/// 竖版单句正向歌词排版 (从上到下逐字排列)
struct VerticalLyricLineView: View {
    let line: LyricLine
    let currentTime: TimeInterval
    let isCurrent: Bool
    
    // 拆分字符序列，保证每个字符均为正向正立排列
    var charTokens: [(text: String, word: LyricWord?)] {
        if !line.words.isEmpty {
            return line.words.flatMap { word -> [(String, LyricWord?)] in
                let chars = Array(word.text)
                if chars.count <= 1 {
                    return [(word.text, word)]
                }
                let totalDur = word.duration
                let durPerChar = totalDur / Double(chars.count)
                return chars.enumerated().map { idx, ch in
                    let chStart = word.startTime + Double(idx) * durPerChar
                    let subWord = LyricWord(text: String(ch), startTime: chStart, duration: durPerChar)
                    return (String(ch), subWord)
                }
            }
        } else {
            return Array(line.text).map { (String($0), nil) }
        }
    }
    
    var body: some View {
        let count = max(1, charTokens.count)
        // 根据字数智能调整字号与行间距，确保长歌词也能完整容纳且美观
        let fontSize: CGFloat = count > 12 ? 10.5 : (count > 9 ? 11.5 : 12.5)
        let spacing: CGFloat = count > 12 ? 1.5 : (count > 9 ? 2.5 : 3.5)
        
        VStack(spacing: spacing) {
            ForEach(0..<charTokens.count, id: \.self) { idx in
                let item = charTokens[idx]
                if let w = item.word {
                    VerticalWordTokenView(
                        word: w,
                        currentTime: currentTime,
                        fontSize: fontSize,
                        isCurrentLine: isCurrent
                    )
                } else {
                    Text(item.text)
                        .font(.system(size: fontSize, weight: isCurrent ? .semibold : .medium))
                        .foregroundColor(isCurrent ? .white : Color.white.opacity(0.35))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CompactVerticalIslandView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var weatherManager = WeatherManager.shared
    
    var currentLine: LyricLine? {
        let lyrics = musicManager.currentSong.lyrics
        let idx = musicManager.currentLyricIndex
        if !lyrics.isEmpty && idx >= 0 && idx < lyrics.count {
            return lyrics[idx]
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !musicManager.isPlaying {
                // 非播放状态：显示顶部时间与周几 (播放音乐时隐藏)
                VStack(spacing: 1) {
                    let timeParts = weatherManager.timeString.components(separatedBy: ":")
                    Text(timeParts.first ?? "13")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(timeParts.count > 1 ? timeParts[1] : "31")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text(weatherManager.dayOfWeekString)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                Spacer(minLength: 4)
            } else {
                Spacer(minLength: 8)
            }
            
            // 中间：始终正面朝向、从上到下逐字流动的竖排歌词 (播放音乐时独占整条垂直胶囊)
            ZStack(alignment: .center) {
                if let line = currentLine {
                    VerticalLyricLineView(
                        line: line,
                        currentTime: musicManager.playbackTime,
                        isCurrent: true
                    )
                    .id("v-lyric-\(musicManager.currentLyricIndex)")
                    .transition(.opacity)
                } else {
                    VStack(spacing: 5) {
                        if musicManager.isPlaying {
                            Image(systemName: "music.note")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(musicManager.activeSource.themeColor)
                                .padding(.bottom, 2)
                            
                            let defaultText = "\(musicManager.activeSource.displayName)播放中"
                            let displayTitle = musicManager.currentSong.title.isEmpty ? defaultText : musicManager.currentSong.title
                            let chars = Array(displayTitle.prefix(12))
                            ForEach(0..<chars.count, id: \.self) { i in
                                Text(String(chars[i]))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        } else {
                            ForEach(Array("Mac灵动岛"), id: \.self) { ch in
                                Text(String(ch))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                }
            }
            .frame(width: 36)
            .frame(maxHeight: musicManager.isPlaying ? 346 : 220)
            .animation(.easeInOut(duration: 0.22), value: musicManager.currentLyricIndex)
            
            if !musicManager.isPlaying {
                Spacer(minLength: 4)
                
                // 非播放状态：显示底部天气与温度 (播放音乐时隐藏)
                VStack(spacing: 2) {
                    Image(systemName: weatherManager.weather.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(.yellow)
                    Text("\(weatherManager.weather.temperature)°")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 8)
            }
        }
        .frame(width: 42, height: 380)
        .background(
            GlassmorphicBackground(cornerRadius: 21, opacity: 0.55)
        )
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: musicManager.isPlaying)
    }
}
