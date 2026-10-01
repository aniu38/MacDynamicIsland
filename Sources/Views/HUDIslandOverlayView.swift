import SwiftUI

struct HUDIslandOverlayView: View {
    let hud: HUDNotification
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hud.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            Text(hud.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(hud.value)))
                }
            }
            .frame(height: 6)
            
            Text("\(Int(hud.value * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(height: 38)
        .background(
            GlassmorphicBackground(cornerRadius: 19, opacity: 0.55)
        )
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }
}
