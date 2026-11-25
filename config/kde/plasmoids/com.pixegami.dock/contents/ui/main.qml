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
    readonly property int bottomGap: 4
    readonly property real influence: baseSize * cfg.zoomReach

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ---- panel integration ------------------------------------------------------
    // The panel draws its background (and asks KWin for blur) from one frame
    // item that fills the whole panel. We shrink that frame to sit exactly under
    // our dock bar and make it invisible: KWin then blurs only behind the bar,
    // and the rest of the tall panel stays fully transparent.
    property Item panelRoot: null
    property Item panelFrame: null
    property var panelFrames: []

    function findPanelRoot() {
        let p = root.parent
        while (p) {
            if (p.floatingTranslucentItemOffset !== undefined) return p
            p = p.parent
        }
        return null
    }
    function hookPanel() {
        // Panel background must stay on: Plasma only requests blur when it is.
        // Its frames are made invisible and resized to the bar below.
        const c = Plasmoid.containment
        if (c && c.backgroundHints !== PlasmaCore.Types.StandardBackground) {
            c.backgroundHints = PlasmaCore.Types.StandardBackground
        }
        panelRoot = findPanelRoot()
        if (!panelRoot) return
        const frames = []
        for (const ch of panelRoot.children) {
            if (ch.imagePath !== undefined) frames.push(ch)
        }
        // The master frame is the one the others anchor to.
        let master = null
        for (const f of frames) {
            const a = f.anchors.fill
            if (a && frames.indexOf(a) >= 0) { master = a; break }
        }
        panelFrames = frames.filter(f => f === master || f.anchors.fill === master)
        panelFrame = master
        // rounded frame from the Plasma style, so the blur has rounded corners
        for (const f of panelFrames) {
            f.imagePath = "dialogs/background"
            if (f.enabledBorders !== undefined) f.enabledBorders = 15   // all borders
        }
        for (const f of panelFrames) f.opacity = 0
        syncPanelFrame()
        hideDashboardApplet()
        Qt.callLater(syncPanelFrame)
    }
    // Bar geometry. The blur frame is placed from the panel's own size only
    // (centred, at the bottom) and the bar is then positioned onto it. Nothing
    // here depends on where Plasma put this widget, so there is no feedback.
    property Item barItem: null
    property real barX: (width - barW) / 2
    property real barY: height - bottomGap - barH
    property real dockCenterX: width / 2
    readonly property real barW: (barItem ? barItem.width : 0)
    readonly property real barH: baseSize + 2 * pad

    function syncPanelFrame() {
        if (!panelRoot || !barItem) return
        const fw = Math.round(barW)
        const fh = Math.round(barH)
        const fx = Math.round((panelRoot.width - fw) / 2)
        const fy = Math.round(panelRoot.height - bottomGap - fh)
        if (panelFrame) {
            if (panelFrame.x !== fx) panelFrame.x = fx
            if (panelFrame.y !== fy) panelFrame.y = fy
            if (panelFrame.width !== fw) panelFrame.width = fw
            if (panelFrame.height !== fh) panelFrame.height = fh
            for (const f of panelFrames) if (f.opacity !== 0) f.opacity = 0
        }
        const p = root.mapFromItem(panelRoot, fx, fy)
        if (Math.abs(p.x - barX) > 0.5) barX = p.x
        if (Math.abs(p.y - barY) > 0.5) barY = p.y
        const c = root.mapFromItem(panelRoot, panelRoot.width / 2, 0).x
        if (Math.abs(c - dockCenterX) > 0.5) dockCenterX = c
    }
    // Plasma can re-layout the panel later (unlock, screen changes): recheck.
    Timer { interval: 250; repeat: true; running: root.panelRoot !== null; onTriggered: root.syncPanelFrame() }
    Timer {
        // keeps the blur region glued to the bar while it resizes during zoom
        interval: 16
        repeat: true
        running: root.panelRoot !== null && (root.hovering || root.zoomAmount > 0.001 || root.dragRow >= 0)
        onTriggered: root.syncPanelFrame()
    }
    Timer {
        id: hookTimer
        interval: 400
        onTriggered: root.hookPanel()
    }
    Component.onCompleted: hookTimer.start()
    onWidthChanged: syncPanelFrame()
    onHeightChanged: syncPanelFrame()
    onXChanged: syncPanelFrame()
    onYChanged: syncPanelFrame()

    // ---- Application Dashboard ----------------------------------------------------
    // The stock "Application Dashboard" widget lives (hidden) in this panel;
    // the dock's first icon opens it through its global shortcut action.
    function findDashboard(item) {
        if (!item) return null
        if (item.plasmoid && item.plasmoid.pluginName === "org.kde.plasma.kickerdash") return item
        for (const ch of item.children) {
            const r = findDashboard(ch)
            if (r) return r
        }
        return null
    }
    property int dashboardId: -1
    function hideDashboardApplet() {
        const containmentItem = findContainmentItem()
        const dash = findDashboard(containmentItem)
        if (!dash) return
        dashboardId = dash.plasmoid.id
        // Leave its panel slot alone (changing it makes Plasma re-layout the
        // panel); just make the widget invisible and unclickable.
        dash.opacity = 0
        dash.enabled = false
    }
    function hasDock(item) {
        for (const ch of item.children) if (isAncestorOf(ch, root)) return true
        return false
    }
    function isAncestorOf(a, b) {
        let p = b
        while (p) { if (p === a) return true; p = p.parent }
        return false
    }
    function findContainmentItem() {
        let p = root.parent
        while (p) {
            if (p.plasmoid && p.plasmoid.pluginName === "org.kde.panel") return p
            p = p.parent
        }
        return null
    }
    function openDashboard() {
        hovering = false        // a fullscreen window is about to cover the dock
        if (dashboardId < 0) hideDashboardApplet()
        if (dashboardId < 0) { openAppLauncher(); return }
        shell.run("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel "
                  + "/component/plasmashell org.kde.kglobalaccel.Component.invokeShortcut "
                  + "string:" + sh("activate widget " + dashboardId))
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
        let x = dockCenterX - total / 2 + slot * (baseSize + spacing) + baseSize / 2
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

    // Task row whose resting slot is nearest to x (root coordinates).
    function taskRowAt(x) {
        let best = -1, bestD = 1e9
        for (let i = 0; i < tasksModel.count; ++i) {
            const d = Math.abs(x - restingCenter(i + 1))
            if (d < bestD) { bestD = d; best = i }
        }
        return best
    }

    // ---- view ----------------------------------------------------------------
    fullRepresentation: Item {
        id: stage
        // Fixed size hints: the panel must never size or place this widget from
        // its children, or moving the bar would move the widget (feedback loop).
        implicitWidth: 0
        implicitHeight: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 200
        Layout.preferredWidth: 200
        Layout.minimumHeight: 0
        Layout.preferredHeight: 0

        HoverHandler {
            id: hover
            property point last: Qt.point(-1, -1)
            onPointChanged: {
                const p = point.position
                last = p
                const zoomTop = bar.y + bar.height - root.pad - root.maxSize - 4
                // Only the bar itself starts the zoom; once zooming, the raised
                // icons above it keep it going. A small side margin, no more.
                const inX = p.x >= bar.x - root.pad && p.x <= bar.x + bar.width + root.pad
                root.pointerX = p.x
                root.hovering = hovered && inX && p.y >= (root.hovering ? zoomTop : bar.y)
                if (root.hovering) staleTimer.restart()
            }
            onHoveredChanged: if (!hovered) root.hovering = false
        }

        // Safety net: if the pointer left without the dock getting a final
        // event (fast exit, a fullscreen window opening on top), and its last
        // known spot wasn't on an icon or the bar, un-zoom instead of sticking.
        Timer {
            id: staleTimer
            interval: 400
            onTriggered: {
                const p = hover.last
                const onBar = p.x >= bar.x && p.x <= bar.x + bar.width && p.y >= bar.y
                const r = icons.mapToItem(stage, 0, 0)
                const onIcons = p.x >= r.x && p.x <= r.x + icons.width
                                && p.y >= r.y + icons.height - root.baseSize * root.maxZoom
                if (!hover.hovered || !(onBar || onIcons)) root.hovering = false
            }
        }
        Connections {
            target: root
            function onHoveringChanged() { if (!root.hovering) staleTimer.stop() }
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
        // No border: just a frosted navy tint over KWin's blur.
        Rectangle {
            id: bar
            x: root.barX
            y: root.barY
            height: root.barH
            width: icons.width + 2 * root.pad
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.11, 0.2, 0.26, root.cfg.bgOpacity) }
                GradientStop { position: 1.0; color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, Math.min(1, root.cfg.bgOpacity + 0.1)) }
            }
            Component.onCompleted: root.barItem = bar
            onWidthChanged: root.syncPanelFrame()
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
                iconSource: "org.kde.plasma.kickerdash"
                label: "Application Dashboard"
                onLeftClicked: root.openDashboard()
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
            preventStealing: true          // keep the drag; don't let the panel take it
            property real pressX: 0
            property bool moved: false

            onContainsMouseChanged: containsMouse ? item.hoverStarted() : item.hoverEnded()

            onPressed: (e) => {
                pressX = mapToItem(root, e.x, e.y).x
                moved = false
            }
            onPositionChanged: (e) => {
                if (!pressed || pressedButtons !== Qt.LeftButton || item.taskRow < 0) return
                const x = mapToItem(root, e.x, e.y).x
                if (!moved && Math.abs(x - pressX) > 8) {
                    moved = true
                    root.dragRow = item.taskRow
                    root.hidePreview()
                    previewDelay_stop()
                }
                if (moved) {
                    root.pointerX = x
                    const target = root.taskRowAt(x)
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
            onCanceled: {
                if (moved) {
                    tasksModel.syncLaunchers()
                    root.dragRow = -1
                    moved = false
                }
            }
            function previewDelay_stop() { item.hoverEnded() }
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
