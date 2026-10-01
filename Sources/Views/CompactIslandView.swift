import SwiftUI

struct CompactLyricView: View {
    let lyrics: [LyricLine]
    let currentIndex: Int
    let isPlaying: Bool
    @ObservedObject var musicManager = MusicManager.shared
    
    var currentLine: LyricLine? {
        if !lyrics.isEmpty && currentIndex >= 0 && currentIndex < lyrics.count {
            return lyrics[currentIndex]
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(musicManager.activeSource.themeColor)
            
            // 极简纯净原位淡入淡出容器 (Clean & Clear Cross-Dissolve)
            ZStack(alignment: .center) {
                if let line = currentLine {
                    HStack(spacing: 0) {
                        if !line.words.isEmpty {
                            ForEach(line.words) { word in
                                WordByWordTextTokenView(
                                    word: word,
                                    currentTime: musicManager.playbackTime,
                                    fontSize: 12.0,
                                    isCurrentLine: true
                                )
                            }
                        } else {
                            Text(line.text)
                                .font(.system(size: 12.0, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .id("lyric-line-\(currentIndex)")
                    // 纯粹干净的原位淡入淡出：彻底杜绝上下位移与眼花晃动，清晰明了
                    .transition(.opacity)
                } else {
                    Text(isPlaying ? (musicManager.currentSong.title.isEmpty ? "♪ \(musicManager.activeSource.displayName) 正在播放 ♪" : "♪ \(musicManager.currentSong.title) ♪") : "Mac 灵动岛")
                        .font(.system(size: 12.0, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(height: 22)
            .animation(.easeInOut(duration: 0.22), value: currentIndex)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CompactIslandView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var weatherManager = WeatherManager.shared
    
    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 0) {
                if !musicManager.isPlaying {
                    // 非播放状态：显示左侧时间 周三
                    HStack(spacing: 6) {
                        Text(weatherManager.timeString)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(weatherManager.dayOfWeekString)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Spacer(minLength: 4)
                }
                
                // 播放音乐时：隐藏左右两侧，整个灵动岛全宽居中独占显示歌词
                CompactLyricView(
                    lyrics: musicManager.currentSong.lyrics,
                    currentIndex: musicManager.currentLyricIndex,
                    isPlaying: musicManager.isPlaying
                )
                .frame(maxWidth: .infinity, alignment: .center)
                
                if !musicManager.isPlaying {
                    Spacer(minLength: 4)
                    
                    // 非播放状态：显示右侧天气与温度
                    HStack(spacing: 4) {
                        Image(systemName: weatherManager.weather.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text("\(weatherManager.weather.condition) \(weatherManager.weather.temperature)°")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: musicManager.isPlaying)
            
            // 底部细波形音频跳动条 (收窄高度与内切，留给歌词充裕呼吸空间)
            WaveformVisualizerView(isPlaying: musicManager.isPlaying, barCount: 36, maxHeight: 6)
                .padding(.bottom, 3)
                .padding(.horizontal, 16)
        }
        .frame(height: 38)
        .background(
            GlassmorphicBackground(cornerRadius: 19, opacity: 0.52)
        )
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }
}
