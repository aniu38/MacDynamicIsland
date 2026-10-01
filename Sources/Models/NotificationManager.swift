import SwiftUI
import Combine

struct IslandNotification: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentNotification: IslandNotification?
    private var dismissTimer: Timer?
    
    func showNotification(icon: String, iconColor: Color = .green, title: String, subtitle: String, duration: TimeInterval = 3.0) {
        dismissTimer?.invalidate()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            currentNotification = IslandNotification(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle)
        }
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.currentNotification = nil
            }
        }
    }
}
