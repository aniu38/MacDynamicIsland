import AppKit
import Combine

class ArtworkFetcher: ObservableObject {
    static let shared = ArtworkFetcher()
    
    @Published var artworkImage: NSImage?
    private var cache: [String: NSImage] = [:]
    private var lastKey: String = ""
    
    func fetchArtworkByNcmID(_ ncmID: String, title: String, artist: String = "") {
        let key = "\(title)-\(ncmID)"
        guard !title.isEmpty, key != lastKey else { return }
        lastKey = key
        
        if let cached = cache[key] ?? cache[title] {
            DispatchQueue.main.async {
                self.artworkImage = cached
            }
            return
        }
        
        let urlString = "https://music.163.com/api/song/detail/?id=\(ncmID)&ids=[\(ncmID)]"
        guard let url = URL(string: urlString) else {
            fetchArtwork(for: title, artist: artist)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 4.0)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                self?.fetchArtwork(for: title, artist: artist)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let songs = json["songs"] as? [[String: Any]],
                   let firstSong = songs.first,
                   let album = (firstSong["al"] as? [String: Any]) ?? (firstSong["album"] as? [String: Any]),
                   let picUrlString = album["picUrl"] as? String,
                   let picURL = URL(string: picUrlString) {
                    
                    self?.downloadImage(from: picURL, key: key)
                } else {
                    self?.fetchArtwork(for: title, artist: artist)
                }
            } catch {
                self?.fetchArtwork(for: title, artist: artist)
            }
        }.resume()
    }
    
    func fetchArtwork(for title: String, artist: String = "") {
        let key = "\(title)-\(artist)"
        guard !title.isEmpty, key != lastKey else { return }
        lastKey = key
        
        if let cached = cache[key] ?? cache[title] {
            DispatchQueue.main.async {
                self.artworkImage = cached
            }
            return
        }
        
        let keyword = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let searchURLString = "https://music.163.com/api/cloudsearch/pc?s=\(keyword)&type=1&offset=0&limit=1"
        guard let url = URL(string: searchURLString) else { return }
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 4.0)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let songs = result["songs"] as? [[String: Any]],
                   let firstSong = songs.first {
                    
                    let album = (firstSong["al"] as? [String: Any]) ?? (firstSong["album"] as? [String: Any])
                    if let picUrlString = album?["picUrl"] as? String,
                       let picURL = URL(string: picUrlString) {
                        self?.downloadImage(from: picURL, key: key)
                    }
                }
            } catch {
                print("解析 Artwork 失败: \(error)")
            }
        }.resume()
    }
    
    private func downloadImage(from url: URL, key: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil, let image = NSImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self?.cache[key] = image
                self?.artworkImage = image
            }
        }.resume()
    }
}
