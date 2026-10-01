import SwiftUI
import Combine

class WaveformViewModel: ObservableObject {
    @Published var heights: [CGFloat] = []
    private var timer: Timer?
    
    func setup(barCount: Int) {
        if heights.count != barCount {
            heights = Array(repeating: 3, count: barCount)
        }
    }
    
    func startAnimating(isPlaying: Bool, barCount: Int, maxHeight: CGFloat) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, isPlaying else { return }
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.6)) {
                self.heights = (0..<barCount).map { _ in
                    CGFloat.random(in: 3...maxHeight)
                }
            }
        }
    }
    
    func stopAnimating(barCount: Int) {
        timer?.invalidate()
        withAnimation(.easeOut(duration: 0.3)) {
            heights = Array(repeating: 2, count: barCount)
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct WaveformVisualizerView: View {
    var isPlaying: Bool
    var barCount: Int = 36
    var maxHeight: CGFloat = 16
    var customColor: Color? = nil
    
    @ObservedObject private var musicManager = MusicManager.shared
    @StateObject private var viewModel = WaveformViewModel()
    
    private var barColor: Color {
        customColor ?? musicManager.activeSource.themeColor
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.95), barColor.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: viewModel.heights.indices.contains(i) ? viewModel.heights[i] : 3)
            }
        }
        .onAppear {
            viewModel.setup(barCount: barCount)
            if isPlaying {
                viewModel.startAnimating(isPlaying: true, barCount: barCount, maxHeight: maxHeight)
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                viewModel.startAnimating(isPlaying: true, barCount: barCount, maxHeight: maxHeight)
            } else {
                viewModel.stopAnimating(barCount: barCount)
            }
        }
    }
}
