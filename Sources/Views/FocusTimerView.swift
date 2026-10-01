import SwiftUI

struct FocusTimerView: View {
    @ObservedObject var timerManager = FocusTimerManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：环形倒计时进度
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.timeRemaining) / CGFloat(timerManager.durationSeconds))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.timeRemaining)
                
                VStack(spacing: 0) {
                    Text(timerManager.formattedRemainingTime)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("番茄钟")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 68, height: 68)
            
            // 右侧：控制与统计
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("专注工作法")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("完成: \(timerManager.completedCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        if timerManager.isRunning {
                            timerManager.pause()
                        } else {
                            timerManager.start()
                        }
                    }) {
                        Label(timerManager.isRunning ? "暂停" : "开始", systemImage: timerManager.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { timerManager.reset() }) {
                        Text("重置")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
