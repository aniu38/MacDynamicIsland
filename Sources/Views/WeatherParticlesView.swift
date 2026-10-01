import SwiftUI
import Combine

struct RainDropItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var length: CGFloat
    var speed: CGFloat
    var opacity: Double
}

struct SnowflakeItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var speed: CGFloat
    var opacity: Double
    var swingOffset: CGFloat
}

class WeatherParticlesViewModel: ObservableObject {
    @Published var rainDrops: [RainDropItem] = []
    @Published var snowflakes: [SnowflakeItem] = []
    private var timer: Timer?
    
    func updateCondition(_ condition: String, size: CGSize) {
        // 彻底解决粒子残留 Bug：若不下雨，清空 rainDrops；若不下雪，清空 snowflakes
        if !condition.contains("雨") {
            rainDrops = []
        }
        if !condition.contains("雪") {
            snowflakes = []
        }
        
        setupParticles(condition: condition, size: size)
        startAnimation(condition: condition, size: size)
    }
    
    private func setupParticles(condition: String, size: CGSize) {
        let width = size.width > 0 ? size.width : 140
        let height = size.height > 0 ? size.height : 120
        
        if condition.contains("雨") {
            rainDrops = (0..<25).map { _ in
                RainDropItem(
                    x: CGFloat.random(in: 0...width),
                    y: CGFloat.random(in: 0...height),
                    length: CGFloat.random(in: 8...16),
                    speed: CGFloat.random(in: 6...12),
                    opacity: Double.random(in: 0.35...0.75)
                )
            }
        }
        
        if condition.contains("雪") {
            snowflakes = (0..<20).map { _ in
                SnowflakeItem(
                    x: CGFloat.random(in: 0...width),
                    y: CGFloat.random(in: 0...height),
                    radius: CGFloat.random(in: 1.2...2.8),
                    speed: CGFloat.random(in: 1.0...2.5),
                    opacity: Double.random(in: 0.5...0.9),
                    swingOffset: CGFloat.random(in: 2.0...6.0)
                )
            }
        }
    }
    
    private func startAnimation(condition: String, size: CGSize) {
        timer?.invalidate()
        let height = size.height > 0 ? size.height : 120
        let width = size.width > 0 ? size.width : 140
        
        guard condition.contains("雨") || condition.contains("雪") else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if condition.contains("雨") && !self.rainDrops.isEmpty {
                for i in self.rainDrops.indices {
                    self.rainDrops[i].y += self.rainDrops[i].speed
                    self.rainDrops[i].x -= 0.5
                    if self.rainDrops[i].y > height {
                        self.rainDrops[i].y = -self.rainDrops[i].length
                        self.rainDrops[i].x = CGFloat.random(in: 0...width + 20)
                    }
                }
            }
            
            if condition.contains("雪") && !self.snowflakes.isEmpty {
                for i in self.snowflakes.indices {
                    self.snowflakes[i].y += self.snowflakes[i].speed
                    if self.snowflakes[i].y > height {
                        self.snowflakes[i].y = -5
                        self.snowflakes[i].x = CGFloat.random(in: 0...width)
                    }
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct WeatherParticlesView: View {
    let condition: String
    @StateObject private var viewModel = WeatherParticlesViewModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if condition.contains("雨") {
                    Canvas { context, size in
                        for drop in viewModel.rainDrops {
                            var path = Path()
                            path.move(to: CGPoint(x: drop.x, y: drop.y))
                            path.addLine(to: CGPoint(x: drop.x - 2, y: drop.y + drop.length))
                            
                            context.stroke(
                                path,
                                with: .color(Color.white.opacity(drop.opacity)),
                                lineWidth: 1.2
                            )
                        }
                    }
                } else if condition.contains("雪") {
                    Canvas { context, size in
                        for flake in viewModel.snowflakes {
                            let rect = CGRect(
                                x: flake.x + sin(flake.y / 15.0) * flake.swingOffset,
                                y: flake.y,
                                width: flake.radius * 2,
                                height: flake.radius * 2
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(Color.white.opacity(flake.opacity))
                            )
                        }
                    }
                } else if condition.contains("夜") || condition.contains("晴") && Calendar.current.component(.hour, from: Date()) >= 19 {
                    Canvas { context, size in
                        for i in 0..<15 {
                            let x = CGFloat((i * 37) % Int(size.width > 0 ? size.width : 100))
                            let y = CGFloat((i * 23) % Int(size.height > 0 ? size.height : 80))
                            let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(Double.random(in: 0.3...0.9))))
                        }
                    }
                }
            }
            .onAppear {
                viewModel.updateCondition(condition, size: geo.size)
            }
            .onChange(of: condition) { newCondition in
                viewModel.updateCondition(newCondition, size: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
}
