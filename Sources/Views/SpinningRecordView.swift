import SwiftUI
import Combine

class SpinningRecordViewModel: ObservableObject {
    @Published var rotationAngle: Double = 0.0
    private var timer: Timer?
    
    func startSpinning() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.rotationAngle = (self.rotationAngle + 1.2).truncatingRemainder(dividingBy: 360)
        }
    }
    
    func stopSpinning() {
        timer?.invalidate()
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct SpinningRecordView: View {
    var artworkImage: NSImage?
    var isPlaying: Bool
    
    @StateObject private var viewModel = SpinningRecordViewModel()
    
    var body: some View {
        ZStack {
            // 1. 唱片底盘黑胶纹理
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.15), Color(white: 0.05), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 3)
            
            // 唱片纹理圆圈
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 50, height: 50)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 40, height: 40)
            
            // 2. 匹配到的 SPlayer 真实专辑封面图片
            if let artwork = artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 38, height: 38)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            // 3. 唱片中心小圆圈
            Circle()
                .fill(Color.black)
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 3, height: 3)
        }
        .rotationEffect(.degrees(viewModel.rotationAngle))
        .onAppear {
            if isPlaying {
                viewModel.startSpinning()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                viewModel.startSpinning()
            } else {
                viewModel.stopSpinning()
            }
        }
    }
}
