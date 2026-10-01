import Foundation
import AppKit

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let icon: NSImage
    let addedAt: Date
}

class FileShelfManager: ObservableObject {
    static let shared = FileShelfManager()
    
    @Published var items: [ShelfItem] = []
    @Published var isTargeted: Bool = false
    
    func addFiles(_ urls: [URL]) {
        for url in urls {
            if !items.contains(where: { $0.url == url }) {
                let name = url.lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let item = ShelfItem(url: url, name: name, icon: icon, addedAt: Date())
                items.append(item)
            }
        }
        
        if !urls.isEmpty {
            NotificationManager.shared.showNotification(
                icon: "tray.and.arrow.down.fill",
                iconColor: .cyan,
                title: "文件已加入暂存架",
                subtitle: "共添加 \(urls.count) 个文件至灵动岛 Shelf"
            )
        }
    }
    
    func removeItem(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }
    
    func clearAll() {
        items.removeAll()
    }
    
    func openInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    func copyPath(_ item: ShelfItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.path, forType: .string)
        
        NotificationManager.shared.showNotification(
            icon: "doc.on.doc.fill",
            iconColor: .green,
            title: "路径已复制",
            subtitle: item.name
        )
    }
}
