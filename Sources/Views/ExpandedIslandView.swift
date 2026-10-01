import SwiftUI

struct ExpandedIslandView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var weatherManager = WeatherManager.shared
    @Binding var isExpanded: Bool
    @Binding var activePageIndex: Int
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            
            // ==================== 左侧：SPlayer 音乐控制区 ====================
            HStack(spacing: 12) {
                // 旋转黑胶唱片：自动匹配 SPlayer 封面并在播放时不断平滑旋转
                SpinningRecordView(
                    artworkImage: musicManager.externalArtwork,
                    isPlaying: musicManager.isPlaying
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    // 状态控制标签：动态显示当前活跃播放器 (SPlayer / 网易云音乐 / QQ音乐 / Apple Music)
                    HStack(spacing: 4) {
                        Text(musicManager.activeSource.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(musicManager.activeSource.tagBackgroundColor)
                            .foregroundColor(musicManager.activeSource.themeColor)
                            .cornerRadius(4)
                    }
                    
                    Text(musicManager.currentSong.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 130, alignment: .leading)
                    
                    // 控制按钮：⏮  ⏯  ⏭
                    HStack(spacing: 16) {
                        Button(action: {
                            musicManager.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            musicManager.togglePlayPause()
                        }) {
                            Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            musicManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(width: 200)
            
            // ==================== 中间：多功能动态板块 (歌词 / 文件暂存 / 番茄钟 / 系统硬件) ====================
            ZStack {
                AlbumArtworkGradientView(
                    artworkImage: musicManager.externalArtwork,
                    songTitle: musicManager.currentSong.title
                )
                
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        switch activePageIndex {
                        case 0:
                            AppleMusicLyricsView(
                                lyrics: musicManager.currentSong.lyrics,
                                currentIndex: musicManager.currentLyricIndex
                            )
                        case 1:
                            FileShelfView()
                        case 2:
                            FocusTimerView()
                        default:
                            SystemStatsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 底部分页可点击指示器
                    HStack(spacing: 8) {
                        Spacer()
                        ForEach(0..<4, id: \.self) { idx in
                            Circle()
                                .fill(idx == activePageIndex ? musicManager.activeSource.themeColor : Color.white.opacity(0.35))
                                .frame(width: idx == activePageIndex ? 7 : 5, height: idx == activePageIndex ? 7 : 5)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        activePageIndex = idx
                                    }
                                }
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
            .frame(maxWidth: .infinity)
            
            // ==================== 右侧：1:1 天气 App 小组件 ====================
            WeatherWidgetView()
                .frame(width: 140, height: 100)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 740, height: 125)
        .background(
            GlassmorphicBackground(cornerRadius: 32, opacity: 0.48)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
    
    private func getLyricText(_ lyrics: [LyricLine], index: Int) -> String {
        guard index >= 0 && index < lyrics.count else { return " " }
        return lyrics[index].text
    }
}
