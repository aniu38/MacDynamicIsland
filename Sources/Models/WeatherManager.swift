import Foundation
import Combine
import CoreLocation

struct WeatherInfo: Equatable {
    var temperature: Int
    var condition: String
    var iconName: String
    var city: String
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var timeString: String = ""
    @Published var dayOfWeekString: String = ""
    @Published var weather: WeatherInfo = WeatherInfo(temperature: 19, condition: "多云", iconName: "cloud.sun.fill", city: "本地")
    
    private var clockTimer: Timer?
    private var weatherTimer: Timer?
    private let locationManager = CLLocationManager()
    
    // 默认硬件位置（系统精准定位 fallback）
    private var currentLat: Double = 31.2304
    private var currentLon: Double = 121.4737
    
    override init() {
        super.init()
        
        setupLocationManager()
        updateTime()
        startClockTimer()
        
        fetchRealSystemWeather()
        startWeatherTimer()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.currentLat = location.coordinate.latitude
            self.currentLon = location.coordinate.longitude
            fetchWeatherForCoordinates(lat: currentLat, lon: currentLon)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("系统 Location 提示: \(error)")
    }
    
    func startClockTimer() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
    }
    
    func startWeatherTimer() {
        weatherTimer?.invalidate()
        // 60秒 (1分钟) 高频同步系统最新天气与温度
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchRealSystemWeather()
        }
    }
    
    func updateTime() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        formatter.dateFormat = "HH:mm"
        timeString = formatter.string(from: Date())
        
        formatter.dateFormat = "EEE"
        dayOfWeekString = formatter.string(from: Date())
    }
    
    func fetchRealSystemWeather() {
        fetchWeatherForCoordinates(lat: currentLat, lon: currentLon)
    }
    
    private func fetchWeatherForCoordinates(lat: Double, lon: Double) {
        let weatherURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
        guard let url = URL(string: weatherURLString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let currentWeather = json["current_weather"] as? [String: Any],
                   let temp = currentWeather["temperature"] as? Double,
                   let weatherCode = currentWeather["weathercode"] as? Int {
                    
                    let roundedTemp = Int(round(temp))
                    let (condition, icon) = self?.mapWeatherCode(weatherCode) ?? ("多云", "cloud.sun.fill")
                    
                    DispatchQueue.main.async {
                        self?.weather = WeatherInfo(
                            temperature: roundedTemp,
                            condition: condition,
                            iconName: icon,
                            city: "本地"
                        )
                    }
                }
            } catch {
                print("解析 Weather API 失败: \(error)")
            }
        }
        task.resume()
    }
    
    private func mapWeatherCode(_ code: Int) -> (String, String) {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 19 || hour < 6
        
        switch code {
        case 0:
            // 晴朗天
            return (isNight ? "晴夜" : "晴", isNight ? "moon.stars.fill" : "sun.max.fill")
        case 1, 2, 3:
            // 多云
            return ("多云", isNight ? "cloud.moon.fill" : "cloud.sun.fill")
        case 45, 48:
            // 雾
            return ("有雾", "cloud.fog.fill")
        case 51, 53, 55, 56, 57, 61, 63, 65:
            // 明确雨天
            return ("雨", "cloud.rain.fill")
        case 71, 73, 75, 77:
            // 明确雪天
            return ("雪", "cloud.snow.fill")
        case 80, 81, 82:
            // 阵雨
            return ("阵雨", "cloud.heavyrain.fill")
        case 95, 96, 99:
            // 雷阵雨
            return ("雷阵雨", "cloud.bolt.rain.fill")
        default:
            return ("多云", isNight ? "cloud.moon.fill" : "cloud.sun.fill")
        }
    }
}
