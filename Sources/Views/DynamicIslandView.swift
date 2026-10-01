import SwiftUI

class DynamicIslandViewModel: ObservableObject {
    static let shared = DynamicIslandViewModel()
    @Published var isExpanded: Bool = false
    @Published var activePageIndex: Int = 4
}

struct DynamicIslandView: View {
    @ObservedObject private var viewModel = DynamicIslandViewModel.shared
    @ObservedObject var notifManager = NotificationManager.shared
    @ObservedObject var settings = IslandSettingsManager.shared
    
    var body: some View {
        ZStack {
            if let notif = notifManager.currentNotification {
                // 灵动岛弹窗通知形态
                NotificationIslandView(notification: notif)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 0.7).combined(with: .opacity)
                        )
                    )
            } else if viewModel.isExpanded {
                ExpandedIslandView(isExpanded: $viewModel.isExpanded, activePageIndex: $viewModel.activePageIndex)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.75).combined(with: .opacity),
                            removal: .scale(scale: 0.75).combined(with: .opacity)
                        )
                    )
            } else {
                CompactIslandView()
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .scale(scale: 0.85).combined(with: .opacity)
                        )
                    )
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                viewModel.isExpanded.toggle()
                if viewModel.isExpanded && MusicManager.shared.isPlaying {
                    viewModel.activePageIndex = 0
                }
                IslandPanelManager.shared.updateWindowFrameForState(isExpanded: viewModel.isExpanded)
            }
        }
    }
}

// 灵动岛通知气泡视图
struct NotificationIslandView: View {
    let notification: IslandNotification
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(notification.iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(notification.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 42)
        .background(
            GlassmorphicBackground(cornerRadius: 21, opacity: 0.52)
        )
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }
}
