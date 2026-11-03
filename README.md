# Live Wallpaper Plugin

[English](#live-wallpaper-plugin) | [简体中文](#简体中文)

![Live Wallpaper settings](screenshot.png)

Video wallpaper plugin for [Dux Shell](https://github.com/duxlabs-dev/dux-shell) (formerly Dank Material Shell). It uses `mpvpaper` for playback and includes a settings interface, DankBar wallpaper switcher, slideshow/shuffle mode, and battery-aware power saving.

> **Fork of [tokisak1kurum1/mpvpaper-plugin](https://github.com/tokisak1kurum1/mpvpaper-plugin)** — enhanced with slideshow, shuffle, battery awareness, and a skip button in the widget.

## Features

### From the original plugin
- Smooth wallpaper switching without restarting `mpvpaper` for every video change
- Shared video library with independent wallpaper selection per monitor, or one wallpaper across all monitors
- DankBar widget for browsing and switching wallpapers
- Hardware decoding with `auto`, `nvdec`, `vaapi`, and `vdpau`, plus fill mode and volume controls
- Configurable lock-screen behavior: stop the player or pause and resume from the current position
- Configurable periodic `mpvpaper` restart to mitigate memory leaks (disabled by default)
- DMS dynamic colors generated from the active video wallpaper, including when switching to the dynamic theme
- English and Simplified Chinese settings

### ✨ New in this fork
- **Slideshow mode** — automatically cycle through your video library at a configurable interval (30s to 2h)
- **Shuffle mode** — randomize the order with smart history tracking to ensure full rotation before repeats
- **Skip button** — manually advance to the next wallpaper from the DankBar widget popup
- **Battery-aware power saving** — automatically pause video wallpapers when running on battery, resume when plugged in
- **Enhanced pause logic** — combined battery + fullscreen + lock-screen awareness for maximum power efficiency

## Installation

Live Wallpaper Plugin is available in the DMS Plugin Directory.

1. Open **DMS Settings → Plugins → Browse**.
2. Search for **Live Wallpaper** (or **MpvPaper Plugin**).
3. Install and enable the plugin.

Install the required system packages first. On Arch Linux:

```bash
sudo pacman -S ffmpeg
yay -S mpvpaper
```

## Usage

1. Open the plugin settings and add video files or a folder.
2. Select a monitor and choose its wallpaper, or enable the same wallpaper for all monitors.
3. Configure playback, lock-screen behavior, and optional advanced MPV settings as needed.
4. Add **Live Wallpaper** to the DankBar layout if you want quick wallpaper switching from the bar.

### Slideshow Mode
1. Go to **Settings → Slideshow** section.
2. Toggle **Auto-cycle wallpapers** on.
3. Set the desired interval (30 seconds to 2 hours).
4. Optionally enable **Shuffle order** for random rotation.
5. Use the ⏭ **skip button** in the DankBar popup to manually advance.

### Battery Power Saving
1. Go to **Settings → Battery & Power** section.
2. Toggle **Pause on battery power** on.
3. The plugin will automatically pause playback when unplugged and resume when AC power is restored.

The settings page and DankBar widget use the same video library. Changing a wallpaper only changes the current selection; adding videos does not automatically replace the active wallpaper.

Setting the volume to zero disables audio tracks. Switching between zero and a positive volume restarts the player once; changing between positive volumes reuses the player.

## Requirements

- DMS 1.6.2 or later
- [`mpvpaper`](https://github.com/GhostNaN/mpvpaper)
- `ffmpeg` for thumbnails and dynamic color extraction

## License

MIT — Original plugin by [tokisak1kurum1](https://github.com/tokisak1kurum1), enhanced by [4all3n](https://github.com/4all3n).

---

## 简体中文

用于 [Dux Shell](https://github.com/duxlabs-dev/dux-shell)（前身 Dank Material Shell）的视频壁纸插件。插件使用 `mpvpaper` 播放视频壁纸，提供完整的设置界面、DankBar 壁纸切换组件、幻灯片/随机播放模式和电池感知省电功能。

> **基于 [tokisak1kurum1/mpvpaper-plugin](https://github.com/tokisak1kurum1/mpvpaper-plugin) 的增强版** — 新增幻灯片、随机播放、电池感知和跳过按钮。

### 功能

#### 原版功能
- 切换视频时复用现有 `mpvpaper` 播放进程，减少黑屏、闪烁和重新启动造成的卡顿
- 使用统一的视频库，可为每个显示器分别选择壁纸，也可让所有显示器使用同一壁纸
- 提供 DankBar 组件，可直接浏览和切换视频壁纸
- 支持 `auto`、`nvdec`、`vaapi`、`vdpau` 硬件解码，并提供画面填充和音量设置
- 锁屏时可选择关闭播放器，或暂停播放并在解锁后从当前位置继续
- 可设置定时重启 `mpvpaper`，默认关闭
- 根据当前视频壁纸生成 DMS 动态配色，切换到动态主题时也会更新配色
- 设置界面支持 English 和简体中文

#### ✨ 新增功能
- **幻灯片模式** — 按设定间隔自动轮换视频库中的视频（30秒至2小时）
- **随机播放模式** — 随机顺序播放，智能历史追踪确保全部轮换后才重复
- **跳过按钮** — 在 DankBar 弹出窗口中手动切换到下一个壁纸
- **电池感知省电** — 使用电池供电时自动暂停视频壁纸，接通电源后恢复
- **增强暂停逻辑** — 电池 + 全屏 + 锁屏综合感知，最大限度节省电量

### 安装

1. 打开 **DMS 设置 → 插件 → 浏览**。
2. 搜索 **Live Wallpaper**（或 **MpvPaper Plugin**）。
3. 安装并启用插件。

请先安装系统依赖。Arch Linux：

```bash
sudo pacman -S ffmpeg
yay -S mpvpaper
```

### 使用

1. 打开插件设置，添加视频文件或整个视频文件夹。
2. 选择显示器并设置对应壁纸；也可以启用"所有显示器使用相同壁纸"。
3. 按需设置硬件解码、画面填充、音量、锁屏行为和高级 MPV 参数。
4. 如需从状态栏快速切换壁纸，可在 DankBar 布局中添加 **Live Wallpaper**。

### 依赖

- DMS 1.6.2 或更高版本
- [`mpvpaper`](https://github.com/GhostNaN/mpvpaper)
- `ffmpeg`，用于生成视频缩略图和动态配色取帧

### 许可证

MIT — 原始插件由 [tokisak1kurum1](https://github.com/tokisak1kurum1) 开发，由 [4all3n](https://github.com/4all3n) 增强。
