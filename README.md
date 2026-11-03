# Dux Live Wallpaper

A modern, high-performance live video wallpaper plugin for [Dux Shell](https://github.com/duxlabs-dev/dux-shell) (formerly Dank Material Shell) on Wayland compositors (Niri, Hyprland, etc.). Powered by [`mpvpaper`](https://github.com/GhostNaN/mpvpaper).

![Live Wallpaper Screenshot](screenshot.png)

> **Fork of [tokisak1kurum1/mpvpaper-plugin](https://github.com/tokisak1kurum1/mpvpaper-plugin)** — redesigned and modernized for Dux Shell 2.0 with a 3D Coverflow carousel, Niri workspace overview background blur synchronization, keyboard navigation, instant battery awareness, folder auto-detection, and session persistence.

---

## ✨ Features

### 🎨 Modern 3D Coverflow Carousel
- **Dux Shell Native Styling**: 16:9 cards with perspective transformation (`±25°`), smooth scaling, and side-peek depth falloff matching Dux Shell DDash.
- **Rounded Corners**: GPU-accelerated rounded corners (`ClippingRectangle`) that strictly clip video thumbnails inside the border.
- **Keyboard Navigation**:
  - `←` / `→` arrow keys to smoothly step through wallpapers.
  - `Enter`, `Return`, or `Space` to apply the centered wallpaper immediately.
  - Mouse wheel and touch drag scrolling supported.
- **Clear Status & Quick Actions**: Active card checkmark badge, hover-to-remove button, and dynamic `"Press Enter or Click to Apply"` badge when browsing.
- **Empty State**: Welcoming placeholder with quick `"Add Video"` and `"Add Folder"` buttons when the library is empty.

### 🖼️ Niri Workspace Overview Background Blur Sync
- Automatically extracts high-resolution frames (`preview.jpg`) from your active video and synchronizes them directly with Dux Shell's `SessionData.setWallpaper()`.
- When entering the Niri workspace overview, Dux Shell's `WallpaperBackground` blurs the matching video frame instead of falling back to old static images.
- Automatically preserves your original static wallpaper so turning off live wallpaper restores your desktop cleanly with zero black screens or glitches.

### 🎛️ Control Center & DankBar Integration
- **Control Center Tile**: Displays live status pill (`Playing`, `Paused`, `Disabled`) with a 1-click toggle and detailed configuration view.
- **Detail View**: Master Play/Pause and Power buttons in the header, with streamlined settings below (zero duplicate buttons).
- **DankBar Pill & Popout**: Optional top-bar pill with a quick popout carousel.

### 🔋 Intelligent Power & Battery Saving
- **Instant Battery Detection**: Hooked directly into Dux Shell's native `BatteryService.isPluggedIn` UPower D-Bus events for instant (<10ms) reaction when unplugging the charger.
- **Kernel Sysfs Fallback**: Monitors `/sys/class/power_supply/AC/online` for robust detection even without UPower.
- **Fullscreen Window Awareness**: Pauses playback when an application is fullscreen or covering the monitor on Niri.
- **Lock-Screen Behavior**: Configurable action on lock (pause playback or completely stop the player to save resources).

### 🔄 Multi-Monitor & Persistence
- **Persistent Reboot State**: Multi-layer fallback chain (`monitorVideos` → `allMonitorsVideo` → `lastActiveVideo` → library) guarantees wallpapers persist across reboots, logouts, and display config changes.
- **Multi-Monitor Modes**: Run independent video wallpapers on each display or sync the same wallpaper across all screens.
- **Seamless Boot Frame**: Dux Shell renders the cached video preview frame before `mpvpaper` spawns, eliminating startup black flashes.

### 📂 Folder Auto-Detection & Library Management
- **Directory Scanning**: Add entire folders containing `.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, or `.wmv` files.
- **Auto-Detection**: Background scanner checks monitored folders periodically and imports newly added videos automatically.
- **Async Thumbnail Pregeneration**: Extracts thumbnails and high-res frames in the background without freezing the UI.

### 🎞️ Slideshow & Hardware Acceleration
- **Auto-Cycle / Slideshow**: Automatically rotate through videos at configurable intervals (30 seconds to 2 hours).
- **Smart Shuffle**: Random rotation with history tracking to prevent repeats until the full library cycles.
- **GPU Decoding**: Supports `auto`, `vaapi`, `nvdec`, and `vdpau` hardware acceleration.
- **Display Modes**: Pan-and-scan modes (`Fill Screen (Crop)`, `Fit Screen (Letterbox)`, `Stretch Fill`).
- **Volume & Custom MPV Options**: Audio volume slider and arbitrary MPV command-line arguments.
- **Material You Dynamic Theming**: Extracts color palettes from active video wallpapers for Dux Shell's dynamic theme engine.

---

## ⌨️ Keyboard Shortcuts (Inside Carousel)

| Key | Action |
| :--- | :--- |
| `←` (Left Arrow) | Move to previous wallpaper in carousel |
| `→` (Right Arrow) | Move to next wallpaper in carousel |
| `Enter` / `Return` | Apply and play the centered wallpaper |
| `Space` | Apply and play the centered wallpaper |
| `Mouse Wheel` | Scroll through wallpapers |
| `Click on Card` | Select and apply wallpaper |

---

## 📦 Requirements

- **Dux Shell** (formerly Dank Material Shell) 1.6.2 or 2.0+
- **`mpvpaper`** (Wayland video wallpaper utility)
- **`ffmpeg`** (for thumbnail generation, preview extraction, and color palette sampling)
- **`zenity`** or **`kdialog`** (for system file and folder picker dialogs)

### Package Installation

#### Arch Linux / EndeavourOS / Manjaro:
```bash
sudo pacman -S ffmpeg zenity
yay -S mpvpaper
```

#### Fedora:
```bash
sudo dnf install ffmpeg zenity
# Install mpvpaper via copr or source:
sudo dnf copr enable erikreider/SwayNotificationCenter
sudo dnf install mpvpaper
```

#### Ubuntu / Debian:
```bash
sudo apt install ffmpeg zenity mpv
# Build mpvpaper from source or via PPA
```

---

## 🚀 Installation

### Option 1: Via DMS Plugins Directory
1. Open **DMS Settings → Plugins → Browse**.
2. Search for **Live Wallpaper** (or **mpvpaper**).
3. Click **Install** and **Enable**.

### Option 2: Manual Installation (Git)
Clone or symlink this repository into your Dux Shell plugins directory:

```bash
mkdir -p ~/.config/dms/plugins
git clone https://github.com/4all3n/dux-live-wallpaper.git ~/.config/dms/plugins/mpvpaper
```

Restart Dux Shell:
```bash
dms restart
```

---

## 🛠️ Usage

1. Open **Dux Shell Settings → Plugins → MpvPaper** or open **Control Center → Video Wallpaper**.
2. Click **Add Video** or **Add Folder** to import your wallpapers.
3. Use the arrow keys or click a card in the **Coverflow Carousel** to set your wallpaper.
4. Customize your playback options:
   - **Pause on battery power**: Automatically freezes playback when unplugged to extend laptop battery life.
   - **Sync static wallpaper**: Keeps Dux Shell's static wallpaper in sync with your active video so the Niri workspace overview blur matches.
   - **Auto-cycle wallpapers**: Enables automatic wallpaper rotation with interval and shuffle options.

---

## 📄 License

MIT License — Original plugin created by [tokisak1kurum1](https://github.com/tokisak1kurum1), modernized and enhanced by [4all3n](https://github.com/4all3n).
