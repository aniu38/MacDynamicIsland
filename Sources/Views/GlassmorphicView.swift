import SwiftUI
import AppKit

struct VisualEffectBlur: NSViewRepresentable {
    var cornerRadius: CGFloat = 0
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
    }
}

struct GlassmorphicBackground: View {
    var cornerRadius: CGFloat
    var opacity: Double = 0.28
    
    var body: some View {
        ZStack {
            // 1. macOS 系统级原生高透光 GPU 玻璃 (使用 SwiftUI 纯原生 .ultraThinMaterial，100% 裁切无任何直角底框)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // 2. 液态暗色透视半透明层 (低黑透，让桌布与窗口清晰透出)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(opacity),
                            Color(white: 0.04).opacity(opacity + 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. macOS 27 棱镜折射彩虹调色层 (Prismatic Glass Iridescence)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.cyan.opacity(0.07),
                            Color.purple.opacity(0.07),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 4. 外层顶端弱高光边框 (仅顶部一侧显示微弱高光，底部 100% 完全透明 Color.clear，物理级消除拖拽移动时底部白线闪烁)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
