import Foundation
import Combine

class FocusTimerManager: ObservableObject {
    static let shared = FocusTimerManager()
    
    @Published var durationSeconds: Int = 25 * 60 // 默认 25 分钟番茄钟
    @Published var timeRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var completedCount: Int = 0
    
    private var timer: Timer?
    
    var formattedRemainingTime: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.finish()
            }
        }
        
        NotificationManager.shared.showNotification(
            icon: "timer",
            iconColor: .orange,
            title: "番茄专注钟已开启",
            subtitle: "25 分钟倒计时开始"
        )
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        timeRemaining = durationSeconds
    }
    
    private func finish() {
        pause()
        completedCount += 1
        timeRemaining = durationSeconds
        
        NotificationManager.shared.showNotification(
            icon: "checkmark.seal.fill",
            iconColor: .green,
            title: "专注时间结束！",
            subtitle: "已累计完成 \(completedCount) 个番茄钟"
        )
    }
}
