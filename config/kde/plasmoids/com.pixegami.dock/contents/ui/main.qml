/*
 * Pixegami Dock: a macOS / Latte-style dock for Plasma 6.
 *
 * Lives in a tall, transparent bottom panel: the dock bar is drawn at the
 * bottom and the empty space above gives the zoomed icons room to grow.
 * Apps come from Plasma's own task manager model, so pinned launchers,
 * running windows, activation and closing behave like the stock panel.
 *
 * Features: parabolic zoom, app labels, live window previews, running /
 * focused / attention indicators, launch bounce, click to focus / minimize /
 * show all windows, scroll to cycle windows, drag to reorder, drop files on
 * an app to open them, drop .desktop files to pin, Trash with drop-to-trash,
 * and minimize-to-icon geometry for KWin's Magic Lamp (genie) effect.
 */
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

PlasmoidItem {
    id: root

    // ---- look ------------------------------------------------------------
    readonly property color navy: "#0c1c25"
    readonly property color navyLight: "#152535"
    readonly property color mint: "#86ffaf"
    readonly property color amber: "#ffbc51"
    readonly property color textColor: "#e8f4f0"

    readonly property var cfg: Plasmoid.configuration
    readonly property int baseSize: cfg.iconSize
    readonly property real maxZoom: cfg.maxZoom
    readonly property int maxSize: Math.ceil(baseSize * maxZoom)
    readonly property int spacing: Math.round(baseSize / 6)
    readonly property int pad: Math.round(baseSize / 5)
    readonly property int bottomGap: 8
    readonly property real influence: baseSize * cfg.zoomReach

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Hide the panel's own background so only our dock bar shows.
    function hidePanelBackground() {
        const c = Plasmoid.containment
        if (c && c.backgroundHints !== PlasmaCore.Types.NoBackground) {
            c.backgroundHints = PlasmaCore.Types.NoBackground
        }
    }
    Component.onCompleted: hidePanelBackground()
    Connections {
        target: Plasmoid.containment
        ignoreUnknownSignals: true
        function onBackgroundHintsChanged() { root.hidePanelBackground() }
    }

    // ---- data --------------------------------------------------------------
    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        filterByActivity: true
        filterByVirtualDesktop: false
        filterByScreen: false
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop

        Component.onCompleted: launcherList = root.cfg.launchers
        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(root.cfg.launchers)) {
                root.cfg.launchers = launcherList
            }
        }
    }
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            const saved = root.cfg.launchers
            if (JSON.stringify(saved) !== JSON.stringify(tasksModel.launcherList)) {
                tasksModel.launcherList = saved
            }
        }
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }

    // Trash state (for the full / empty icon).
    FolderListModel {
        id: trashFiles
        folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/Trash/files"
        showHidden: true
        showDirs: true
    }

    function sh(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function openAppLauncher() {
        shell.run("dbus-send --session --type=method_call --dest=org.kde.plasmashell "
                  + "/PlasmaShell org.kde.PlasmaShell.activateLauncherMenu")
    }

    function role(idx, r) { return tasksModel.data(idx, r) }

    function windowIds(row) {
        const idx = tasksModel.makeModelIndex(row)
        return role(idx, TaskManager.AbstractTasksModel.WinIdList) || []
    }

    // KWin "show this app's windows side by side" (WindowView effect).
    function presentWindows(row) {
        const ids = windowIds(row)
        if (!ids.length) return
        shell.run("dbus-send --session --type=method_call --dest=org.kde.KWin "
                  + "/org/kde/KWin/Effect/WindowView1 org.kde.KWin.Effect.WindowView1.activate "
                  + "array:string:" + ids.map(id => sh(String(id))).join(","))
    }

    // Left click: launch, focus, minimize, or show all of an app's windows.
    function activate(row) {
        const idx = tasksModel.makeModelIndex(row)
        const isLauncher = role(idx, TaskManager.AbstractTasksModel.IsLauncher)
        const children = role(idx, TaskManager.AbstractTasksModel.ChildCount) || 0
        const isActive = role(idx, TaskManager.AbstractTasksModel.IsActive)

        if (isLauncher) { tasksModel.requestActivate(idx); return }
        if (children <= 1) {
            if (isActive) tasksModel.requestToggleMinimized(idx)
            else tasksModel.requestActivate(idx)
            return
        }
        if (isActive) { presentWindows(row); return }
        // Focus the app's most recently used window.
        let recent = 0, recentTime = 0
        for (let i = 0; i < children; ++i) {
            const t = role(tasksModel.makeModelIndex(row, i), TaskManager.AbstractTasksModel.LastActivated)
            if (t && t > recentTime) { recentTime = t; recent = i }
        }
        tasksModel.requestActivate(tasksModel.makeModelIndex(row, recent))
    }

    // Scroll on an icon: cycle through that app's windows.
    function cycle(row, forward) {
        const idx = tasksModel.makeModelIndex(row)
        const children = role(idx, TaskManager.AbstractTasksModel.ChildCount) || 0
        if (children <= 1) {
            if (!role(idx, TaskManager.AbstractTasksModel.IsLauncher)) tasksModel.requestActivate(idx)
            return
        }
        let active = -1
        for (let i = 0; i < children; ++i) {
            if (role(tasksModel.makeModelIndex(row, i), TaskManager.AbstractTasksModel.IsActive)) active = i
        }
        const next = active < 0 ? 0 : (active + (forward ? 1 : children - 1)) % children
        tasksModel.requestActivate(tasksModel.makeModelIndex(row, next))
    }

    // ---- hover zoom (smoothed) -------------------------------------------------
    // Zoom is computed from each icon's *resting* position so icons don't chase
    // the pointer as the dock widens. The pointer position and the zoom amount
    // are both eased every frame, which keeps motion fluid.
    readonly property int itemCount: tasksModel.count + 1 + (cfg.showTrash ? 1 : 0)
    property real pointerX: -1
    property real easedX: -1
    property bool hovering: false
    property real zoomAmount: 0          // 0 = flat, 1 = fully zoomed

    Behavior on zoomAmount {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    onHoveringChanged: {
        if (hovering && easedX < 0) easedX = pointerX
        zoomAmount = hovering ? 1 : 0
    }

    FrameAnimation {
        running: root.hovering || Math.abs(root.easedX - root.pointerX) > 0.3
        onTriggered: {
            const k = Math.min(1, frameTime * 22)
            root.easedX += (root.pointerX - root.easedX) * k
        }
    }

    function restingCenter(slot) {
        // slots: 0 launcher, 1..n tasks, then separator gap + trash
        const sepExtra = cfg.showTrash ? spacing * 2 + 2 : 0
        const total = itemCount * baseSize + (itemCount - 1) * spacing + sepExtra
        let x = (width - total) / 2 + slot * (baseSize + spacing) + baseSize / 2
        if (cfg.showTrash && slot === itemCount - 1) x += sepExtra
        return x
    }
    function zoomFor(slot) {
        if (zoomAmount <= 0.001) return 1
        const d = Math.abs(easedX - restingCenter(slot))
        if (d >= influence) return 1
        const s = (1 + Math.cos(Math.PI * d / influence)) / 2
        return 1 + (maxZoom - 1) * s * zoomAmount
    }

    // ---- previews ------------------------------------------------------------
    property Item previewFor: null       // the DockIcon whose preview is open
    property int previewRow: -1
    property var previewWindows: []

    function buildPreviewList(row) {
        const idx = tasksModel.makeModelIndex(row)
        const children = role(idx, TaskManager.AbstractTasksModel.ChildCount) || 0
        const list = []
        if (children > 0) {
            for (let i = 0; i < children; ++i) {
                const c = tasksModel.makeModelIndex(row, i)
                list.push({ row: row, child: i, title: role(c, Qt.DisplayRole) || "",
                            uuid: String((role(c, TaskManager.AbstractTasksModel.WinIdList) || [""])[0]),
                            minimized: role(c, TaskManager.AbstractTasksModel.IsMinimized) === true })
            }
        } else if (!role(idx, TaskManager.AbstractTasksModel.IsLauncher)) {
            list.push({ row: row, child: -1, title: role(idx, Qt.DisplayRole) || "",
                        uuid: String((role(idx, TaskManager.AbstractTasksModel.WinIdList) || [""])[0]),
                        minimized: role(idx, TaskManager.AbstractTasksModel.IsMinimized) === true })
        }
        return list
    }

    function showPreview(icon, row) {
        if (!cfg.showPreviews) return
        const list = buildPreviewList(row)
        if (!list.length) { hidePreview(); return }
        previewWindows = list
        previewRow = row
        previewFor = icon
        previewCloseTimer.stop()
        previewDialog.visible = true
    }
    function hidePreview() {
        previewDialog.visible = false
        previewFor = null
        previewRow = -1
        previewWindows = []
    }
    Timer {
        id: previewCloseTimer
        interval: 350
        onTriggered: if (!previewHover.hovered) root.hidePreview()
    }

    PlasmaCore.Dialog {
        id: previewDialog
        visualParent: root.previewFor
        location: PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        visible: false

        mainItem: Rectangle {
            id: previewBox
            readonly property int thumbW: 240
            readonly property int thumbH: 150
            width: previewRowItem.implicitWidth + 20
            height: previewRowItem.implicitHeight + 20
            radius: 14
            color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.3)

            HoverHandler {
                id: previewHover
                onHoveredChanged: if (!hovered) previewCloseTimer.restart()
            }

            Row {
                id: previewRowItem
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: root.previewWindows
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property var idx: modelData.child >= 0
                            ? tasksModel.makeModelIndex(modelData.row, modelData.child)
                            : tasksModel.makeModelIndex(modelData.row)
                        width: previewBox.thumbW
                        height: previewBox.thumbH + 30
                        radius: 10
                        color: cardMouse.containsMouse ? Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Item {
                            id: thumbArea
                            x: 6; y: 6
                            width: parent.width - 12
                            height: previewBox.thumbH - 6

                            TaskManager.ScreencastingRequest {
                                id: cast
                                uuid: root.previewDialog_visible() && !card.modelData.minimized ? card.modelData.uuid : ""
                            }
                            PipeWire.PipeWireSourceItem {
                                id: live
                                anchors.fill: parent
                                nodeId: cast.nodeId
                                visible: nodeId > 0 && ready
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 64; height: 64
                                visible: !live.visible
                                source: root.previewFor ? root.previewFor.iconSource : ""
                                opacity: 0.8
                            }
                        }

                        Text {
                            anchors { left: parent.left; right: closeBtn.left; bottom: parent.bottom; margins: 8 }
                            text: card.modelData.title
                            color: root.textColor
                            elide: Text.ElideRight
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: (e) => {
                                if (e.button === Qt.MiddleButton) tasksModel.requestClose(card.idx)
                                else tasksModel.requestActivate(card.idx)
                                root.hidePreview()
                            }
                        }

                        Rectangle {
                            id: closeBtn
                            anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                            width: 20; height: 20; radius: 10
                            visible: cardMouse.containsMouse || closeMouse.containsMouse
                            color: closeMouse.containsMouse ? "#ff3c3c" : Qt.rgba(1, 1, 1, 0.12)
                            Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 11 }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: tasksModel.requestClose(card.idx)
                            }
                        }
                    }
                }
            }
        }
    }
    function previewDialog_visible() { return previewDialog.visible }

    // ---- reorder by drag -------------------------------------------------------
    property int dragRow: -1

    function slotAt(globalX) {
        for (let i = 0; i < taskRepeater.count; ++i) {
            const it = taskRepeater.itemAt(i)
            if (!it) continue
            const p = it.mapToGlobal(0, 0)
            if (globalX >= p.x && globalX < p.x + it.width) return i
        }
        return -1
    }

    // ---- view ----------------------------------------------------------------
    fullRepresentation: Item {
        id: stage

        HoverHandler {
            id: hover
            onPointChanged: {
                const p = point.position
                const barTop = stage.height - root.bottomGap - bar.height
                const zoomTop = stage.height - root.bottomGap - root.pad - root.maxSize - 4
                const inX = p.x >= bar.x - root.baseSize && p.x <= bar.x + bar.width + root.baseSize
                root.pointerX = p.x
                root.hovering = hovered && inX && p.y >= (root.hovering ? zoomTop : barTop)
            }
            onHoveredChanged: if (!hovered) root.hovering = false
        }

        // Drop a .desktop file anywhere on the dock to pin it.
        DropArea {
            anchors.fill: bar
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                for (const u of drop.urls) {
                    const s = u.toString()
                    if (s.endsWith(".desktop")) tasksModel.requestAddLauncher(u)
                }
            }
        }

        // The dock bar: semi-transparent navy with a soft gradient and mint edge.
        Rectangle {
            id: bar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomGap
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.baseSize + 2 * root.pad
            width: icons.width + 2 * root.pad
            radius: Math.round(height * 0.3)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.11, 0.2, 0.26, root.cfg.bgOpacity) }
                GradientStop { position: 1.0; color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, Math.min(1, root.cfg.bgOpacity + 0.15)) }
            }
            border.width: 1
            border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.22)

            // soft drop shadow
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.margins: -2
                anchors.topMargin: 2
                radius: parent.radius + 2
                color: "transparent"
                border.width: 3
                border.color: Qt.rgba(0, 0, 0, 0.18)
            }
            // top sheen
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                height: 1
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.10)
            }
        }

        Row {
            id: icons
            anchors.bottom: bar.bottom
            anchors.bottomMargin: root.pad
            anchors.horizontalCenter: bar.horizontalCenter
            height: root.maxSize
            spacing: root.spacing

            DockIcon {
                zoom: root.zoomFor(0)
                iconSource: "start-here-kde-plasma"
                label: "Applications"
                onLeftClicked: root.openAppLauncher()
            }

            Repeater {
                id: taskRepeater
                model: tasksModel
                delegate: DockIcon {
                    id: task
                    required property int index
                    required property var model

                    taskRow: index
                    zoom: root.zoomFor(index + 1)
                    iconSource: model.decoration
                    label: model.AppName || model.display || ""
                    running: !model.IsLauncher && !model.IsStartup
                    active: model.IsActive === true
                    minimized: model.IsMinimized === true
                    windows: model.ChildCount || (running ? 1 : 0)
                    attention: model.IsDemandingAttention === true
                    starting: model.IsStartup === true
                    dragging: root.dragRow === index

                    onLeftClicked: { root.hidePreview(); root.activate(index) }
                    onMiddleClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(index))
                    onRightClicked: { root.hidePreview(); menu.openRelative() }
                    onWheel: (forward) => root.cycle(index, forward)
                    onHoverStarted: previewDelay.restart()
                    onHoverEnded: { previewDelay.stop(); previewCloseTimer.restart() }
                    onFilesDropped: (urls) => tasksModel.requestOpenUrls(tasksModel.makeModelIndex(index), urls)

                    Timer {
                        id: previewDelay
                        interval: root.previewFor ? 80 : 450
                        onTriggered: root.showPreview(task, task.index)
                    }

                    // Tell KWin where this app's icon is, so minimize (genie) animates into it.
                    function publishGeometry() {
                        if (!task.running) return
                        const p = task.mapToGlobal(0, 0)
                        tasksModel.requestPublishDelegateGeometry(
                            tasksModel.makeModelIndex(index),
                            Qt.rect(Math.round(p.x), Math.round(p.y + task.height - root.baseSize),
                                    root.baseSize, root.baseSize),
                            task)
                    }
                    Timer {
                        id: geomTimer
                        interval: 250
                        onTriggered: task.publishGeometry()
                    }
                    onRunningChanged: geomTimer.restart()
                    onXChanged: if (!root.hovering) geomTimer.restart()
                    Component.onCompleted: geomTimer.restart()
                    Connections {
                        target: root
                        function onHoveringChanged() { if (!root.hovering) geomTimer.restart() }
                    }

                    PlasmaExtras.Menu {
                        id: menu
                        visualParent: task
                        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

                        PlasmaExtras.MenuItem {
                            text: "New Window"
                            icon: "window-new"
                            onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(task.index))
                        }
                        PlasmaExtras.MenuItem {
                            visible: task.windows > 1
                            text: "Show All Windows"
                            icon: "view-grid"
                            onClicked: root.presentWindows(task.index)
                        }
                        PlasmaExtras.MenuItem {
                            readonly property bool pinned: task.model.IsLauncher || task.model.HasLauncher
                            text: pinned ? "Unpin from Dock" : "Pin to Dock"
                            icon: pinned ? "window-unpin" : "window-pin"
                            onClicked: {
                                if (pinned) tasksModel.requestRemoveLauncher(task.model.LauncherUrlWithoutIcon)
                                else tasksModel.requestAddLauncher(task.model.LauncherUrl)
                            }
                        }
                        PlasmaExtras.MenuItem {
                            visible: task.running
                            text: task.minimized ? "Restore" : "Minimize"
                            icon: task.minimized ? "window-restore" : "window-minimize"
                            onClicked: tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(task.index))
                        }
                        PlasmaExtras.MenuItem {
                            visible: task.running
                            text: task.windows > 1 ? "Close All Windows" : "Close"
                            icon: "window-close"
                            onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(task.index))
                        }
                    }
                }
            }

            // separator + Trash
            Item {
                visible: root.cfg.showTrash
                width: 2; height: root.baseSize * 0.75
                y: parent.height - height - root.baseSize * 0.12
                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.25)
                }
            }

            DockIcon {
                visible: root.cfg.showTrash
                zoom: root.zoomFor(root.itemCount - 1)
                iconSource: trashFiles.count > 0 ? "user-trash-full" : "user-trash"
                label: trashFiles.count > 0 ? "Trash (" + trashFiles.count + ")" : "Trash"
                onLeftClicked: root.shell_open("trash:/")
                onFilesDropped: (urls) => root.shell_trash(urls)
            }
        }
    }

    function shell_open(url) { shell.run("xdg-open " + sh(url)) }
    function shell_trash(urls) {
        const args = urls.map(u => sh(u.toString())).join(" ")
        if (args.length) shell.run("kioclient move " + args + " trash:/")
    }

    // ---- one dock icon ----------------------------------------------------------
    component DockIcon: Item {
        id: item
        property int taskRow: -1
        property real zoom: 1
        property var iconSource
        property string label
        property bool running: false
        property bool active: false
        property bool minimized: false
        property int windows: 0
        property bool attention: false
        property bool starting: false
        property bool dragging: false

        signal leftClicked()
        signal middleClicked()
        signal rightClicked()
        signal wheel(bool forward)
        signal hoverStarted()
        signal hoverEnded()
        signal filesDropped(var urls)

        width: root.baseSize * zoom
        height: root.baseSize * zoom
        y: parent.height - height
        z: mouse.containsMouse ? 2 : 1

        // Icon is rendered once at full zoom size and scaled on the GPU: smooth,
        // and no re-rasterising every frame.
        Kirigami.Icon {
            id: glyph
            width: root.maxSize
            height: root.maxSize
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            transformOrigin: Item.Bottom
            scale: item.zoom / root.maxZoom
            source: item.iconSource
            roundToIconSize: false
            smooth: true
            opacity: item.dragging ? 0.6 : (item.minimized ? 0.75 : 1)
            transform: Translate { id: lift; y: 0 }

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Soft mint glow under the focused app.
        Rectangle {
            visible: item.active
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -root.pad + 3
            width: parent.width * 0.9
            height: root.pad + 2
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.18) }
            }
        }

        // Bounce while the app is starting.
        SequentialAnimation {
            running: item.starting && root.cfg.bounceOnLaunch
            loops: Animation.Infinite
            NumberAnimation { target: lift; property: "y"; to: -root.baseSize * 0.45; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0; duration: 300; easing.type: Easing.InQuad }
            onRunningChanged: if (!running) lift.y = 0
        }
        // Hop when an app wants attention.
        SequentialAnimation {
            running: item.attention
            loops: Animation.Infinite
            NumberAnimation { target: lift; property: "y"; to: -root.baseSize * 0.3; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBounce }
            PauseAnimation { duration: 900 }
            onRunningChanged: if (!running) lift.y = 0
        }
        // Small press feedback.
        SequentialAnimation {
            id: pressAnim
            NumberAnimation { target: lift; property: "y"; to: 3; duration: 70 }
            NumberAnimation { target: lift; property: "y"; to: 0; duration: 160; easing.type: Easing.OutBack }
        }

        // Running indicator: a dot per window (max 3), wide pill when focused.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: Math.max(2, root.pad / 2 - 2)
            spacing: 3
            visible: item.running
            Repeater {
                model: item.active ? 1 : Math.min(item.windows, 3)
                Rectangle {
                    width: item.active ? 16 : 5
                    height: 5
                    radius: 2.5
                    color: item.attention ? root.amber : root.mint
                    opacity: item.active ? 1 : (item.minimized ? 0.45 : 0.8)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Name label above the hovered icon.
        Rectangle {
            id: tag
            readonly property bool shown: root.cfg.showLabels && mouse.containsMouse
                                          && item.label.length > 0 && root.previewFor !== item
            opacity: shown ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            width: name.implicitWidth + 18
            height: name.implicitHeight + 8
            radius: 7
            color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, 0.95)
            border.width: 1
            border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.35)
            Text {
                id: name
                anchors.centerIn: parent
                text: item.label
                color: root.mint
                font.pixelSize: 13
            }
        }

        // Files dragged over an app: highlight, raise its window, open on drop.
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: raiseTimer.restart()
            onExited: raiseTimer.stop()
            onDropped: (drop) => { raiseTimer.stop(); item.filesDropped(drop.urls) }
            Rectangle {
                anchors.fill: parent
                radius: 10
                visible: parent.containsDrag
                color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.18)
            }
            Timer {
                id: raiseTimer
                interval: 700
                onTriggered: if (item.taskRow >= 0 && item.running) root.activate(item.taskRow)
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            property real pressX: 0
            property bool moved: false

            onContainsMouseChanged: containsMouse ? item.hoverStarted() : item.hoverEnded()

            onPressed: (e) => { pressX = e.x; moved = false }
            onPositionChanged: (e) => {
                if (!(e.buttons & Qt.LeftButton) || item.taskRow < 0) return
                if (!moved && Math.abs(e.x - pressX) > 10) {
                    moved = true
                    root.dragRow = item.taskRow
                    root.hidePreview()
                }
                if (moved) {
                    const g = mapToGlobal(e.x, e.y)
                    const target = root.slotAt(g.x)
                    if (target >= 0 && target !== root.dragRow) {
                        tasksModel.move(root.dragRow, target)
                        root.dragRow = target
                    }
                }
            }
            onReleased: (e) => {
                if (moved) {
                    tasksModel.syncLaunchers()
                    root.dragRow = -1
                }
            }
            onClicked: (e) => {
                if (moved) return
                if (e.button === Qt.LeftButton) { pressAnim.restart(); item.leftClicked() }
                else if (e.button === Qt.MiddleButton) item.middleClicked()
                else item.rightClicked()
            }
            onWheel: (w) => item.wheel(w.angleDelta.y < 0)
        }
    }
}
