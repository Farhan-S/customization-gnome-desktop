/*
 * Pixegami Dock: a macOS-style dock for Plasma 6 with zoom on hover.
 *
 * Lives in a tall, transparent bottom panel: the dock bar is drawn at the
 * bottom and the empty space above gives the zoomed icons room to grow.
 * Apps come from Plasma's own task manager model, so pinned launchers,
 * running windows, activation and closing all behave like the stock panel.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // ---- look ------------------------------------------------------------
    readonly property color navy: "#0c1c25"
    readonly property color navyLight: "#152535"
    readonly property color mint: "#86ffaf"
    readonly property color amber: "#ffbc51"
    readonly property color textColor: "#e8f4f0"

    readonly property int baseSize: Plasmoid.configuration.iconSize
    readonly property real maxZoom: Plasmoid.configuration.maxZoom
    readonly property int spacing: Math.round(baseSize / 6)
    readonly property int pad: Math.round(baseSize / 5)       // bar padding
    readonly property int bottomGap: 8                          // bar <-> screen edge
    readonly property real influence: baseSize * 3              // zoom reach (px)

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

        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(Plasmoid.configuration.launchers)) {
                Plasmoid.configuration.launchers = launcherList
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            const saved = Plasmoid.configuration.launchers
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

    function openAppLauncher() {
        shell.run("dbus-send --session --type=method_call --dest=org.kde.plasmashell "
                  + "/PlasmaShell org.kde.PlasmaShell.activateLauncherMenu")
    }

    function role(idx, r) {
        return tasksModel.data(idx, r)
    }

    // Left click: launch, focus, minimize, or cycle a group's windows.
    function activate(row) {
        const idx = tasksModel.makeModelIndex(row)
        const isLauncher = role(idx, TaskManager.AbstractTasksModel.IsLauncher)
        const children = role(idx, TaskManager.AbstractTasksModel.ChildCount) || 0
        const isActive = role(idx, TaskManager.AbstractTasksModel.IsActive)

        if (isLauncher || children <= 1) {
            if (isActive && !isLauncher) {
                tasksModel.requestToggleMinimized(idx)
            } else {
                tasksModel.requestActivate(idx)
            }
            return
        }
        // Group: focus the most recent window, or cycle if already focused.
        let activeChild = -1, recent = 0, recentTime = 0
        for (let i = 0; i < children; ++i) {
            const c = tasksModel.makeModelIndex(row, i)
            if (role(c, TaskManager.AbstractTasksModel.IsActive)) activeChild = i
            const t = role(c, TaskManager.AbstractTasksModel.LastActivated)
            if (t && t > recentTime) { recentTime = t; recent = i }
        }
        const target = activeChild >= 0 ? (activeChild + 1) % children : recent
        tasksModel.requestActivate(tasksModel.makeModelIndex(row, target))
    }

    // ---- hover zoom ----------------------------------------------------------
    // Zoom is computed from each icon's *resting* position, so the icons don't
    // chase the pointer as the dock widens.
    readonly property int itemCount: tasksModel.count + 1      // + app launcher
    property real pointerX: -1
    property bool zooming: false

    function restingCenter(i) {
        const total = itemCount * baseSize + (itemCount - 1) * spacing
        return (width - total) / 2 + i * (baseSize + spacing) + baseSize / 2
    }
    function zoomFor(i) {
        if (!zooming) return 1
        const d = Math.abs(pointerX - restingCenter(i))
        if (d >= influence) return 1
        const s = (1 + Math.cos(Math.PI * d / influence)) / 2
        return 1 + (maxZoom - 1) * s
    }

    fullRepresentation: Item {
        id: stage

        HoverHandler {
            id: hover
            onPointChanged: {
                const p = point.position
                const barTop = stage.height - root.bottomGap - bar.height
                const zoomTop = stage.height - root.bottomGap - root.pad - root.baseSize * root.maxZoom
                const inX = p.x >= bar.x - root.baseSize && p.x <= bar.x + bar.width + root.baseSize
                // Start zooming on the bar itself; keep zooming over the raised icons.
                root.zooming = hovered && inX && p.y >= (root.zooming ? zoomTop : barTop)
                root.pointerX = p.x
            }
            onHoveredChanged: if (!hovered) root.zooming = false
        }

        // The dock bar.
        Rectangle {
            id: bar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomGap
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.baseSize + 2 * root.pad
            width: icons.width + 2 * root.pad
            radius: 18
            color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, 0.9)
            border.width: 1
            border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.25)

            // faint top highlight for depth
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                height: parent.height / 2
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.03)
            }
        }

        Row {
            id: icons
            anchors.bottom: bar.bottom
            anchors.bottomMargin: root.pad
            anchors.horizontalCenter: bar.horizontalCenter
            height: root.baseSize * root.maxZoom
            spacing: root.spacing

            DockIcon {
                zoom: root.zoomFor(0)
                iconSource: "start-here-kde-plasma"
                label: "Applications"
                running: false
                onLeftClicked: root.openAppLauncher()
            }

            Repeater {
                model: tasksModel
                delegate: DockIcon {
                    id: task
                    required property int index
                    required property var model

                    zoom: root.zoomFor(index + 1)
                    iconSource: model.decoration
                    label: model.AppName || model.display || ""
                    running: !model.IsLauncher && !model.IsStartup
                    active: model.IsActive === true
                    windows: model.ChildCount || (running ? 1 : 0)
                    attention: model.IsDemandingAttention === true
                    starting: model.IsStartup === true

                    onLeftClicked: root.activate(index)
                    onMiddleClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(index))
                    onRightClicked: menu.openRelative()

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
                            readonly property bool pinned: task.model.IsLauncher || task.model.HasLauncher
                            text: pinned ? "Unpin from Dock" : "Pin to Dock"
                            icon: pinned ? "window-unpin" : "window-pin"
                            onClicked: {
                                if (pinned) {
                                    tasksModel.requestRemoveLauncher(task.model.LauncherUrlWithoutIcon)
                                } else {
                                    tasksModel.requestAddLauncher(task.model.LauncherUrl)
                                }
                            }
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
        }
    }

    // ---- one dock icon --------------------------------------------------------
    component DockIcon: Item {
        id: item
        property real zoom: 1
        property var iconSource
        property string label
        property bool running: false
        property bool active: false
        property int windows: 0
        property bool attention: false
        property bool starting: false

        signal leftClicked()
        signal middleClicked()
        signal rightClicked()

        width: root.baseSize * zoom
        height: root.baseSize * zoom
        y: parent.height - height

        Behavior on zoom {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        Kirigami.Icon {
            id: glyph
            anchors.fill: parent
            source: item.iconSource
            active: mouse.containsMouse
            transform: Translate { id: lift; y: 0 }
        }

        // Bounce while the app is starting.
        SequentialAnimation {
            running: item.starting
            loops: Animation.Infinite
            NumberAnimation { target: lift; property: "y"; to: -root.baseSize * 0.4; duration: 280; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0; duration: 280; easing.type: Easing.InQuad }
            onRunningChanged: if (!running) lift.y = 0
        }

        // Running indicator: one dot per window (max 3), wide pill when focused.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: Math.max(2, root.pad / 2 - 2)
            spacing: 3
            visible: item.running
            Repeater {
                model: item.active ? 1 : Math.min(item.windows, 3)
                Rectangle {
                    width: item.active ? 14 : 5
                    height: 5
                    radius: 2.5
                    color: item.attention ? root.amber : root.mint
                    opacity: item.active ? 1 : 0.75
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }

        // Name label above the hovered icon.
        Rectangle {
            visible: mouse.containsMouse && item.label.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            width: name.implicitWidth + 18
            height: name.implicitHeight + 8
            radius: 7
            color: root.navy
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

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (e) => {
                if (e.button === Qt.LeftButton) item.leftClicked()
                else if (e.button === Qt.MiddleButton) item.middleClicked()
                else item.rightClicked()
            }
        }
    }
}
