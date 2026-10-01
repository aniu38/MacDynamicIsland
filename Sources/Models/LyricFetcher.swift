import Foundation
import Combine

class LyricFetcher: ObservableObject {
    static let shared = LyricFetcher()
    
    @Published var currentLyrics: [LyricLine] = []
    @Published var isLoading: Bool = false
    
    private var cache: [String: [LyricLine]] = [:]
    private var lastTitle: String = ""
    
    init() {
        setupPreloadedLyrics()
    }
    
    private func setupPreloadedLyrics() {
        // 《Savage Love》原装英中双语歌词
        cache["Savage Love"] = MusicManager.parseLRC("""
        [00:00.00]Savage Love - Metrixx
        [00:04.00]Lover but before you leave
        [00:07.50]在你回到你前任身边随手给予的
        [00:11.00]Usually I would never would never even care
        [00:15.50]但在你离开之前我才不会在乎呢
        [00:20.00]Baby I know she creepin' I feel it in the air
        [00:25.50]宝贝我知道爱在传播你能感受到
        [00:30.00]Every night and every day
        [00:34.50]一天又一天
        [00:39.00]I try to make you stay
        [00:43.50]我想方设法留住你
        [00:48.00]Savage love
        [00:52.00]野蛮的爱
        """)
        
        cache["没心没肺"] = MusicManager.parseLRC("""
        [00:00.00]没心没肺 - 俊俊
        [00:06.00]如果可以没心没肺地生活
        [00:11.50]是不是就不会有那么多难过
        [00:17.00]夜深人静的时候 一个人发呆
        [00:23.00]回忆像潮水般 将我淹没
        """)
        
        cache["亦是此间少年（demo）"] = MusicManager.parseLRC("""
        [00:00.00]亦是此间少年 - 枯木逢春
        [00:05.00]风吹过这片土地
        [00:10.00]留下少年的足迹
        [00:15.00]归来仍是此间少年
        """)
    }
    
    func fetchLyricsByNcmID(_ ncmID: String, title: String) {
        if let cached = cache[title] {
            DispatchQueue.main.async {
                self.currentLyrics = cached
            }
            return
        }
        
        // 1. 优先尝试从 SPlayer 本地 SQLite 缓存读取 100% 匹配的歌词 (0毫秒响应)
        if let localLyrics = fetchLocalSPlayerLyric(ncmID: ncmID) {
            DispatchQueue.main.async {
                self.cache[title] = localLyrics
                self.currentLyrics = localLyrics
            }
            return
        }
        
        // 2. 本地无缓存时调用在线 API 抓取
        fetchLRCBySongID(Int(ncmID) ?? 0, originalTitle: title)
    }
    
    private func fetchLocalSPlayerLyric(ncmID: String) -> [LyricLine]? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = "\(home)/Library/Application Support/SPlayer/DataCache/cache.db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, "SELECT CAST(data AS TEXT) FROM kv_cache WHERE key = '\(ncmID).json';"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let jsonString = String(data: data, encoding: .utf8), !jsonString.isEmpty else { return nil }
            
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                var lyricString: String? = nil
                if let yrcDict = json["yrc"] as? [String: Any], let yrc = yrcDict["lyric"] as? String, !yrc.isEmpty {
                    lyricString = yrc
                } else if let lrcDict = json["lrc"] as? [String: Any], let lrc = lrcDict["lyric"] as? String {
                    lyricString = lrc
                }
                
                if let rawLrc = lyricString {
                    let lines = MusicManager.parseLRC(rawLrc)
                    if !lines.isEmpty {
                        return lines
                    }
                }
            }
        } catch {
            print("读取 SPlayer 本地歌词失败: \(error)")
        }
        return nil
    }
    
    func fetchLyrics(for rawTitle: String, artist: String = "") {
        guard !rawTitle.isEmpty else { return }
        
        let title = MusicManager.cleanSongTitle(rawTitle)
        
        if title != lastTitle {
            lastTitle = title
            
            let cleanTitle = title.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            if let cached = cache[title] ?? cache[cleanTitle] {
                self.currentLyrics = cached
                return
            }
            
            self.currentLyrics = getLyricsForTitle(cleanTitle)
            searchOnlineLyrics(title: cleanTitle, artist: artist)
        }
    }
    
    func getLyricsForTitle(_ rawTitle: String, sourceName: String = "音乐") -> [LyricLine] {
        let title = MusicManager.cleanSongTitle(rawTitle)
        let cleanTitle = title.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        if let cached = cache[title] ?? cache[cleanTitle] {
            return cached
        }
        
        return [
            LyricLine(timestamp: 0.0, text: "正在播放: 《\(cleanTitle)》"),
            LyricLine(timestamp: 3.0, text: "♪ \(sourceName) 音乐实时同步中 ♪"),
            LyricLine(timestamp: 6.0, text: "♪ 享受音乐的美好时光 ♪"),
            LyricLine(timestamp: 12.0, text: "♪ \(sourceName) 正在同步 ♪")
        ]
    }
    
    private func searchOnlineLyrics(title: String, artist: String) {
        let keyword = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let searchURLString = "https://music.163.com/api/cloudsearch/pc?s=\(keyword)&type=1&offset=0&limit=1"
        
        guard let url = URL(string: searchURLString) else { return }
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 4.0)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let songs = result["songs"] as? [[String: Any]],
                   let firstSong = songs.first,
                   let songID = firstSong["id"] as? Int {
                    self?.fetchLRCBySongID(songID, originalTitle: title)
                }
            } catch {
                print("搜索歌词失败: \(error)")
            }
        }.resume()
    }
    
    private func fetchLRCBySongID(_ songID: Int, originalTitle: String) {
        guard songID > 0 else { return }
        let lrcURLString = "https://music.163.com/api/song/lyric?os=pc&id=\(songID)&lv=-1&kv=-1&tv=-1&yv=-1"
        guard let url = URL(string: lrcURLString) else { return }
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 4.0)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var lyricString: String? = nil
                    
                    if let yrcDict = json["yrc"] as? [String: Any], let yrc = yrcDict["lyric"] as? String, !yrc.isEmpty {
                        lyricString = yrc
                    } else if let lrcDict = json["lrc"] as? [String: Any], let lrc = lrcDict["lyric"] as? String {
                        lyricString = lrc
                    }
                    
                    if let raw = lyricString {
                        let parsedLines = MusicManager.parseLRC(raw)
                        if !parsedLines.isEmpty {
                            DispatchQueue.main.async {
                                self?.cache[originalTitle] = parsedLines
                                if self?.lastTitle == originalTitle {
                                    self?.currentLyrics = parsedLines
                                }
                            }
                        }
                    }
                }
            } catch {
                print("解析 LRC/YRC 失败: \(error)")
            }
        }.resume()
    }
}
