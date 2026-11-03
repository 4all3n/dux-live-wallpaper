import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Plugins
import qs.Modals.FileBrowser

PluginComponent {
    id: root
    pluginId: "mpvpaper"

    Component.onCompleted: {
        MpvPaperI18n.language = pluginData.language || "en"
    }

    property var monitors: Quickshell.screens.map(screen => screen.name)
    property string selectedMonitor: {
        if (parentScreen && parentScreen.name) return parentScreen.name
        return monitors.length > 0 ? monitors[0] : ""
    }

    property int refreshTrigger: 0
    property var fileBrowserParentPopout: null
    property bool sameOnAllMonitors: pluginData.sameOnAllMonitors || false

    readonly property bool isLiveActive: (pluginData.liveWallpaperActive === undefined || pluginData.liveWallpaperActive === null)
        ? true
        : !!pluginData.liveWallpaperActive
    readonly property bool isPaused: !!pluginData.isPaused

    // ── Control Center Integration ──
    ccWidgetIcon: "movie"
    ccWidgetPrimaryText: MpvPaperI18n.tr("Live Wallpaper", "mpvpaper")
    ccWidgetSecondaryText: {
        root.refreshTrigger
        if (!root.isLiveActive) return MpvPaperI18n.tr("Live wallpaper disabled", "mpvpaper")
        const current = root.getCurrentVideoPath()
        if (!current) return MpvPaperI18n.tr("No video selected", "mpvpaper")
        const filename = current.split("/").pop()
        if (root.isPaused) return filename + " (" + MpvPaperI18n.tr("Paused", "mpvpaper") + ")"
        if (pluginData && pluginData.slideshowEnabled) return filename + " (Auto)"
        return filename
    }
    ccWidgetIsActive: root.isLiveActive && root.getCurrentVideoPath() !== ""
    ccWidgetIsToggle: true
    ccDetailHeight: 520

    onCcWidgetToggled: {
        if (!root.isLiveActive) {
            root.toggleLiveWallpaperActive()
        } else {
            root.cycleNextVideo()
        }
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === "mpvpaper") root.refreshTrigger++
        }
    }

    onPluginDataChanged: {
        MpvPaperI18n.language = pluginData.language || "en"
        refreshTrigger++
    }

    function getPlaylist() {
        if (!pluginService) return []
        const library = pluginService.loadPluginData("mpvpaper", "videoLibrary", [])
        return Array.isArray(library) ? library : []
    }

    function getCurrentVideoPath() {
        if (!pluginService) return ""
        const monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})

        if (sameOnAllMonitors) {
            return pluginService.loadPluginData("mpvpaper", "allMonitorsVideo", "")
        }

        return monitorVideos[selectedMonitor] || ""
    }

    function setCurrentVideo(videoPath) {
        if (!pluginService || !videoPath || getPlaylist().indexOf(videoPath) === -1) return

        if (!root.isLiveActive) {
            pluginService.savePluginData("mpvpaper", "liveWallpaperActive", true)
        }

        if (sameOnAllMonitors) {
            pluginService.savePluginData("mpvpaper", "allMonitorsVideo", videoPath)
        } else {
            const monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})
            if (selectedMonitor) monitorVideos[selectedMonitor] = videoPath
            pluginService.savePluginData("mpvpaper", "monitorVideos", monitorVideos)
        }

        syncStaticPreview(videoPath)
        root.refreshTrigger++
    }

    function cycleNextVideo() {
        const playlist = root.getPlaylist()
        if (playlist.length < 2) return
        const currentPath = root.getCurrentVideoPath()
        let currentIndex = playlist.indexOf(currentPath)
        if (currentIndex < 0) currentIndex = -1
        const shuffleEnabled = (pluginData && pluginData.slideshowShuffle) || false
        let nextVideo
        if (shuffleEnabled) {
            let idx = Math.floor(Math.random() * playlist.length)
            if (playlist[idx] === currentPath && playlist.length > 1)
                idx = (idx + 1) % playlist.length
            nextVideo = playlist[idx]
        } else {
            nextVideo = playlist[(currentIndex + 1) % playlist.length]
        }
        if (nextVideo) root.setCurrentVideo(nextVideo)
    }

    function togglePausePlayback() {
        if (!pluginService) return
        const next = !root.isPaused
        pluginService.savePluginData("mpvpaper", "isPaused", next)
        root.refreshTrigger++
    }

    function toggleLiveWallpaperActive() {
        if (!pluginService) return
        const next = !root.isLiveActive
        pluginService.savePluginData("mpvpaper", "liveWallpaperActive", next)
        if (!next) {
            const orig = (pluginData && pluginData.originalStaticWallpaper) ? pluginData.originalStaticWallpaper : ""
            if (orig && typeof SessionData !== "undefined") {
                if (SessionData.setWallpaper) SessionData.setWallpaper(orig)
                if (SessionData.setMonitorWallpaper) {
                    for (const s of Quickshell.screens) {
                        SessionData.setMonitorWallpaper(s.name, orig)
                    }
                }
            }
        } else {
            root.syncStaticPreview(root.getCurrentVideoPath())
        }
        root.refreshTrigger++
    }

    function saveSetting(key, value) {
        if (!pluginService) return
        pluginService.savePluginData("mpvpaper", key, value)
        root.refreshTrigger++
    }

    function getVideoSettings() {
        const videoPath = getCurrentVideoPath()
        if (!videoPath || !pluginService) return {}
        const allSettings = pluginService.loadPluginData("mpvpaper", "videoSettings", {})
        return allSettings[videoPath] || {}
    }

    function getVideoSetting(key, defaultValue) {
        const settings = getVideoSettings()
        return settings[key] !== undefined ? settings[key] : defaultValue
    }

    function saveVideoSetting(key, value) {
        const videoPath = getCurrentVideoPath()
        if (!videoPath || !pluginService) return

        var allSettings = pluginService.loadPluginData("mpvpaper", "videoSettings", {})
        if (!allSettings[videoPath]) allSettings[videoPath] = {}
        allSettings[videoPath][key] = value
        pluginService.savePluginData("mpvpaper", "videoSettings", allSettings)
        root.refreshTrigger++
    }

    function getWallpaperFolders() {
        if (!pluginService) return []
        const folders = pluginService.loadPluginData("mpvpaper", "wallpaperFolders", null)
        if (Array.isArray(folders) && folders.length > 0) return folders
        const library = getPlaylist()
        const inferred = []
        for (const video of library) {
            const dir = video.substring(0, video.lastIndexOf("/"))
            if (dir && inferred.indexOf(dir) === -1) inferred.push(dir)
        }
        return inferred
    }

    function addToPlaylist(videoPath) {
        if (!pluginService || !videoPath) return false
        const trimmedPath = videoPath.trim()
        if (!trimmedPath) return false

        const library = getPlaylist().slice()
        if (library.indexOf(trimmedPath) !== -1) return false

        library.push(trimmedPath)
        pluginService.savePluginData("mpvpaper", "videoLibrary", library)

        const dir = trimmedPath.substring(0, trimmedPath.lastIndexOf("/"))
        if (dir) {
            const folders = getWallpaperFolders().slice()
            if (folders.indexOf(dir) === -1) {
                folders.push(dir)
                pluginService.savePluginData("mpvpaper", "wallpaperFolders", folders)
            }
        }

        refreshTrigger++
        return true
    }

    function removeFromPlaylist(index) {
        if (!pluginService) return
        var library = getPlaylist().slice()
        if (index < 0 || index >= library.length) return

        const videoPath = library[index]
        library.splice(index, 1)
        pluginService.savePluginData("mpvpaper", "videoLibrary", library)

        var monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})
        let assignmentsChanged = false
        for (const monitor in monitorVideos) {
            if (monitorVideos[monitor] === videoPath) {
                delete monitorVideos[monitor]
                assignmentsChanged = true
            }
        }
        if (assignmentsChanged)
            pluginService.savePluginData("mpvpaper", "monitorVideos", monitorVideos)

        if (pluginService.loadPluginData("mpvpaper", "allMonitorsVideo", "") === videoPath)
            pluginService.savePluginData("mpvpaper", "allMonitorsVideo", "")

        refreshTrigger++
    }

    function getThumbnailUrl(videoPath) {
        if (!videoPath) return ""
        let h = 0
        for (let i = 0; i < videoPath.length; i++) {
            h = ((h << 5) - h) + videoPath.charCodeAt(i)
            h = h & h
        }
        const fileName = Math.abs(h) + "_thumb.jpg"
        const located = StandardPaths.locate(
            StandardPaths.GenericCacheLocation,
            "DankMaterialShell/mpvpaper_thumbnails/" + fileName,
            StandardPaths.LocateFile
        )
        if (located.toString() !== "") {
            const p = located.toString()
            return p.startsWith("file://") ? p : "file://" + p
        }
        return ""
    }

    function syncStaticPreview(videoPath) {
        if (!videoPath || typeof SessionData === "undefined") return

        // Preserve original static wallpaper once so user can restore when disabling live wallpaper
        if (SessionData.wallpaperPath && !SessionData.wallpaperPath.includes("mpvpaper_thumbnails")) {
            if (pluginService && (!pluginData || !pluginData.originalStaticWallpaper)) {
                pluginService.savePluginData("mpvpaper", "originalStaticWallpaper", SessionData.wallpaperPath)
            }
        }

        let h = 0
        for (let i = 0; i < videoPath.length; i++) {
            h = ((h << 5) - h) + videoPath.charCodeAt(i)
            h = h & h
        }
        const hashStr = Math.abs(h).toString()
        const cacheDir = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace("file://", "") + "/DankMaterialShell/mpvpaper_thumbnails"
        const prevPath = cacheDir + "/" + hashStr + "_preview.jpg"

        // If preview already exists in cache, apply immediately with 0 latency
        const cached = StandardPaths.locate(
            StandardPaths.GenericCacheLocation,
            "DankMaterialShell/mpvpaper_thumbnails/" + hashStr + "_preview.jpg",
            StandardPaths.LocateFile
        )
        if (cached.toString() !== "") {
            if (SessionData.setWallpaper) SessionData.setWallpaper(prevPath)
            if (SessionData.setMonitorWallpaper) {
                const screens = root.sameOnAllMonitors ? Quickshell.screens.map(s => s.name) : [root.selectedMonitor]
                for (const s of screens) {
                    if (s) SessionData.setMonitorWallpaper(s, prevPath)
                }
            }
            return
        }

        if (staticPreviewProcess.running) staticPreviewProcess.running = false
        staticPreviewProcess.previewPath = prevPath
        staticPreviewProcess.videoPath = videoPath
        staticPreviewProcess.command = [
            "bash", "-c",
            `if [ -f "$1" ]; then exit 0; fi; mkdir -p "$(dirname "$1")" && ffmpeg -loglevel error -i "$2" -ss 00:00:01 -vframes 1 -q:v 2 "$1" -y`,
            "mpvpaper-widget-static", prevPath, videoPath
        ]
        staticPreviewProcess.running = true
    }

    Process {
        id: staticPreviewProcess
        property string previewPath: ""
        property string videoPath: ""

        onExited: code => {
            if (code === 0 && previewPath && typeof SessionData !== "undefined") {
                if (SessionData.setWallpaper) SessionData.setWallpaper(previewPath)
                if (SessionData.setMonitorWallpaper) {
                    const screens = root.sameOnAllMonitors ? Quickshell.screens.map(s => s.name) : [root.selectedMonitor]
                    for (const s of screens) {
                        if (s) SessionData.setMonitorWallpaper(s, previewPath)
                    }
                }
            }
        }
    }

    function openSystemFilePicker() {
        systemFilePickerProcess.selectedFile = ""
        systemFilePickerProcess.running = true
    }

    Process {
        id: systemFilePickerProcess
        property string selectedFile: ""
        command: ["bash", "-c", `
            if command -v zenity >/dev/null 2>&1; then
                zenity --file-selection --multiple --separator=$'\n' --title="${MpvPaperI18n.tr("Select Video Files", "mpvpaper")}" --file-filter="${MpvPaperI18n.tr("Video Files", "mpvpaper")} | *.mp4 *.mkv *.webm *.avi *.mov *.flv *.wmv *.m4v" --file-filter="${MpvPaperI18n.tr("All Files", "mpvpaper")} | *"
            elif command -v kdialog >/dev/null 2>&1; then
                kdialog --getopenfilename ~ "*.mp4 *.mkv *.webm *.avi *.mov *.flv *.wmv *.m4v|${MpvPaperI18n.tr("Video Files", "mpvpaper")}" --multiple --separate-output
            else
                echo "ERROR: No file picker available"
                exit 1
            fi
        `]
        stdout: SplitParser { onRead: (data) => { systemFilePickerProcess.selectedFile += data + "\n" } }
        onExited: (code) => {
            const trimmed = selectedFile.trim()
            if (code === 0 && trimmed !== "") {
                const files = trimmed.split('\n').map(f => f.trim()).filter(f => f !== "")
                files.forEach(f => addToPlaylist(f))
            } else if (trimmed.includes("ERROR")) {
                videoFileBrowser.open()
            }
            selectedFile = ""
        }
    }

    function openSystemDirectoryPicker() {
        systemDirectoryPickerProcess.selectedDir = ""
        systemDirectoryPickerProcess.running = true
    }

    Process {
        id: systemDirectoryPickerProcess
        property string selectedDir: ""
        command: ["bash", "-c", `
            if command -v zenity >/dev/null 2>&1; then
                zenity --file-selection --directory --title="${MpvPaperI18n.tr("Select Video Folder", "mpvpaper")}"
            elif command -v kdialog >/dev/null 2>&1; then
                kdialog --getexistingdirectory ~
            else
                echo "ERROR: No file picker available"
                exit 1
            fi
        `]
        stdout: SplitParser { onRead: (data) => { systemDirectoryPickerProcess.selectedDir += data } }
        onExited: (code) => {
            const dir = selectedDir.trim()
            if (code === 0 && dir !== "") {
                const folders = getWallpaperFolders().slice()
                if (folders.indexOf(dir) === -1) {
                    folders.push(dir)
                    pluginService.savePluginData("mpvpaper", "wallpaperFolders", folders)
                }
                rescanMonitoredFolders(true)
            }
            selectedDir = ""
        }
    }

    function rescanMonitoredFolders(showToast) {
        if (folderRescanProcess.running) return
        const folders = getWallpaperFolders()
        if (folders.length === 0) {
            if (showToast && typeof ToastService !== "undefined") {
                ToastService.showWarning(
                    MpvPaperI18n.tr("No Videos Found", "mpvpaper"),
                    MpvPaperI18n.tr("No supported video files found in selected folder", "mpvpaper")
                )
            }
            return
        }

        folderRescanProcess.notifyUser = !!showToast
        folderRescanProcess.scanOutput = ""
        const folderArgs = folders.map(f => `"${f}"`).join(" ")
        folderRescanProcess.command = [
            "bash", "-c",
            `for d in ${folderArgs}; do [ -d "$d" ] && find "$d" -maxdepth 2 -type f -regextype posix-extended -iregex '.*\\.(mp4|mkv|webm|avi|mov|flv|wmv|m4v)'; done`
        ]
        folderRescanProcess.running = true
    }

    Process {
        id: folderRescanProcess
        property bool notifyUser: false
        property string scanOutput: ""
        stdout: SplitParser { onRead: (data) => { folderRescanProcess.scanOutput += data + "\n" } }
        onExited: (code) => {
            if (code === 0 && scanOutput.trim() !== "") {
                const files = scanOutput.trim().split("\n").map(f => f.trim()).filter(f => f !== "")
                if (files.length > 0 && pluginService) {
                    const currentLibrary = getPlaylist().slice()
                    let addedCount = 0
                    for (const f of files) {
                        if (currentLibrary.indexOf(f) === -1) {
                            currentLibrary.push(f)
                            addedCount++
                        }
                    }
                    if (addedCount > 0) {
                        pluginService.savePluginData("mpvpaper", "videoLibrary", currentLibrary)
                    }
                    if (notifyUser && typeof ToastService !== "undefined") {
                        ToastService.showInfo(
                            MpvPaperI18n.tr("Rescan complete", "mpvpaper"),
                            MpvPaperI18n.tr("Found %1 wallpapers (%2 new)", "mpvpaper").arg(currentLibrary.length).arg(addedCount)
                        )
                    }
                    root.refreshTrigger++
                }
            } else if (notifyUser && typeof ToastService !== "undefined") {
                ToastService.showInfo(
                    MpvPaperI18n.tr("Rescan complete", "mpvpaper"),
                    MpvPaperI18n.tr("Found %1 wallpapers (%2 new)", "mpvpaper").arg(root.getPlaylist().length).arg(0)
                )
            }
            scanOutput = ""
            notifyUser = false
        }
    }

    FileBrowserSurfaceModal {
        id: videoFileBrowser
        parentPopout: root.fileBrowserParentPopout
        browserTitle: MpvPaperI18n.tr("Select Video Files", "mpvpaper")
        browserIcon: "movie"
        browserType: "mpvpaper-video"
        showHiddenFiles: true
        fileExtensions: ["*.mp4", "*.mkv", "*.webm", "*.avi", "*.mov", "*.flv", "*.wmv", "*.m4v"]

        onFileSelected: (videoPath) => {
            root.addToPlaylist(videoPath)
            close()
        }
    }

    Timer {
        id: volumeDebounceTimer
        interval: 350
        repeat: false
        property int pendingVal: 0
        onTriggered: root.saveVideoSetting("volume", pendingVal)
    }

    horizontalBarPill: Component { DIcon { name: "movie"; size: root.iconSize; color: Theme.primary } }
    verticalBarPill: Component { DIcon { name: "movie"; size: root.iconSize; color: Theme.primary } }

    // ── Reusable Coverflow Carousel Component ──
    component CoverflowGallery: Item {
        id: galleryRoot
        property real preferredAspect: 9 / 16
        property real itemRatio: 0.60
        readonly property real itemWidth: Math.round(width * itemRatio)
        readonly property real itemHeight: Math.round(itemWidth * preferredAspect)
        readonly property real pitch: itemWidth + carouselList.spacing

        property var playlist: root.getPlaylist()
        property int currentIndex: {
            root.refreshTrigger
            const cur = root.getCurrentVideoPath()
            const idx = playlist.indexOf(cur)
            return idx >= 0 ? idx : 0
        }

        onCurrentIndexChanged: {
            if (carouselList.currentIndex !== currentIndex)
                carouselList.currentIndex = currentIndex
        }

        implicitHeight: itemHeight + 110

        Column {
            anchors.fill: parent
            spacing: Theme.spacingS

            // ── 3D Carousel Stage ──
            Item {
                width: parent.width
                height: galleryRoot.itemHeight + 10
                clip: true

                ListView {
                    id: carouselList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    model: galleryRoot.playlist
                    spacing: -galleryRoot.itemWidth * 0.32
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width - galleryRoot.itemWidth) / 2
                    preferredHighlightEnd: preferredHighlightBegin + galleryRoot.itemWidth
                    highlightMoveDuration: 250
                    snapMode: ListView.SnapToItem
                    clip: false

                    delegate: Item {
                        id: cardSlide
                        required property int index
                        required property string modelData

                        readonly property real offset: (x - carouselList.contentX + width / 2 - carouselList.width / 2) / Math.max(1, galleryRoot.pitch)
                        readonly property real distance: Math.min(1, Math.abs(offset))
                        readonly property bool isSelected: root.getCurrentVideoPath() === modelData

                        readonly property string hashStr: {
                            let h = 0
                            for (let i = 0; i < modelData.length; i++) {
                                h = ((h << 5) - h) + modelData.charCodeAt(i)
                                h = h & h
                            }
                            return Math.abs(h).toString()
                        }
                        readonly property string thumbDir: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace("file://", "") + "/DankMaterialShell/mpvpaper_thumbnails"
                        readonly property string expectedThumbPath: thumbDir + "/" + hashStr + "_thumb.jpg"

                        width: galleryRoot.itemWidth
                        height: galleryRoot.itemHeight
                        y: Math.round((carouselList.height - height) / 2)
                        scale: 1.0 - 0.20 * distance
                        opacity: 1.0 - 0.40 * distance
                        z: -Math.abs(offset)

                        transform: Rotation {
                            origin.x: cardSlide.width / 2
                            origin.y: cardSlide.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: -Math.max(-1, Math.min(1, cardSlide.offset)) * 25
                        }

                        Rectangle {
                            id: cardFrame
                            anchors.fill: parent
                            radius: Theme.cornerRadiusL
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                            border.width: isSelected ? 3 : 1
                            border.color: isSelected ? Theme.primary : Theme.outlineHeavy
                            clip: true

                            Image {
                                id: cardImg
                                anchors.fill: parent
                                anchors.margins: 1
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                source: {
                                    const loc = StandardPaths.locate(
                                        StandardPaths.GenericCacheLocation,
                                        "DankMaterialShell/mpvpaper_thumbnails/" + cardSlide.hashStr + "_thumb.jpg",
                                        StandardPaths.LocateFile
                                    )
                                    if (loc.toString() !== "") {
                                        const s = loc.toString()
                                        return s.startsWith("file://") ? s : "file://" + s
                                    }
                                    return ""
                                }

                                Component.onCompleted: {
                                    if (source.toString() === "") cardThumbProcess.running = true
                                }

                                onStatusChanged: {
                                    if (status === Image.Error || (status === Image.Null && source.toString() === ""))
                                        cardThumbProcess.running = true
                                }
                            }

                            Process {
                                id: cardThumbProcess
                                command: [
                                    "bash", "-c",
                                    'mkdir -p -- "$1" && ffmpeg -loglevel error -i "$2" -ss 00:00:01 -vframes 1 -vf "scale=480:270:force_original_aspect_ratio=increase,crop=480:270" -q:v 3 "$3" -y',
                                    "mpvpaper-carousel-thumb", cardSlide.thumbDir, cardSlide.modelData, cardSlide.expectedThumbPath
                                ]
                                onExited: code => {
                                    if (code === 0) cardImg.source = "file://" + cardSlide.expectedThumbPath
                                }
                            }

                            DIcon {
                                anchors.centerIn: parent
                                name: "movie"
                                size: 36
                                color: Theme.primary
                                visible: cardImg.status !== Image.Ready
                            }

                            // Active checkmark badge
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingS
                                width: 24
                                height: 24
                                radius: 12
                                color: Theme.primary
                                visible: isSelected
                                z: 15

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "check"
                                    size: 16
                                    color: Theme.onPrimary
                                }
                            }

                            // Hover delete button
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingS
                                width: 22
                                height: 22
                                radius: 11
                                color: Theme.error
                                visible: cardMouse.containsMouse
                                z: 20

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 14
                                    color: Theme.onError
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeFromPlaylist(cardSlide.index)
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    carouselList.currentIndex = cardSlide.index
                                    root.setCurrentVideo(cardSlide.modelData)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                            if (delta === 0) return
                            const next = Math.max(0, Math.min(galleryRoot.playlist.length - 1, carouselList.currentIndex - Math.sign(delta)))
                            carouselList.currentIndex = next
                            wheel.accepted = true
                        }
                    }
                }
            }

            // ── Navigation Pager & Quick Controls Strip ──
            Item {
                width: parent.width
                height: 36

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DActionButton {
                        iconName: "chevron_left"
                        iconSize: 18
                        buttonSize: 32
                        enabled: carouselList.currentIndex > 0
                        opacity: enabled ? 0.9 : 0.25
                        onClicked: carouselList.currentIndex = Math.max(0, carouselList.currentIndex - 1)
                    }

                    StyledText {
                        text: (galleryRoot.playlist.length > 0)
                            ? (carouselList.currentIndex + 1) + " / " + galleryRoot.playlist.length
                            : "0 / 0"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        opacity: 0.75
                    }

                    DActionButton {
                        iconName: "chevron_right"
                        iconSize: 18
                        buttonSize: 32
                        enabled: carouselList.currentIndex < galleryRoot.playlist.length - 1
                        opacity: enabled ? 0.9 : 0.25
                        onClicked: carouselList.currentIndex = Math.min(galleryRoot.playlist.length - 1, carouselList.currentIndex + 1)
                    }

                    Rectangle {
                        width: 1
                        height: 20
                        color: Theme.outlineHeavy
                        Layout.leftMargin: Theme.spacingXS
                        Layout.rightMargin: Theme.spacingXS
                    }

                    // Pause / Resume playback
                    DActionButton {
                        iconName: root.isPaused ? "play_arrow" : "pause"
                        iconSize: 18
                        buttonSize: 32
                        tooltipText: root.isPaused ? MpvPaperI18n.tr("Resume Playback", "mpvpaper") : MpvPaperI18n.tr("Pause Playback", "mpvpaper")
                        onClicked: root.togglePausePlayback()
                    }

                    // Enable / Disable (Remove) live wallpaper
                    DActionButton {
                        iconName: root.isLiveActive ? "power_settings_new" : "movie"
                        iconColor: root.isLiveActive ? Theme.primary : Theme.surfaceVariantText
                        iconSize: 18
                        buttonSize: 32
                        tooltipText: root.isLiveActive ? MpvPaperI18n.tr("Disable Live Wallpaper", "mpvpaper") : MpvPaperI18n.tr("Enable Live Wallpaper", "mpvpaper")
                        onClicked: root.toggleLiveWallpaperActive()
                    }

                    // Rescan Wallpapers
                    DActionButton {
                        iconName: "refresh"
                        iconSize: 18
                        buttonSize: 32
                        tooltipText: MpvPaperI18n.tr("Rescan Wallpapers", "mpvpaper")
                        onClicked: root.rescanMonitoredFolders(true)
                    }

                    // Add Video
                    DActionButton {
                        iconName: "add"
                        iconSize: 18
                        buttonSize: 32
                        tooltipText: MpvPaperI18n.tr("Add Video", "mpvpaper")
                        onClicked: root.openSystemFilePicker()
                    }

                    // Add Folder
                    DActionButton {
                        iconName: "folder_open"
                        iconSize: 18
                        buttonSize: 32
                        tooltipText: MpvPaperI18n.tr("Add Folder", "mpvpaper")
                        onClicked: root.openSystemDirectoryPicker()
                    }
                }
            }

            // ── Active Wallpaper Title & Status Card ──
            Rectangle {
                width: parent.width
                height: 48
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                border.width: 1
                border.color: Theme.outlineHeavy

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    width: parent.width - Theme.spacingM * 2

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            root.refreshTrigger
                            const cur = (galleryRoot.playlist.length > 0 && carouselList.currentIndex >= 0 && carouselList.currentIndex < galleryRoot.playlist.length)
                                ? galleryRoot.playlist[carouselList.currentIndex]
                                : root.getCurrentVideoPath()
                            return cur ? cur.split("/").pop() : MpvPaperI18n.tr("No video selected", "mpvpaper")
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            if (!root.isLiveActive) return "• " + MpvPaperI18n.tr("Live wallpaper disabled", "mpvpaper") + " •"
                            if (root.isPaused) return "• " + MpvPaperI18n.tr("Paused", "mpvpaper") + " •"
                            if (pluginData && pluginData.slideshowEnabled) return "• " + MpvPaperI18n.tr("Playing", "mpvpaper") + " (Auto-cycle) •"
                            return "• " + MpvPaperI18n.tr("Playing", "mpvpaper") + " •"
                        }
                        font.pixelSize: Theme.fontSizeSmall * 0.85
                        color: !root.isLiveActive ? Theme.error : (root.isPaused ? Theme.surfaceVariantText : Theme.primary)
                    }
                }
            }
        }
    }

    // ── DankBar Popout Body ──
    Component {
        id: popoutBody

        PopoutComponent {
            id: popout
            parentPopout: mpvPaperPopout
            closePopout: function() { mpvPaperPopout.close() }
            Component.onCompleted: root.fileBrowserParentPopout = mpvPaperPopout
            Component.onDestruction: {
                if (root.fileBrowserParentPopout === mpvPaperPopout)
                    root.fileBrowserParentPopout = null
            }
            headerText: ""
            detailsText: ""
            showCloseButton: false

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight

                Column {
                    anchors.fill: parent
                    anchors.margins: root.popoutPadding
                    spacing: Theme.spacingM

                    // Popout Header
                    Item {
                        width: parent.width
                        height: 32

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            DIcon {
                                name: "movie"
                                size: 20
                                color: Theme.primary
                            }

                            StyledText {
                                text: MpvPaperI18n.tr("Video Wallpaper", "mpvpaper")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: MpvPaperI18n.tr("%1 wallpapers", "mpvpaper").arg(root.getPlaylist().length)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.6
                                verticalAlignment: Text.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            DActionButton {
                                iconName: "close"
                                iconSize: 18
                                buttonSize: 32
                                onClicked: mpvPaperPopout.close()
                            }
                        }
                    }

                    // Large Coverflow Gallery
                    CoverflowGallery {
                        width: parent.width
                        itemRatio: 0.65
                    }
                }
            }
        }
    }

    // ── Control Center Detail Content ──
    ccDetailContent: Component {
        Item {
            id: ccDetailRoot
            implicitHeight: root.ccDetailHeight

            DFlickable {
                anchors.fill: parent
                contentHeight: detailColumn.implicitHeight + Theme.spacingM * 2
                clip: true

                Column {
                    id: detailColumn
                    width: parent.width
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    // ── Header Actions Strip ──
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        DIcon {
                            name: "movie"
                            size: 22
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: MpvPaperI18n.tr("Live Wallpaper", "mpvpaper")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const count = root.getPlaylist().length
                                    return MpvPaperI18n.tr("%1 wallpapers", "mpvpaper").arg(count)
                                }
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }

                        DActionButton {
                            iconName: root.isPaused ? "play_arrow" : "pause"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: root.isPaused ? MpvPaperI18n.tr("Resume Playback", "mpvpaper") : MpvPaperI18n.tr("Pause Playback", "mpvpaper")
                            onClicked: root.togglePausePlayback()
                        }

                        DActionButton {
                            iconName: root.isLiveActive ? "power_settings_new" : "movie"
                            iconColor: root.isLiveActive ? Theme.primary : Theme.surfaceVariantText
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: root.isLiveActive ? MpvPaperI18n.tr("Disable Live Wallpaper", "mpvpaper") : MpvPaperI18n.tr("Enable Live Wallpaper", "mpvpaper")
                            onClicked: root.toggleLiveWallpaperActive()
                        }

                        DActionButton {
                            iconName: "skip_next"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Next wallpaper", "mpvpaper")
                            onClicked: root.cycleNextVideo()
                        }

                        DActionButton {
                            iconName: "refresh"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Rescan Wallpapers", "mpvpaper")
                            onClicked: root.rescanMonitoredFolders(true)
                        }
                    }

                    // ── Coverflow Carousel ──
                    CoverflowGallery {
                        width: parent.width
                        itemRatio: 0.65
                    }

                    // ── Multi-Monitor Selection ──
                    CcGroup {
                        visible: root.monitors.length > 1

                        CcToggleRow {
                            iconName: "linked_services"
                            text: MpvPaperI18n.tr("Same on all monitors", "mpvpaper")
                            checked: root.sameOnAllMonitors
                            onToggled: isChecked => {
                                if (isChecked && !pluginService.loadPluginData("mpvpaper", "allMonitorsVideo", "")) {
                                    const monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})
                                    const src = monitorVideos[root.selectedMonitor] || ""
                                    if (src) pluginService.savePluginData("mpvpaper", "allMonitorsVideo", src)
                                }
                                root.sameOnAllMonitors = isChecked
                                pluginService.savePluginData("mpvpaper", "sameOnAllMonitors", isChecked)
                                root.refreshTrigger++
                            }
                        }

                        CcListRow {
                            visible: !root.sameOnAllMonitors
                            iconName: "desktop_windows"
                            title: MpvPaperI18n.tr("Monitor", "mpvpaper")

                            DDropdown {
                                anchors.verticalCenter: parent.verticalCenter
                                compactMode: true
                                dropdownWidth: 140
                                options: root.monitors
                                currentValue: root.selectedMonitor || MpvPaperI18n.tr("No Monitors", "mpvpaper")
                                onValueChanged: val => root.selectedMonitor = val
                            }
                        }
                    }

                    // ── Slideshow & Rotation ──
                    CcGroup {
                        CcToggleRow {
                            iconName: "autorenew"
                            text: MpvPaperI18n.tr("Auto-cycle wallpapers", "mpvpaper")
                            description: MpvPaperI18n.tr("Automatically rotate through videos in your library at a set interval", "mpvpaper")
                            checked: !!(pluginData && pluginData.slideshowEnabled)
                            onToggled: isChecked => root.saveSetting("slideshowEnabled", isChecked)
                        }

                        CcListRow {
                            visible: !!(pluginData && pluginData.slideshowEnabled)
                            iconName: "timer"
                            title: MpvPaperI18n.tr("Slideshow Interval", "mpvpaper")

                            DDropdown {
                                anchors.verticalCenter: parent.verticalCenter
                                compactMode: true
                                dropdownWidth: 140
                                options: [
                                    MpvPaperI18n.tr("30 Seconds", "mpvpaper"),
                                    MpvPaperI18n.tr("1 Minute", "mpvpaper"),
                                    MpvPaperI18n.tr("5 Minutes", "mpvpaper"),
                                    MpvPaperI18n.tr("10 Minutes", "mpvpaper"),
                                    MpvPaperI18n.tr("30 Minutes", "mpvpaper"),
                                    MpvPaperI18n.tr("1 Hour", "mpvpaper"),
                                    MpvPaperI18n.tr("2 Hours", "mpvpaper")
                                ]
                                currentValue: {
                                    const interval = (pluginData && pluginData.slideshowInterval) ? Number(pluginData.slideshowInterval) : 300
                                    if (interval === 30) return MpvPaperI18n.tr("30 Seconds", "mpvpaper")
                                    if (interval === 60) return MpvPaperI18n.tr("1 Minute", "mpvpaper")
                                    if (interval === 300) return MpvPaperI18n.tr("5 Minutes", "mpvpaper")
                                    if (interval === 600) return MpvPaperI18n.tr("10 Minutes", "mpvpaper")
                                    if (interval === 1800) return MpvPaperI18n.tr("30 Minutes", "mpvpaper")
                                    if (interval === 3600) return MpvPaperI18n.tr("1 Hour", "mpvpaper")
                                    if (interval === 7200) return MpvPaperI18n.tr("2 Hours", "mpvpaper")
                                    return MpvPaperI18n.tr("5 Minutes", "mpvpaper")
                                }
                                onValueChanged: val => {
                                    let interval = 300
                                    if (val === MpvPaperI18n.tr("30 Seconds", "mpvpaper")) interval = 30
                                    else if (val === MpvPaperI18n.tr("1 Minute", "mpvpaper")) interval = 60
                                    else if (val === MpvPaperI18n.tr("5 Minutes", "mpvpaper")) interval = 300
                                    else if (val === MpvPaperI18n.tr("10 Minutes", "mpvpaper")) interval = 600
                                    else if (val === MpvPaperI18n.tr("30 Minutes", "mpvpaper")) interval = 1800
                                    else if (val === MpvPaperI18n.tr("1 Hour", "mpvpaper")) interval = 3600
                                    else if (val === MpvPaperI18n.tr("2 Hours", "mpvpaper")) interval = 7200
                                    root.saveSetting("slideshowInterval", interval)
                                }
                            }
                        }

                        CcToggleRow {
                            visible: !!(pluginData && pluginData.slideshowEnabled)
                            iconName: "shuffle"
                            text: MpvPaperI18n.tr("Shuffle order", "mpvpaper")
                            checked: !!(pluginData && pluginData.slideshowShuffle)
                            onToggled: isChecked => root.saveSetting("slideshowShuffle", isChecked)
                        }
                    }

                    // ── Power & Battery Playback ──
                    CcGroup {
                        CcToggleRow {
                            iconName: "movie"
                            text: MpvPaperI18n.tr("Enable Live Wallpaper", "mpvpaper")
                            description: MpvPaperI18n.tr("Toggle live video wallpaper on desktop", "mpvpaper")
                            checked: root.isLiveActive
                            onToggled: isChecked => {
                                if (isChecked !== root.isLiveActive) root.toggleLiveWallpaperActive()
                            }
                        }

                        CcToggleRow {
                            visible: root.isLiveActive
                            iconName: "pause"
                            text: MpvPaperI18n.tr("Pause Playback", "mpvpaper")
                            description: MpvPaperI18n.tr("Freeze video wallpaper on current frame", "mpvpaper")
                            checked: root.isPaused
                            onToggled: isChecked => {
                                if (isChecked !== root.isPaused) root.togglePausePlayback()
                            }
                        }

                        CcToggleRow {
                            iconName: "battery_saver"
                            text: MpvPaperI18n.tr("Pause on battery power", "mpvpaper")
                            description: MpvPaperI18n.tr("Automatically pause video wallpaper when unplugged to save battery life", "mpvpaper")
                            checked: !!(pluginData && pluginData.pauseOnBattery)
                            onToggled: isChecked => root.saveSetting("pauseOnBattery", isChecked)
                        }

                        CcToggleRow {
                            iconName: "fullscreen_exit"
                            text: MpvPaperI18n.tr("Pause on Fullscreen", "mpvpaper")
                            checked: (pluginData && pluginData.pauseOnFullscreen !== undefined) ? !!pluginData.pauseOnFullscreen : true
                            onToggled: isChecked => root.saveSetting("pauseOnFullscreen", isChecked)
                        }

                        CcListRow {
                            iconName: "lock"
                            title: MpvPaperI18n.tr("Lock Screen Behavior", "mpvpaper")

                            DDropdown {
                                anchors.verticalCenter: parent.verticalCenter
                                compactMode: true
                                dropdownWidth: 150
                                options: [
                                    MpvPaperI18n.tr("Close Player", "mpvpaper"),
                                    MpvPaperI18n.tr("Pause Playback", "mpvpaper")
                                ]
                                currentValue: (pluginData && pluginData.lockBehavior === "pause")
                                    ? MpvPaperI18n.tr("Pause Playback", "mpvpaper")
                                    : MpvPaperI18n.tr("Close Player", "mpvpaper")
                                onValueChanged: val => {
                                    const behavior = val === MpvPaperI18n.tr("Pause Playback", "mpvpaper") ? "pause" : "stop"
                                    root.saveSetting("lockBehavior", behavior)
                                }
                            }
                        }
                    }

                    // ── Display & Audio Settings ──
                    CcGroup {
                        CcListRow {
                            iconName: "aspect_ratio"
                            title: MpvPaperI18n.tr("Tiling Mode", "mpvpaper")

                            DDropdown {
                                anchors.verticalCenter: parent.verticalCenter
                                compactMode: true
                                dropdownWidth: 180
                                options: [
                                    MpvPaperI18n.tr("Fill Screen (Crop)", "mpvpaper"),
                                    MpvPaperI18n.tr("Fit Screen (Letterbox)", "mpvpaper"),
                                    MpvPaperI18n.tr("Stretch Fill", "mpvpaper")
                                ]
                                currentValue: {
                                    root.refreshTrigger
                                    const panscan = root.getVideoSetting("panscan", 1.0)
                                    if (panscan === 1.0) return MpvPaperI18n.tr("Fill Screen (Crop)", "mpvpaper")
                                    if (panscan === 0.0) return MpvPaperI18n.tr("Fit Screen (Letterbox)", "mpvpaper")
                                    return MpvPaperI18n.tr("Stretch Fill", "mpvpaper")
                                }
                                onValueChanged: val => {
                                    if (val === MpvPaperI18n.tr("Fill Screen (Crop)", "mpvpaper")) root.saveVideoSetting("panscan", 1.0)
                                    else if (val === MpvPaperI18n.tr("Fit Screen (Letterbox)", "mpvpaper")) root.saveVideoSetting("panscan", 0.0)
                                    else root.saveVideoSetting("panscan", 0.5)
                                }
                            }
                        }

                        CcListRow {
                            iconName: "memory"
                            title: MpvPaperI18n.tr("Hardware Decoding", "mpvpaper")

                            DDropdown {
                                anchors.verticalCenter: parent.verticalCenter
                                compactMode: true
                                dropdownWidth: 120
                                options: ["auto", "no", "vaapi", "vdpau", "nvdec"]
                                currentValue: {
                                    root.refreshTrigger
                                    return root.getVideoSetting("hwdec", "auto")
                                }
                                onValueChanged: val => root.saveVideoSetting("hwdec", val)
                            }
                        }

                        SettingsSliderRow {
                            iconName: "volume_up"
                            text: MpvPaperI18n.tr("Volume", "mpvpaper")
                            value: {
                                root.refreshTrigger
                                return root.getVideoSetting("volume", 0)
                            }
                            minimum: 0
                            maximum: 100
                            step: 1
                            onSliderValueChanged: val => {
                                volumeDebounceTimer.pendingVal = val
                                volumeDebounceTimer.restart()
                            }
                        }

                        CcToggleRow {
                            iconName: "wallpaper"
                            text: MpvPaperI18n.tr("Sync static wallpaper", "mpvpaper")
                            description: MpvPaperI18n.tr("Set current video frame as desktop static wallpaper so overview blur matches video", "mpvpaper")
                            checked: (pluginData && pluginData.syncStaticWallpaper !== undefined) ? !!pluginData.syncStaticWallpaper : true
                            onToggled: isChecked => {
                                root.saveSetting("syncStaticWallpaper", isChecked)
                                if (isChecked) root.syncStaticPreview(root.getCurrentVideoPath())
                            }
                        }
                    }

                    // ── Folders & Scanning ──
                    CcGroup {
                        CcToggleRow {
                            iconName: "sync"
                            text: MpvPaperI18n.tr("Auto-detect new wallpapers", "mpvpaper")
                            description: MpvPaperI18n.tr("Automatically scan wallpaper folders for new videos", "mpvpaper")
                            checked: (pluginData && pluginData.autoDetectFolders !== undefined) ? !!pluginData.autoDetectFolders : true
                            onToggled: isChecked => root.saveSetting("autoDetectFolders", isChecked)
                        }

                        CcListRow {
                            iconName: "folder"
                            title: MpvPaperI18n.tr("Monitored Folders", "mpvpaper")
                            subtitle: root.getWallpaperFolders().length + " " + MpvPaperI18n.tr("folder(s)", "mpvpaper")

                            DButton {
                                text: MpvPaperI18n.tr("Add Folder", "mpvpaper")
                                iconName: "folder_open"
                                buttonHeight: Theme.buttonHeightXS
                                onClicked: root.openSystemDirectoryPicker()
                            }
                        }
                    }
                }
            }
        }
    }

    DPopout {
        id: mpvPaperPopout
        layerNamespace: "dms:plugins:mpvpaper"
        popupWidth: root.popoutWidth
        popupHeight: root.popoutHeight
        content: popoutBody
        onBackgroundClicked: close()
    }

    pillClickAction: function(x, y, width, section, screen) {
        if (mpvPaperPopout.shouldBeVisible) {
            mpvPaperPopout.close()
            return
        }

        const edge = root.axis ? root.axis.edge : ""
        const barPosition = edge === "left" ? 2
            : (edge === "right" ? 3
            : (edge === "top" ? 0 : 1))
        mpvPaperPopout.setTriggerPosition(
            x, y, width, section, screen, barPosition,
            root.barThickness, root.barSpacing, root.barConfig
        )
        mpvPaperPopout.primeContent()
        Qt.callLater(() => {
            mpvPaperPopout.open()
        })
    }

    popoutWidth: 620
    popoutHeight: 460
}
