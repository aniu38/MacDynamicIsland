import SwiftUI
import Combine

class AlbumGradientViewModel: ObservableObject {
    @Published var animateGradient: Bool = false
    
    func startAnimation() {
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            animateGradient.toggle()
        }
    }
}

struct AlbumArtworkGradientView: View {
    var artworkImage: NSImage?
    var songTitle: String
    
    @StateObject private var viewModel = AlbumGradientViewModel()
    
    var body: some View {
        ZStack {
            // 主背景渐变 (Apple Music 弥散流体质感)
            LinearGradient(
                colors: getGradientColors(for: songTitle, image: artworkImage),
                startPoint: viewModel.animateGradient ? .topLeading : .bottomLeading,
                endPoint: viewModel.animateGradient ? .bottomTrailing : .topTrailing
            )
            .blur(radius: 12)
            .opacity(0.85)
            
            // 叠加一层微弱的黑色磨砂，保证歌词白字清晰可辨
            Color.black.opacity(0.35)
        }
        .onAppear {
            viewModel.startAnimation()
        }
    }
    
    private func getGradientColors(for title: String, image: NSImage?) -> [Color] {
        if let image = image, let extracted = extractColors(from: image), extracted.count >= 2 {
            return extracted
        }
        
        let hash = abs(title.hashValue)
        let themeIndex = hash % 5
        
        switch themeIndex {
        case 0:
            // 经典 Apple Music 炫彩深紫与幽蓝
            return [Color(red: 0.22, green: 0.08, blue: 0.38), Color(red: 0.08, green: 0.15, blue: 0.42), Color(red: 0.05, green: 0.05, blue: 0.15)]
        case 1:
            // 极光渐变 (蓝绿调)
            return [Color(red: 0.05, green: 0.28, blue: 0.38), Color(red: 0.12, green: 0.42, blue: 0.48), Color(red: 0.03, green: 0.10, blue: 0.20)]
        case 2:
            // 玫瑰深金/暖绯色调
            return [Color(red: 0.38, green: 0.12, blue: 0.22), Color(red: 0.48, green: 0.18, blue: 0.12), Color(red: 0.12, green: 0.05, blue: 0.08)]
        case 3:
            // 靛蓝深青调
            return [Color(red: 0.08, green: 0.18, blue: 0.45), Color(red: 0.25, green: 0.12, blue: 0.45), Color(red: 0.04, green: 0.06, blue: 0.18)]
        default:
            // 炫紫粉橙调
            return [Color(red: 0.28, green: 0.10, blue: 0.42), Color(red: 0.42, green: 0.12, blue: 0.32), Color(red: 0.08, green: 0.05, blue: 0.16)]
        }
    }
    
    private func extractColors(from image: NSImage) -> [Color]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        let p1Index = ((height / 4) * width + (width / 4)) * 4
        let p2Index = ((height / 2) * width + (width / 2)) * 4
        let p3Index = ((height * 3 / 4) * width + (width * 3 / 4)) * 4
        
        func makeColor(_ idx: Int) -> Color {
            guard idx + 3 < rawData.count else { return Color.purple }
            let r = Double(rawData[idx]) / 255.0
            let g = Double(rawData[idx + 1]) / 255.0
            let b = Double(rawData[idx + 2]) / 255.0
            return Color(red: r * 0.6 + 0.1, green: g * 0.6 + 0.1, blue: b * 0.6 + 0.1)
        }
        
        return [makeColor(p1Index), makeColor(p2Index), makeColor(p3Index)]
    }
}
