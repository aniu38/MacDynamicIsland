# 🏝️ Mac 灵动岛 (Dynamic Island for macOS)

<p align="center">
  <img src="docs/images/idle_center.png" alt="Mac 灵动岛" width="600" />
</p>

<p align="center">
  <b>专为 Mac 打造的原生灵动交互中枢 · 深度融合四大音乐播放器 · Apple Music 级动态弥散流体歌词</b>
</p>

<p align="center">
  <a href="#-快速下载与安装">📦 快速安装</a> •
  <a href="USER_GUIDE.md">📖 完整使用手册</a> •
  <a href="#-多音乐播放器深度接入">🎵 多播放器支持</a> •
  <a href="#-快捷键与手势">⌨️ 快捷键</a> •
  <a href="#-开发与构建">🛠️ 源码构建</a>
</p>

---

## ✨ 核心亮点

- 🎨 **Apple 级超精密玻璃拟态**：完美融入 macOS 系统壁纸与刘海 (Notch) 设计，提供高透光率与硬件抗锯齿圆角。
- 🎵 **四大音乐播放器无感智能接入**：
  - **网易云音乐 (NeteaseMusic)**：中国红主题，专属红音符与律动波形条。
  - **QQ 音乐 (QQMusic)**：翡翠绿主题，专属绿音符与清爽流体氛围。
  - **Apple Music**：桃粉紫红主题，macOS ScriptingBridge 原生毫秒级精准直连。
  - **SPlayer**：经典青蓝主题，内核 SQLite 0毫秒直读原装歌词与时间戳。
- 🌊 **Apple Music 弥散流体光晕背景**：根据正在播放歌曲的唱片封面色彩实时生成流体弥散高斯模糊。
- 🌟 **原装逐字扫光歌词 (Word-by-Word)**：毫秒级时间戳平滑扫光与纯白辉光渲染，基线稳固绝不晃动。
- 🧲 **120Hz 全局拖拽与刘海磁吸**：屏幕任意位置自由拖拽，靠近刘海与屏幕边缘自动平滑吸附。
- ⏱️ **内置多功能扩展中心**：集成文件暂存架 (NotchDrop)、番茄钟专注计时器与系统硬件/网速监视。

---

## 📦 快速下载与安装

### 方式一：下载即用安装包 (推荐)
直接下载本项目发布的便携压缩包：
- 🚀 **[GitHub Releases 高速下载 MacDynamicIsland-Installer.zip (27 MB)](https://github.com/aniu38/MacDynamicIsland/releases/download/v1.0.0/MacDynamicIsland-Installer.zip)**
- 📦 **[仓库内源文件下载 (MacDynamicIsland-Installer.zip)](MacDynamicIsland-Installer.zip)**

**安装方法：**
1. 解压 `MacDynamicIsland-Installer.zip`；
2. 将 `MacDynamicIsland.app` 拖入 `/Applications` (应用程序) 文件夹；
3. 双击打开即可立即享受屏幕顶端的灵动体验！

> [!TIP]
> 首次打开若系统提示“来自未受信任的开发者”，请在 **系统设置 > 隐私与安全性** 中点击 **“仍要打开”** 即可。

---

## 🎵 多音乐播放器深度接入

灵动岛内置多播放器智能感知引擎，无需任何手动设置，当对应播放器出声时，灵动岛将在 0.1 秒内自动变色、变标并同步原装歌词与专辑封面。

### 1. 网易云音乐 (中国红)
| 胶囊收缩态 | 全景展开态 |
| :---: | :---: |
| ![网易云音乐胶囊](docs/images/netease_compact.png) | ![网易云音乐展开](docs/images/netease_expanded.png) |

### 2. QQ 音乐 (翡翠绿)
| 胶囊收缩态 | 全景展开态 |
| :---: | :---: |
| ![QQ音乐胶囊](docs/images/qqmusic_compact.png) | ![QQ音乐展开](docs/images/qqmusic_expanded.png) |

### 3. Apple Music (桃粉紫红)
| 胶囊收缩态 | 全景展开态 |
| :---: | :---: |
| ![Apple Music胶囊](docs/images/applemusic_compact.png) | ![Apple Music展开](docs/images/applemusic_expanded.png) |

### 4. SPlayer (经典青色)
| 胶囊收缩态 | 全景展开态 |
| :---: | :---: |
| ![SPlayer胶囊](docs/images/splayer_compact.png) | ![SPlayer展开](docs/images/splayer_expanded.png) |

---

## ⌨️ 快捷键与手势

| 按键 / 手势 | 作用说明 |
| :--- | :--- |
| **`⌥ ⌘ R`** / **`⌘ R`** | **全局一键居中复位**：无论灵动岛被移动至何处，瞬间重置回屏幕顶端刘海正下方 |
| **鼠标单击灵动岛** | 在【收缩胶囊】与【全景展开】形态之间平滑切换（播放音乐时自动直达歌词） |
| **鼠标按住拖拽** | 120Hz 极速拖动窗口至屏幕任意位置，松开自动贴边磁吸 |
| **顶部菜单栏控制** | 屏幕右上角常驻 `灵动岛` 菜单，支持无安装效果预览与音乐控制 |

---

## 📖 完整使用手册

了解更详细的功能指引、多功能面板（文件暂存库、番茄钟、系统状态）与疑难解答，请参阅：
👉 **[Mac 灵动岛 官方图文使用手册 (USER_GUIDE.md)](USER_GUIDE.md)**

---

## 🛠️ 源码构建

本项目采用纯 Swift + SwiftUI 与原生 AppKit 开发，依赖极简、零冗余三方库。

### 环境要求
- macOS 13.0 (Ventura) / 14.0 (Sonoma) / 15.0 (Sequoia) 或更高版本
- Xcode 15.0+ 或 Swift 5.9+

### 本地编译
```bash
git clone https://github.com/aniu38/MacDynamicIsland.git
cd MacDynamicIsland
./build.sh
```
编译成功后，应用产物将生成在 `MacDynamicIsland.app`，打包安装包输出为 `MacDynamicIsland-Installer.zip`。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 许可协议开源。
