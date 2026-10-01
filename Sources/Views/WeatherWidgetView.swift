import SwiftUI

struct WeatherWidgetView: View {
    @ObservedObject var weatherManager = WeatherManager.shared
    
    var body: some View {
        ZStack {
            // 1. 系统 Weather App / Widget 主主题渐变背景
            getWeatherBackgroundGradient(condition: weatherManager.weather.condition)
            
            // 2. 下雨、下雪、闪光粒子特效
            WeatherParticlesView(condition: weatherManager.weather.condition)
            
            // 3. 详细天气信息与图标 (1:1 对齐天气 App 小组件排版)
            VStack(alignment: .leading, spacing: 6) {
                // 顶行：时间 01:30 周三
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(weatherManager.timeString)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(weatherManager.dayOfWeekString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer(minLength: 0)
                
                // 底行：天气图标 + 温度 + 天气状况
                HStack(spacing: 6) {
                    Image(systemName: weatherManager.weather.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(getWeatherIconColor(condition: weatherManager.weather.condition))
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Text("\(weatherManager.weather.temperature)°")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(weatherManager.weather.condition)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
    
    private func getWeatherBackgroundGradient(condition: String) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 19 || hour < 6
        
        var colors: [Color] = []
        
        if condition.contains("雨") {
            // 雨天主题 (系统 Weather Widget 雨天沉浸色)
            colors = [Color(red: 0.12, green: 0.18, blue: 0.28), Color(red: 0.22, green: 0.32, blue: 0.45)]
        } else if condition.contains("雪") {
            // 雪天主题 (晶莹雪蓝)
            colors = [Color(red: 0.35, green: 0.48, blue: 0.62), Color(red: 0.58, green: 0.68, blue: 0.82)]
        } else if condition.contains("晴") && !isNight {
            // 白天晴天 (暖金阳光蓝)
            colors = [Color(red: 0.16, green: 0.52, blue: 0.92), Color(red: 0.38, green: 0.75, blue: 0.98)]
        } else if isNight || condition.contains("夜") {
            // 晴夜 (深空银河)
            colors = [Color(red: 0.05, green: 0.08, blue: 0.22), Color(red: 0.12, green: 0.16, blue: 0.36)]
        } else if condition.contains("多云") || condition.contains("阴") {
            // 多云/阴天
            colors = [Color(red: 0.30, green: 0.36, blue: 0.48), Color(red: 0.48, green: 0.55, blue: 0.66)]
        } else {
            colors = [Color(red: 0.20, green: 0.48, blue: 0.82), Color(red: 0.38, green: 0.68, blue: 0.92)]
        }
        
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
    
    private func getWeatherIconColor(condition: String) -> Color {
        if condition.contains("晴") { return .yellow }
        if condition.contains("雨") { return .cyan }
        if condition.contains("雪") { return .white }
        return .yellow
    }
}
