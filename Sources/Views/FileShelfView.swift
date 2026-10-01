import SwiftUI

struct FileShelfView: View {
    @ObservedObject var shelfManager = FileShelfManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                Text("NotchDrop 文件暂存架")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                if !shelfManager.items.isEmpty {
                    Button(action: { shelfManager.clearAll() }) {
                        Text("清空")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            if shelfManager.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundColor(shelfManager.isTargeted ? .cyan : .white.opacity(0.4))
                    Text(shelfManager.isTargeted ? "松开鼠标投递文件" : "将任意文件拖拽至此处暂存 / 复制路径")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(shelfManager.isTargeted ? Color.cyan : Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(shelfManager.items) { item in
                            VStack(spacing: 4) {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                
                                Text(item.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 65)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .contextMenu {
                                Button("Finder 中显示") { shelfManager.openInFinder(item) }
                                Button("复制绝对路径") { shelfManager.copyPath(item) }
                                Button("移除暂存") { shelfManager.removeItem(item) }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { shelfManager.isTargeted }, set: { shelfManager.isTargeted = $0 })) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            shelfManager.addFiles([url])
                        }
                    }
                }
            }
            return true
        }
    }
}
