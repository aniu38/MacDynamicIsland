import Foundation
import Combine
import AppKit
import Darwin
import IOKit.ps

struct HUDNotification: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let value: Double // 0.0 ~ 1.0
    let type: HUDType
    
    enum HUDType {
        case volume
        case brightness
        case battery
    }
}

class SystemHUDManager: ObservableObject {
    static let shared = SystemHUDManager()
    
    @Published var currentHUD: HUDNotification? = nil
    
    // 电源与电池状态
    @Published var hasBattery: Bool = false
    @Published var powerSourceType: String = "AC Power"
    @Published var batteryPercentage: Int = 100
    @Published var isCharging: Bool = false
    
    // CPU 负载
    @Published var cpuUsage: Double = 0.0
    
    // 实时网络速率
    @Published var downloadSpeedStr: String = "0 KB/s"
    @Published var uploadSpeedStr: String = "0 KB/s"
    @Published var downloadSpeedBytesPerSec: Double = 0.0
    @Published var uploadSpeedBytesPerSec: Double = 0.0
    
    private var hudDismissTimer: Timer?
    private var monitorTimer: Timer?
    
    // 网络统计采样基准
    private var lastNetworkSampleTime: TimeInterval = 0
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    
    // CPU 采样基准
    private var prevCpuInfo = host_cpu_load_info()
    private var hasInitialCpuSample = false
    
    init() {
        startHardwareMonitoring()
    }
    
    func startHardwareMonitoring() {
        monitorTimer?.invalidate()
        // 每 1.0 秒实时精准采样一次网速、CPU 负载与电源状态
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
            self?.updateSystemNetworkAndCPU()
        }
        updateBatteryStatus()
        updateSystemNetworkAndCPU()
    }
    
    // MARK: - 电源与电池状态实时检测 (兼容 Mac Studio / Mac mini / MacBook)
    func updateBatteryStatus() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        let powerType = (IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?) ?? "AC Power"
        
        if sources.isEmpty {
            // 无内置电池的台式 Mac (如 Mac Studio / Mac mini / Mac Pro / iMac): 纯电源供电
            DispatchQueue.main.async {
                self.hasBattery = false
                self.powerSourceType = powerType
                self.batteryPercentage = 100
                self.isCharging = false
            }
            return
        }
        
        var foundBattery = false
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let isInternal = (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
                if isInternal || !foundBattery {
                    foundBattery = true
                    let current = info[kIOPSCurrentCapacityKey] as? Int ?? 100
                    let isChargingState = (info[kIOPSIsChargingKey] as? Bool) ?? false
                    
                    DispatchQueue.main.async {
                        self.hasBattery = true
                        self.powerSourceType = powerType
                        self.batteryPercentage = current
                        self.isCharging = isChargingState
                    }
                }
            }
        }
        
        if !foundBattery {
            DispatchQueue.main.async {
                self.hasBattery = false
                self.powerSourceType = powerType
                self.batteryPercentage = 100
                self.isCharging = false
            }
        }
    }
    
    // MARK: - 网络流量与 CPU 占用率实时检测
    private func updateSystemNetworkAndCPU() {
        let now = CACurrentMediaTime()
        let (currentIn, currentOut) = fetchNetworkBytes()
        
        if lastNetworkSampleTime > 0 && now > lastNetworkSampleTime {
            let dt = now - lastNetworkSampleTime
            if dt > 0.2 {
                let diffIn = (currentIn >= lastBytesIn) ? (currentIn - lastBytesIn) : 0
                let diffOut = (currentOut >= lastBytesOut) ? (currentOut - lastBytesOut) : 0
                
                let inRate = Double(diffIn) / dt
                let outRate = Double(diffOut) / dt
                
                let downStr = formatSpeed(inRate)
                let upStr = formatSpeed(outRate)
                
                DispatchQueue.main.async {
                    self.downloadSpeedBytesPerSec = inRate
                    self.uploadSpeedBytesPerSec = outRate
                    self.downloadSpeedStr = downStr
                    self.uploadSpeedStr = upStr
                }
            }
        }
        
        lastNetworkSampleTime = now
        lastBytesIn = currentIn
        lastBytesOut = currentOut
        
        // 实时获取真实 CPU 负载
        let cpu = calculateRealCpuUsage()
        DispatchQueue.main.async {
            self.cpuUsage = cpu
        }
    }
    
    // MARK: - BSD getifaddrs 真实网卡吞吐量提取
    private func fetchNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        
        while let ptr = cursor {
            let flags = Int32(ptr.pointee.ifa_flags)
            // 排除 loopback (lo0) 本地回环，仅统计处于 UP 状态的物理/活跃网络接口
            if (flags & IFF_LOOPBACK) == 0 && (flags & IFF_UP) != 0 {
                if let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = ptr.pointee.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(ifData.pointee.ifi_ibytes)
                        totalOut += UInt64(ifData.pointee.ifi_obytes)
                    }
                }
            }
            cursor = ptr.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        } else if bytesPerSec < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0))
        }
    }
    
    // MARK: - Darwin host_statistics 真实 CPU 计算
    private func calculateRealCpuUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0.0 }
        
        if !hasInitialCpuSample {
            prevCpuInfo = cpuInfo
            hasInitialCpuSample = true
            return 5.0
        }
        
        let userDiff = Double(cpuInfo.cpu_ticks.0 - prevCpuInfo.cpu_ticks.0)
        let sysDiff  = Double(cpuInfo.cpu_ticks.1 - prevCpuInfo.cpu_ticks.1)
        let idleDiff = Double(cpuInfo.cpu_ticks.2 - prevCpuInfo.cpu_ticks.2)
        let niceDiff = Double(cpuInfo.cpu_ticks.3 - prevCpuInfo.cpu_ticks.3)
        
        prevCpuInfo = cpuInfo
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        guard totalTicks > 0 else { return 0.0 }
        let usage = ((userDiff + sysDiff + niceDiff) / totalTicks) * 100.0
        return max(0.0, min(100.0, usage))
    }
    
    func triggerVolumeHUD(value: Double) {
        showHUD(HUDNotification(
            icon: value == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
            title: "系统音量",
            value: value,
            type: .volume
        ))
    }
    
    func triggerBrightnessHUD(value: Double) {
        showHUD(HUDNotification(
            icon: "sun.max.fill",
            title: "屏幕亮度",
            value: value,
            type: .brightness
        ))
    }
    
    func showHUD(_ hud: HUDNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentHUD = hud
            self.hudDismissTimer?.invalidate()
            self.hudDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.currentHUD = nil
            }
        }
    }
}
