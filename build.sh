#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="MacDynamicIsland"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 构建支持直接抓取 SPlayer 界面与本地歌词的 Mac 灵动岛..."

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/"
fi

SWIFT_FILES=(
    "${PROJECT_DIR}/Sources/Models/MusicPlayerSource.swift"
    "${PROJECT_DIR}/Sources/Models/MultiPlayerBridge.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerNativeService.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerBridge.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerTracker.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerAccessibilityScraper.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerLocalLyricReader.swift"
    "${PROJECT_DIR}/Sources/Models/SPlayerLogMonitor.swift"
    "${PROJECT_DIR}/Sources/Models/ArtworkFetcher.swift"
    "${PROJECT_DIR}/Sources/Models/SystemMediaRemoteManager.swift"
    "${PROJECT_DIR}/Sources/Models/LyricFetcher.swift"
    "${PROJECT_DIR}/Sources/Models/MusicManager.swift"
    "${PROJECT_DIR}/Sources/Models/WeatherManager.swift"
    "${PROJECT_DIR}/Sources/Models/NotificationManager.swift"
    "${PROJECT_DIR}/Sources/Models/IslandSettingsManager.swift"
    "${PROJECT_DIR}/Sources/Models/SystemHUDManager.swift"
    "${PROJECT_DIR}/Sources/Models/FileShelfManager.swift"
    "${PROJECT_DIR}/Sources/Models/FocusTimerManager.swift"
    "${PROJECT_DIR}/Sources/Views/WaveformVisualizerView.swift"
    "${PROJECT_DIR}/Sources/Views/SpinningRecordView.swift"
    "${PROJECT_DIR}/Sources/Views/AlbumArtworkGradientView.swift"
    "${PROJECT_DIR}/Sources/Views/WeatherParticlesView.swift"
    "${PROJECT_DIR}/Sources/Views/WeatherWidgetView.swift"
    "${PROJECT_DIR}/Sources/Views/GlassmorphicView.swift"
    "${PROJECT_DIR}/Sources/Views/AppleMusicLyricsView.swift"
    "${PROJECT_DIR}/Sources/Views/FileShelfView.swift"
    "${PROJECT_DIR}/Sources/Views/FocusTimerView.swift"
    "${PROJECT_DIR}/Sources/Views/SystemStatsView.swift"
    "${PROJECT_DIR}/Sources/Views/HUDIslandOverlayView.swift"
    "${PROJECT_DIR}/Sources/Views/CompactIslandView.swift"
    "${PROJECT_DIR}/Sources/Views/CompactVerticalIslandView.swift"
    "${PROJECT_DIR}/Sources/Views/ExpandedIslandView.swift"
    "${PROJECT_DIR}/Sources/Views/ExpandedVerticalIslandView.swift"
    "${PROJECT_DIR}/Sources/Views/DynamicIslandView.swift"
    "${PROJECT_DIR}/Sources/App/IslandPanelManager.swift"
    "${PROJECT_DIR}/Sources/App/AppDelegate.swift"
    "${PROJECT_DIR}/Sources/App/Main.swift"
)

# 编译
swiftc "${SWIFT_FILES[@]}" \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework AVFoundation \
    -framework CoreLocation \
    -framework ApplicationServices \
    -framework IOKit \
    -parse-as-library

# 生成 Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.MacDynamicIsland</string>
    <key>CFBundleName</key>
    <string>Mac 灵动岛</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>灵动岛需要定位以同步系统实时天气与温度。</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>灵动岛需要定位以同步系统实时天气与温度。</string>
</dict>
</plist>
EOF

echo "📦 打包发布 SPlayer UI 直抓版安装包..."

rm -rf "${PROJECT_DIR}/${APP_NAME}.app"
cp -R "${APP_DIR}" "${PROJECT_DIR}/${APP_NAME}.app"

cd "${PROJECT_DIR}"
rm -f "MacDynamicIsland-Installer.zip"
zip -r -q "MacDynamicIsland-Installer.zip" "${APP_NAME}.app"

echo "🎉 SPlayer UI 直抓版灵动岛已成功编译打出！"
echo "  - 应用路径: ${PROJECT_DIR}/${APP_NAME}.app"
echo "  - 安装包路径: ${PROJECT_DIR}/MacDynamicIsland-Installer.zip"
