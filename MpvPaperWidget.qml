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
    property int currentPage: 0
    property int itemsPerPage: 8  // 2x4 grid
    readonly property real popoutPadding: Theme.spacingM
    readonly property real popoutContentWidth: popoutWidth - popoutPadding * 2
    readonly property real popoutGridCellHeight: Math.floor(popoutContentWidth / 4) * 9 / 16
    readonly property real naturalPopoutHeight: popoutPadding * 2
        + 32
        + (monitors.length > 1 ? 40 + Theme.spacingM : 0)
        + popoutGridCellHeight * 2
        + Theme.spacingM * 2
        + 40
    property int totalPages: Math.max(1, Math.ceil(getPlaylist().length / itemsPerPage))
    property int refreshTrigger: 0
    property int gridIndex: 0
    property var fileBrowserParentPopout: null
    property bool sameOnAllMonitors: pluginData.sameOnAllMonitors || false

    // ── Control Center Integration ──
    ccWidgetIcon: "movie"
    ccWidgetPrimaryText: MpvPaperI18n.tr("Live Wallpaper", "mpvpaper")
    ccWidgetSecondaryText: {
        root.refreshTrigger
        const current = root.getCurrentVideoPath()
        if (!current) return MpvPaperI18n.tr("No video selected", "mpvpaper")
        const filename = current.split("/").pop()
        if (pluginData && pluginData.slideshowEnabled) {
            return filename + " (Auto)"
        }
        return filename
    }
    ccWidgetIsActive: root.getCurrentVideoPath() !== ""
    ccWidgetIsToggle: true
    ccDetailHeight: 480

    onCcWidgetToggled: root.cycleNextVideo()

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

    onRefreshTriggerChanged: {
        selectionSyncTimer.restart()
    }

    onSelectedMonitorChanged: selectionSyncTimer.restart()

    Timer {
        id: selectionSyncTimer
        interval: 0
        repeat: false
        onTriggered: root.syncSelectionToPlayback()
    }

    function syncSelectionToPlayback() {
        const currentPath = getCurrentVideoPath()
        const playlist = getPlaylist()
        const index = playlist.indexOf(currentPath)
        if (index < 0) return
        currentPage = Math.floor(index / itemsPerPage)
        gridIndex = index % itemsPerPage
    }

    function getPlaylist() {
        if (!pluginService) return []
        const library = pluginService.loadPluginData("mpvpaper", "videoLibrary", [])
        return Array.isArray(library) ? library : []
    }

    function cycleMonitor(offset) {
        if (monitors.length < 2) return
        let index = monitors.indexOf(selectedMonitor)
        if (index < 0) index = 0
        selectedMonitor = monitors[(index + offset + monitors.length) % monitors.length]
        selectionSyncTimer.restart()
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

        if (sameOnAllMonitors) {
            pluginService.savePluginData("mpvpaper", "allMonitorsVideo", videoPath)
        } else {
            const monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})
            if (selectedMonitor) monitorVideos[selectedMonitor] = videoPath
            pluginService.savePluginData("mpvpaper", "monitorVideos", monitorVideos)
        }

        const videoIndex = getPlaylist().indexOf(videoPath)
        currentPage = Math.floor(videoIndex / itemsPerPage)
        gridIndex = videoIndex % itemsPerPage
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

        // Track folder
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
                console.log("MpvPaper Widget: System file picker not available, using DMS file browser")
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

            Connections {
                target: popout.parentPopout
                ignoreUnknownSignals: true
                function onShouldBeVisibleChanged() {
                    if (popout.parentPopout && popout.parentPopout.shouldBeVisible)
                        selectionSyncTimer.restart()
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight

                Column {
                    anchors.fill: parent
                    anchors.margins: root.popoutPadding
                    spacing: Theme.spacingM

                    // Compact header row
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
                                iconName: "refresh"
                                iconSize: 18
                                buttonSize: 32
                                tooltipText: MpvPaperI18n.tr("Rescan Wallpapers", "mpvpaper")
                                onClicked: root.rescanMonitoredFolders(true)
                            }

                            DActionButton {
                                iconName: "skip_next"
                                iconSize: 18
                                buttonSize: 32
                                tooltipText: MpvPaperI18n.tr("Next wallpaper", "mpvpaper")
                                visible: pluginData.slideshowEnabled || false
                                onClicked: root.cycleNextVideo()
                            }

                            DActionButton {
                                iconName: "close"
                                iconSize: 18
                                buttonSize: 32
                                onClicked: mpvPaperPopout.close()
                            }
                        }
                    }

                    // Monitor selector
                    Item {
                        width: parent.width
                        height: root.monitors.length > 1 ? 40 : 0
                        visible: root.monitors.length > 1
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingM

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: sameAllRow.implicitWidth + Theme.spacingM * 2
                                implicitHeight: 40
                                radius: Theme.cornerRadius
                                color: root.sameOnAllMonitors ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                                border.width: 1
                                border.color: root.sameOnAllMonitors ? Theme.primary : Theme.outlineHeavy

                                Row {
                                    id: sameAllRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS
                                    DIcon {
                                        name: "linked_services"
                                        size: 16
                                        color: root.sameOnAllMonitors ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: MpvPaperI18n.tr("All", "mpvpaper")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.sameOnAllMonitors ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const enabling = !root.sameOnAllMonitors
                                        if (pluginService && enabling && !pluginService.loadPluginData("mpvpaper", "allMonitorsVideo", "")) {
                                            const monitorVideos = pluginService.loadPluginData("mpvpaper", "monitorVideos", {})
                                            const sourceVideo = monitorVideos[root.selectedMonitor] || ""
                                            if (sourceVideo) {
                                                pluginService.savePluginData("mpvpaper", "allMonitorsVideo", sourceVideo)
                                            }
                                        }
                                        root.sameOnAllMonitors = enabling
                                        if (pluginService) {
                                            pluginService.savePluginData("mpvpaper", "sameOnAllMonitors", root.sameOnAllMonitors)
                                        }
                                        root.refreshTrigger++
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 40
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                                border.width: 1
                                border.color: Theme.outlineHeavy
                                opacity: root.sameOnAllMonitors ? 0.4 : 1.0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS

                                    DActionButton {
                                        iconName: "chevron_left"
                                        iconSize: 18
                                        buttonSize: 30
                                        enabled: !root.sameOnAllMonitors
                                        onClicked: root.cycleMonitor(-1)
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: root.sameOnAllMonitors ? MpvPaperI18n.tr("All Monitors", "mpvpaper") : (root.selectedMonitor || MpvPaperI18n.tr("No Monitors", "mpvpaper"))
                                        font.pixelSize: Theme.fontSizeMedium
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                    DActionButton {
                                        iconName: "chevron_right"
                                        iconSize: 18
                                        buttonSize: 30
                                        enabled: !root.sameOnAllMonitors
                                        onClicked: root.cycleMonitor(1)
                                    }
                                }
                            }
                        }
                    }

                    // Video grid
                    Item {
                        id: gridContainer
                        width: parent.width
                        height: gridContainer.cellHeight * 2
                        property real cellWidth: Math.floor(width / 4)
                        property real cellHeight: cellWidth * 9 / 16

                        GridView {
                            id: videoGrid
                            width: cellWidth * 4
                            height: cellHeight * 2
                            anchors.centerIn: parent
                            cellWidth: gridContainer.cellWidth
                            cellHeight: gridContainer.cellHeight
                            clip: true
                            interactive: false
                            currentIndex: root.gridIndex

                            model: {
                                root.refreshTrigger
                                const playlist = root.getPlaylist()
                                const startIndex = root.currentPage * root.itemsPerPage
                                return playlist.slice(startIndex, startIndex + root.itemsPerPage)
                            }

                            onCountChanged: if (count > 0) currentIndex = Math.min(root.gridIndex, count - 1)
                            onCurrentIndexChanged: root.gridIndex = currentIndex

                            delegate: Item {
                                width: videoGrid.cellWidth
                                height: videoGrid.cellHeight
                                property bool isSelected: { root.refreshTrigger; return root.getCurrentVideoPath() === modelData }

                                readonly property string hashStr: {
                                    let h = 0
                                    for (let i = 0; i < modelData.length; i++) {
                                        h = ((h << 5) - h) + modelData.charCodeAt(i)
                                        h = h & h
                                    }
                                    return Math.abs(h).toString()
                                }
                                readonly property string thumbDir: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace("file://", "") + "/DankMaterialShell/mpvpaper_thumbnails"
                                readonly property string expectedThumb: thumbDir + "/" + hashStr + "_thumb.jpg"

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingXS
                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                    radius: Theme.cornerRadius
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        z: 9
                                        color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        z: 10
                                        color: "transparent"
                                        border.width: isSelected ? 3 : 0
                                        border.color: Theme.primary
                                    }

                                    Image {
                                        id: popoutThumbImg
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        source: {
                                            const loc = StandardPaths.locate(
                                                StandardPaths.GenericCacheLocation,
                                                "DankMaterialShell/mpvpaper_thumbnails/" + hashStr + "_thumb.jpg",
                                                StandardPaths.LocateFile
                                            )
                                            if (loc.toString() !== "") {
                                                const s = loc.toString()
                                                return s.startsWith("file://") ? s : "file://" + s
                                            }
                                            return ""
                                        }

                                        Component.onCompleted: {
                                            if (source.toString() === "") popoutThumbGen.running = true
                                        }

                                        onStatusChanged: {
                                            if (status === Image.Error || (status === Image.Null && source.toString() === ""))
                                                popoutThumbGen.running = true
                                        }
                                    }

                                    Process {
                                        id: popoutThumbGen
                                        command: [
                                            "bash", "-c",
                                            'mkdir -p -- "$1" && ffmpeg -loglevel error -i "$2" -ss 00:00:01 -vframes 1 -vf "scale=320:180:force_original_aspect_ratio=increase,crop=320:180" -q:v 3 "$3" -y',
                                            "mpvpaper-popout-thumb", thumbDir, modelData, expectedThumb
                                        ]
                                        onExited: code => {
                                            if (code === 0) popoutThumbImg.source = "file://" + expectedThumb
                                        }
                                    }

                                    DIcon {
                                        anchors.centerIn: parent
                                        name: "movie"
                                        size: 24
                                        color: Theme.primary
                                        visible: popoutThumbImg.status !== Image.Ready
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            videoGrid.currentIndex = index
                                            if (modelData) root.setCurrentVideo(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom navigation
                    Item {
                        width: parent.width
                        height: 40

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DActionButton {
                                iconName: "chevron_left"
                                iconSize: 18
                                buttonSize: 32
                                enabled: root.currentPage > 0
                                opacity: enabled ? 0.8 : 0.2
                                onClicked: { root.currentPage--; root.gridIndex = 0 }
                            }

                            StyledText {
                                width: 56
                                height: 32
                                text: (root.currentPage + 1) + " / " + root.totalPages
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.65
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            DActionButton {
                                iconName: "chevron_right"
                                iconSize: 18
                                buttonSize: 32
                                enabled: root.currentPage < root.totalPages - 1
                                opacity: enabled ? 0.8 : 0.2
                                onClicked: { root.currentPage++; root.gridIndex = 0 }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DActionButton {
                                iconName: "folder_open"
                                iconSize: 18
                                buttonSize: 32
                                tooltipText: MpvPaperI18n.tr("Add Folder", "mpvpaper")
                                onClicked: root.openSystemDirectoryPicker()
                            }

                            DActionButton {
                                iconName: "add"
                                iconSize: 18
                                buttonSize: 32
                                tooltipText: MpvPaperI18n.tr("Add Video", "mpvpaper")
                                onClicked: root.openSystemFilePicker()
                            }
                        }
                    }
                }
            }
        }
    }

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
                                text: {
                                    root.refreshTrigger
                                    const cur = root.getCurrentVideoPath()
                                    return cur ? cur.split("/").pop() : MpvPaperI18n.tr("No video selected", "mpvpaper")
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
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
                            iconName: "refresh"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Rescan Wallpapers", "mpvpaper")
                            onClicked: root.rescanMonitoredFolders(true)
                        }

                        DActionButton {
                            iconName: "skip_next"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Next wallpaper", "mpvpaper")
                            onClicked: root.cycleNextVideo()
                        }

                        DActionButton {
                            iconName: "add"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Add Video", "mpvpaper")
                            onClicked: root.openSystemFilePicker()
                        }

                        DActionButton {
                            iconName: "folder_open"
                            iconSize: 18
                            buttonSize: 32
                            tooltipText: MpvPaperI18n.tr("Add Folder", "mpvpaper")
                            onClicked: root.openSystemDirectoryPicker()
                        }
                    }

                    // ── Horizontal Wallpaper Carousel ──
                    Item {
                        width: parent.width
                        height: 110

                        ListView {
                            id: ccVideoList
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: Theme.spacingS
                            clip: true

                            model: {
                                root.refreshTrigger
                                return root.getPlaylist()
                            }

                            delegate: Rectangle {
                                id: cardRoot
                                width: 160
                                height: 100
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                border.width: isSelected ? 2 : 1
                                border.color: isSelected ? Theme.primary : Theme.outlineHeavy
                                clip: true

                                readonly property bool isSelected: {
                                    root.refreshTrigger
                                    return root.getCurrentVideoPath() === modelData
                                }
                                readonly property string videoPath: modelData
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
                                            "DankMaterialShell/mpvpaper_thumbnails/" + cardRoot.hashStr + "_thumb.jpg",
                                            StandardPaths.LocateFile
                                        )
                                        if (loc.toString() !== "") {
                                            const s = loc.toString()
                                            return s.startsWith("file://") ? s : "file://" + s
                                        }
                                        return ""
                                    }

                                    Component.onCompleted: {
                                        if (source.toString() === "") cardThumbGen.running = true
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Error || (status === Image.Null && source.toString() === "")) {
                                            cardThumbGen.running = true
                                        }
                                    }
                                }

                                Process {
                                    id: cardThumbGen
                                    command: [
                                        "bash", "-c",
                                        'mkdir -p -- "$1" && ffmpeg -loglevel error -i "$2" -ss 00:00:01 -vframes 1 -vf "scale=320:180:force_original_aspect_ratio=increase,crop=320:180" -q:v 3 "$3" -y',
                                        "mpvpaper-card-thumb",
                                        cardRoot.thumbDir,
                                        cardRoot.videoPath,
                                        cardRoot.expectedThumbPath
                                    ]
                                    onExited: code => {
                                        if (code === 0) cardImg.source = "file://" + cardRoot.expectedThumbPath
                                    }
                                }

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "movie"
                                    size: 26
                                    color: Theme.primary
                                    visible: cardImg.status !== Image.Ready
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 28
                                    color: Qt.rgba(0, 0, 0, 0.65)

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        text: modelData.split("/").pop()
                                        font.pixelSize: Theme.fontSizeSmall * 0.85
                                        color: "white"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: Theme.error
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    visible: cardMouseArea.containsMouse
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
                                        onClicked: root.removeFromPlaylist(index)
                                    }
                                }

                                MouseArea {
                                    id: cardMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setCurrentVideo(modelData)
                                }
                            }
                        }
                    }

                    // ── Monitor Selection (Multi-Monitor) ──
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

                    // ── Power & Playback ──
                    CcGroup {
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
            root.syncSelectionToPlayback()
            mpvPaperPopout.open()
        })
    }

    popoutWidth: 600
    popoutHeight: Math.ceil(naturalPopoutHeight)
}
