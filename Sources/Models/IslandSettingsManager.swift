import Foundation
import Combine

enum IslandOrientation: String, CaseIterable, Identifiable {
    case horizontal = "横版"
    case vertical = "竖版"
    
    var id: String { self.rawValue }
}

class IslandSettingsManager: ObservableObject {
    static let shared = IslandSettingsManager()
    
    @Published var orientation: IslandOrientation = .horizontal {
        didSet {
            UserDefaults.standard.set(IslandOrientation.horizontal.rawValue, forKey: "IslandOrientation")
        }
    }
    
    init() {
        self.orientation = .horizontal
        UserDefaults.standard.set(IslandOrientation.horizontal.rawValue, forKey: "IslandOrientation")
    }
    
    func toggleOrientation() {
        // 暂时隐藏竖版所有内容，锁定为横版
        self.orientation = .horizontal
    }
}
