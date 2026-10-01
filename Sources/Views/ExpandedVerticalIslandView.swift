import SwiftUI

struct ExpandedVerticalIslandView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var weatherManager = WeatherManager.shared
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. 顶部：时间与 SPlayer 旋转唱片
            VStack(spacing: 8) {
                HStack {
                    Text(weatherManager.timeString)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(musicManager.activeSource.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(musicManager.activeSource.tagBackgroundColor)
                        .foregroundColor(musicManager.activeSource.themeColor)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                
                // 黑胶唱片 (中心居中)
                SpinningRecordView(
                    artworkImage: musicManager.externalArtwork,
                    isPlaying: musicManager.isPlaying
                )
                
                VStack(spacing: 2) {
                    Text(musicManager.currentSong.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(musicManager.currentSong.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
            }
            
            // 2. 中间：Apple Music 风格弥散歌词板 (高屏立柱卡片)
            ZStack {
                AlbumArtworkGradientView(
                    artworkImage: musicManager.externalArtwork,
                    songTitle: musicManager.currentSong.title
                )
                
                AppleMusicLyricsView(
                    lyrics: musicManager.currentSong.lyrics,
                    currentIndex: musicManager.currentLyricIndex,
                    isVerticalCompact: true
                )
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .frame(height: 260)
            .padding(.horizontal, 10)
            
            // 3. 控制按钮⏮  ⏯  ⏭
            HStack(spacing: 20) {
                Button(action: { musicManager.previousTrack() }) {
                    Image(systemName: "backward.fill").font(.system(size: 14)).foregroundColor(.white)
                }.buttonStyle(PlainButtonStyle())
                
                Button(action: { musicManager.togglePlayPause() }) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16)).foregroundColor(.white)
                }.buttonStyle(PlainButtonStyle())
                
                Button(action: { musicManager.nextTrack() }) {
                    Image(systemName: "forward.fill").font(.system(size: 14)).foregroundColor(.white)
                }.buttonStyle(PlainButtonStyle())
            }
            
            Spacer(minLength: 0)
            
            // 4. 底部：天气 Widget
            HStack(spacing: 6) {
                Image(systemName: weatherManager.weather.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
                Text("\(weatherManager.weather.condition) \(weatherManager.weather.temperature)°")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 150, height: 580)
        .background(
            GlassmorphicBackground(cornerRadius: 28, opacity: 0.50)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
