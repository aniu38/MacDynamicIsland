import SwiftUI

struct WordByWordTextTokenView: View {
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
                // 1. 已唱完：纯净耀眼纯白，基线稳固，零阴影，排版严谨如刻
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundColor(.white)
            } else if isBeingSung {
                // 2. 正在唱响：Apple Music 标准平滑线性扫光充盈 + 柔和纯白辉光氛围（字符绝对不跳动）
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: fillProgress),
                                .init(color: Color.white.opacity(0.35), location: min(1.0, fillProgress + 0.03))
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.white.opacity(0.75), radius: 3.2, x: 0, y: 0)
            } else {
                // 3. 未唱到：纯净半透明白，通透雅致，基线恒定无杂质
                Text(word.text)
                    .font(.system(size: fontSize, weight: isCurrentLine ? .semibold : .medium))
                    .foregroundColor(Color.white.opacity(isCurrentLine ? 0.35 : 0.45))
            }
        }
    }
}

struct AppleMusicLyricsView: View {
    let lyrics: [LyricLine]
    let currentIndex: Int
    var isVerticalCompact: Bool = false
    @ObservedObject var musicManager = MusicManager.shared
    
    private var lineHeight: CGFloat {
        isVerticalCompact ? 24.0 : 28.0
    }
    private var lineSpacing: CGFloat {
        isVerticalCompact ? 4.0 : 6.0
    }
    
    var body: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2.0
            let itemTotalHeight = lineHeight + lineSpacing
            let targetY = centerY - (CGFloat(max(0, currentIndex)) * itemTotalHeight + lineHeight / 2.0)
            let currentTime = musicManager.playbackTime
            
            ZStack(alignment: .topLeading) {
                if lyrics.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("♪ \(musicManager.activeSource.displayName) 逐字歌词同步中 ♪")
                            .font(.system(size: isVerticalCompact ? 12 : 15, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.5), radius: 4, x: 0, y: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: lineSpacing) {
                        ForEach(Array(lyrics.enumerated()), id: \.offset) { idx, line in
                            let isCurrent = (idx == currentIndex)
                            let distance = abs(idx - currentIndex)
                            let lineOpacity = isCurrent ? 1.0 : max(0.18, 0.50 - Double(distance) * 0.16)
                            let baseFontSize: CGFloat = isVerticalCompact ? (isCurrent ? 12.5 : (distance == 1 ? 10.5 : 9.5)) : (isCurrent ? 15.5 : (distance == 1 ? 13.0 : 11.5))
                            let blurRadius: CGFloat = (distance == 0) ? 0 : (distance == 1 ? 0.4 : 1.2)
                            
                            HStack(spacing: 0) {
                                if isCurrent && !line.words.isEmpty {
                                    ForEach(line.words) { word in
                                        WordByWordTextTokenView(
                                            word: word,
                                            currentTime: currentTime,
                                            fontSize: baseFontSize,
                                            isCurrentLine: isCurrent
                                        )
                                    }
                                } else {
                                    Text(line.text)
                                        .font(.system(size: baseFontSize, weight: isCurrent ? .bold : .medium))
                                        .foregroundColor(Color.white.opacity(lineOpacity))
                                        .blur(radius: blurRadius)
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.60)
                            .frame(height: lineHeight, alignment: .leading)
                        }
                    }
                    .offset(y: targetY)
                    .animation(.spring(response: 0.52, dampingFraction: 0.88), value: currentIndex)
                }
            }
            .clipped()
        }
    }
}
