/*
 * Pixegami Bar: top-bar islands in the Pixegami style.
 *
 * One widget, two jobs:
 * - Styles the panel it sits in: the theme's panel background is made
 *   invisible but kept as the (rounded) blur shape, so KWin blurs behind the
 *   panel, and a navy glass tint is drawn under the panel's widgets.
 *   Each top island (left / clock / tray) is its own fit-to-content floating
 *   panel with one of these widgets in it.
 * - With showLogo (left island): the Pixegami logo button, which opens the
 *   user menu (profile picture, name, power and system actions).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color navy: "#0c1c25"
    readonly property color navyLight: "#152535"
    readonly property color mint: "#86ffaf"
    readonly property color textColor: "#e8f4f0"
    readonly property color subText: "#8fa8a0"
    readonly property url logo: Qt.resolvedUrl("../images/logo.svg")
    readonly property bool showLogo: Plasmoid.configuration.showLogo

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""

    // ---- user / system info -------------------------------------------------------
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.infoCmd) {
                const l = (data["stdout"] || "").split("\n")
                root.realName = l[0] || ""
                root.userName = l[1] || ""
                root.hostName = l[2] || ""
                root.osName = l[3] || ""
                root.uptime = (l[4] || "").replace(/^up /, "")
            } else if (source === root.statsCmd) {
                root.parseStats(data["stdout"] || "")
            }
            disconnectSource(source)
        }
        function run(cmd) { connectSource(cmd) }
    }
    readonly property string infoCmd:
        'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; echo "$USER"; hostname; '
        + '. /etc/os-release; echo "$PRETTY_NAME"; uptime -p'
    property string realName: ""
    property string userName: ""
    property string hostName: ""
    property string osName: ""
    property string uptime: ""
    readonly property string avatar: userName
        ? "file:///var/lib/AccountsService/icons/" + userName : ""
    Component.onCompleted: if (showLogo) shell.run(infoCmd)

    // ---- live system stats (only polled while the menu is open) -------------------
    readonly property string statsCmd:
        'head -1 /proc/stat; grep -E "^(MemTotal|MemAvailable):" /proc/meminfo; '
        + 'df -B1 --output=size,used / | tail -1; '
        + 'cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; '
        + 'cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; '
        + 'cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null'
    property real cpu: -1          // %
    property real memUsed: 0       // bytes
    property real memTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property int battery: -1       // %
    property string batteryStatus: ""
    property real tempC: -1
    property var cpuPrev: null

    function parseStats(out) {
        const l = out.split("\n")
        const c = (l[0] || "").trim().split(/\s+/).slice(1).map(Number)
        if (c.length >= 4) {
            const idle = c[3] + (c[4] || 0)
            const total = c.reduce((a, b) => a + b, 0)
            if (cpuPrev && total > cpuPrev.total) {
                cpu = Math.round(100 * (1 - (idle - cpuPrev.idle) / (total - cpuPrev.total)))
            }
            cpuPrev = { idle: idle, total: total }
        }
        const kb = (s) => Number(((s || "").match(/(\d+)/) || [0, 0])[1]) * 1024
        memTotal = kb(l[1])
        memUsed = memTotal - kb(l[2])
        const d = (l[3] || "").trim().split(/\s+/).map(Number)
        if (d.length === 2) { diskTotal = d[0]; diskUsed = d[1] }
        battery = l[4] && l[4].trim().length ? Number(l[4]) : -1
        batteryStatus = (l[5] || "").trim()
        tempC = l[6] && l[6].trim().length ? Math.round(Number(l[6]) / 1000) : -1
    }
    function gb(bytes) { return (bytes / 1073741824).toFixed(bytes >= 1e11 ? 0 : 1) }

    Timer {
        interval: 1500
        repeat: true
        triggeredOnStart: true
        running: root.menuWindow !== null && root.menuWindow.visible
        onTriggered: shell.run(root.statsCmd)
    }

    function dbus(dest, path, method) {
        return "dbus-send --session --type=method_call --dest=" + dest + " " + path + " " + method
    }
    // The menu lives inside the bar representation, so its id isn't visible
    // here; it registers itself in menuWindow.
    property var menuWindow: null
    function act(cmd) {
        if (menuWindow) menuWindow.visible = false
        shell.run(cmd)
    }

    // Opens the Application Dashboard (the hidden kickerdash widget in the dock
    // panel) through its global-shortcut action. Plasma's activateLauncherMenu
    // doesn't reach it, so look its widget id up and invoke "activate widget N".
    readonly property string dashboardCmd:
        'id=$(awk \'/^\\[Containments\\]\\[[0-9]+\\]\\[Applets\\]\\[[0-9]+\\]$/{s=$0} '
        + '/^plugin=org.kde.plasma.kickerdash$/{print s}\' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" '
        + '| grep -o "[0-9]*\\]$" | tr -d "]" | head -1); '
        + 'dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/plasmashell '
        + 'org.kde.kglobalaccel.Component.invokeShortcut string:"activate widget $id"'

    // keys: shown as key caps. "Win" is the Windows / Super key (KDE calls it Meta).
    // The power shortcuts are real global shortcuts (set in kglobalshortcutsrc):
    // Sleep Win+Alt+S, Restart Win+Alt+R, Shut Down Win+Alt+Q; Win+L and
    // Ctrl+Alt+Del are KDE's defaults.
    readonly property var menuModel: [
        { icon: "view-app-grid-symbolic", text: "Applications", keys: ["Win"], cmd: dashboardCmd },
        { icon: "search", text: "Search", keys: ["Alt", "Space"],
          cmd: dbus("org.kde.krunner", "/App", "org.kde.krunner.App.display") },
        { separator: true },
        { icon: "configure-symbolic", text: "System Settings", cmd: "systemsettings" },
        { icon: "user-identity", text: "Account", cmd: "systemsettings kcm_users" },
        { icon: "help-about", text: "About This System", cmd: "kinfocenter" },
        { separator: true },
        { icon: "system-lock-screen", text: "Lock Screen", keys: ["Win", "L"], cmd: "loginctl lock-session" },
        { icon: "system-suspend", text: "Sleep", keys: ["Win", "Alt", "S"], cmd: "systemctl suspend" },
        { icon: "system-reboot", text: "Restart…", keys: ["Win", "Alt", "R"],
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot") },
        { icon: "system-shutdown", text: "Shut Down…", keys: ["Win", "Alt", "Q"],
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptShutDown") },
        { icon: "system-log-out", text: "Log Out…", keys: ["Ctrl", "Alt", "Del"],
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptLogout") }
    ]

    // ---- in the bar: the logo button (or nothing, when only styling) -------------------
    fullRepresentation: MouseArea {
        id: button
        hoverEnabled: root.showLogo
        enabled: root.showLogo
        visible: root.showLogo
        Layout.minimumWidth: root.showLogo ? height + 6 : 0
        Layout.preferredWidth: root.showLogo ? height + 6 : 0
        Layout.maximumWidth: root.showLogo ? height + 6 : 0
        onClicked: {
            if (!menu.visible) shell.run(root.infoCmd)
            menu.visible = !menu.visible
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.height - 6
            height: parent.height - 6
            radius: 9
            color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b,
                           menu.visible ? 0.18 : (button.containsMouse ? 0.10 : 0))
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.height * 0.62)
            height: width
            source: root.logo
            roundToIconSize: false
            scale: button.pressed ? 0.92 : (button.containsMouse ? 1.06 : 1)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // ---- the user menu: our own window, drawn fully in Pixegami navy -------------
        PlasmaCore.Dialog {
            id: menu
            visualParent: button
            location: PlasmaCore.Types.TopEdge
            type: PlasmaCore.Dialog.PopupMenu
            flags: Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true
            visible: false
            Component.onCompleted: root.menuWindow = menu

            mainItem: Rectangle {
                id: card
                width: Kirigami.Units.gridUnit * 19
                height: content.implicitHeight + 20
                radius: 16
                color: Qt.rgba(root.navy.r, root.navy.g, root.navy.b, 0.97)
                border.width: 1
                border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.12)
                focus: true
                Keys.onEscapePressed: menu.visible = false

                ColumnLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 2

                    // header: profile picture, name, account
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 6
                        Layout.bottomMargin: 10
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            Rectangle {   // mint ring
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: root.mint
                            }
                            Kirigami.Avatar {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: root.avatar
                                name: root.realName || root.userName
                            }
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: root.realName || root.userName
                                color: root.textColor
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.userName ? root.userName + "@" + root.hostName : ""
                                color: root.mint
                                font.pixelSize: 12
                            }
                            Text {
                                text: root.uptime ? "up " + root.uptime : root.osName
                                color: root.subText
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // system stats: 2x2 tiles, click opens System Monitor
                    Rectangle {
                        id: statsBox
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.bottomMargin: 6
                        implicitHeight: statsGrid.implicitHeight + 16
                        radius: 12
                        color: statsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        GridLayout {
                            id: statsGrid
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            columns: 2
                            columnSpacing: 14
                            rowSpacing: 10

                            Repeater {
                                model: [
                                    { label: "CPU",
                                      value: root.cpu < 0 ? "…" : root.cpu + "%" + (root.tempC > 0 ? "  ·  " + root.tempC + "°C" : ""),
                                      frac: Math.max(0, root.cpu) / 100 },
                                    { label: "Memory",
                                      value: root.memTotal ? root.gb(root.memUsed) + " / " + root.gb(root.memTotal) + " GB" : "…",
                                      frac: root.memTotal ? root.memUsed / root.memTotal : 0 },
                                    { label: "Disk",
                                      value: root.diskTotal ? root.gb(root.diskUsed) + " / " + root.gb(root.diskTotal) + " GB" : "…",
                                      frac: root.diskTotal ? root.diskUsed / root.diskTotal : 0 },
                                    { label: "Battery",
                                      value: root.battery < 0 ? "—" : root.battery + "%"
                                             + (root.batteryStatus === "Charging" ? "  ·  charging"
                                                : root.batteryStatus === "Full" ? "  ·  full" : ""),
                                      frac: Math.max(0, root.battery) / 100 }
                                ]
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 4
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: modelData.label; color: root.subText; font.pixelSize: 10; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6 }
                                        Item { Layout.fillWidth: true }
                                    }
                                    Text {
                                        text: modelData.value
                                        color: root.textColor
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {   // bar
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        Rectangle {
                                            width: parent.width * Math.min(1, modelData.frac)
                                            height: parent.height
                                            radius: 2
                                            // mint normally, amber when high (battery: when low)
                                            color: (modelData.label === "Battery" ? modelData.frac < 0.2 && root.battery >= 0 : modelData.frac > 0.85)
                                                   ? "#ffbc51" : root.mint
                                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: statsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.act("plasma-systemmonitor")
                        }
                    }

                    Repeater {
                        model: root.menuModel
                        delegate: Item {
                            id: entry
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: modelData.separator ? 11 : 34

                            Rectangle {
                                visible: !!entry.modelData.separator
                                anchors.centerIn: parent
                                width: parent.width - 12
                                height: 1
                                color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.12)
                            }
                            Rectangle {
                                visible: !entry.modelData.separator
                                anchors.fill: parent
                                radius: 9
                                color: rowMouse.containsMouse ? Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.13) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 11
                                    Kirigami.Icon {
                                        source: entry.modelData.icon || ""
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        isMask: true
                                        color: rowMouse.containsMouse ? root.mint : root.textColor
                                    }
                                    Text {
                                        text: entry.modelData.text || ""
                                        color: rowMouse.containsMouse ? root.mint : root.textColor
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }
                                    Row {   // shortcut as key caps
                                        spacing: 3
                                        Repeater {
                                            model: entry.modelData.keys || []
                                            Rectangle {
                                                required property string modelData
                                                width: Math.max(18, cap.implicitWidth + 10)
                                                height: 18
                                                radius: 4
                                                color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.18)
                                                Text {
                                                    id: cap
                                                    anchors.centerIn: parent
                                                    text: parent.modelData
                                                    color: rowMouse.containsMouse ? root.mint : root.subText
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.act(entry.modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- panel styling ----------------------------------------------------------------
    property Item panelRoot: null
    property var panelFrames: []
    property Item tint: null

    function findPanelRoot() {
        let p = root.parent
        while (p) {
            if (p.floatingTranslucentItemOffset !== undefined) return p
            p = p.parent
        }
        return null
    }
    function stylePanel() {
        if (!Plasmoid.configuration.stylePanel) return
        panelRoot = findPanelRoot()
        if (!panelRoot) return
        const frames = []
        for (const ch of panelRoot.children) if (ch.imagePath !== undefined) frames.push(ch)
        let master = null
        for (const f of frames) {
            const a = f.anchors.fill
            if (a && frames.indexOf(a) >= 0) { master = a; break }
        }
        if (!master) return
        panelFrames = frames.filter(f => f === master || f.anchors.fill === master)
        for (const f of panelFrames) {
            f.imagePath = "dialogs/background"    // rounded blur shape, like the dock
            f.opacity = 0
        }
        if (!tint) tint = Qt.createQmlObject('import QtQuick; Rectangle { z: -1 }', panelRoot, "pixegamiTint")
        tint.anchors.fill = master
        tint.radius = Qt.binding(() => panelRoot.floatingness > 0.5 ? 12 : 0)
        tint.color = Qt.binding(() => Qt.rgba(root.navy.r, root.navy.g, root.navy.b, Plasmoid.configuration.bgOpacity))
    }
    Timer { interval: 400; running: true; onTriggered: root.stylePanel() }
    Timer {
        interval: 2000; repeat: true; running: root.panelRoot !== null
        onTriggered: { for (const f of root.panelFrames) if (f.opacity !== 0) f.opacity = 0 }
    }
    Component.onDestruction: if (tint) tint.destroy()
}
