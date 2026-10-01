import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var hudManager = SystemHUDManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 电源与电池状态 (自适应无电池台式机与笔记本电池)
            HStack(spacing: 6) {
                if hudManager.hasBattery {
                    // 笔记本内置电池状态
                    Image(systemName: hudManager.isCharging ? "battery.100.bolt" : batteryIconName(for: hudManager.batteryPercentage))
                        .font(.system(size: 16))
                        .foregroundColor(hudManager.isCharging ? .green : (hudManager.batteryPercentage <= 20 ? .red : .white))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(hudManager.batteryPercentage)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(hudManager.isCharging ? "电源连接中" : "电池供电")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    // 台式机无电池外接电源供电状态 (如 Mac Studio / Mac mini / iMac)
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("电源供电")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("交流电 (无电池)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider().frame(height: 24).background(Color.white.opacity(0.2))
            
            // 2. 真实 CPU 占用率
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.1f%%", hudManager.cpuUsage))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("CPU 负载")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider().frame(height: 24).background(Color.white.opacity(0.2))
            
            // 3. 真实实时网速检测 (BSD getifaddrs 真实吞吐量)
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("↓ \(hudManager.downloadSpeedStr)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("↑ \(hudManager.uploadSpeedStr)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func batteryIconName(for level: Int) -> String {
        switch level {
        case 0..<20: return "battery.0"
        case 20..<40: return "battery.25"
        case 40..<60: return "battery.50"
        case 60..<80: return "battery.75"
        default: return "battery.100"
        }
    }
}
