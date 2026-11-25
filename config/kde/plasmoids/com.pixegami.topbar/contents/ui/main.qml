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
    // One value per line, always the same number of lines (missing values are
    // printed as empty lines so the positions never shift).
    readonly property string statsCmd:
        'head -1 /proc/stat; '
        + 'grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree):" /proc/meminfo; '
        + 'df -B1 --output=size,used / | tail -1; '
        + 'echo "$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)"; '
        + 'echo "$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)"; '
        + 'echo "$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"; '
        + 'w=$(ls /sys/class/net | grep -m1 "^wl"); '
        + 'echo "$w $(cat /sys/class/net/$w/statistics/rx_bytes 2>/dev/null) $(cat /sys/class/net/$w/statistics/tx_bytes 2>/dev/null)"; '
        + 'l=$(iw dev "$w" link 2>/dev/null); '
        + 'echo "$(echo "$l" | sed -n "s/^[[:space:]]*SSID: //p")"; '
        + 'echo "$(echo "$l" | awk \'/signal:/{print $2}\')"'
    property real cpu: -1          // %
    property real memUsed: 0       // bytes
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property int battery: -1       // %
    property string batteryStatus: ""
    property real tempC: -1
    property string wifiName: ""
    property real wifiSignal: -1   // 0..100
    property real rxRate: -1       // bytes / s
    property real txRate: -1
    property var cpuPrev: null
    property var netPrev: null

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
        swapTotal = kb(l[3])
        swapUsed = swapTotal - kb(l[4])
        const d = (l[5] || "").trim().split(/\s+/).map(Number)
        if (d.length === 2) { diskTotal = d[0]; diskUsed = d[1] }
        battery = (l[6] || "").trim().length ? Number(l[6]) : -1
        batteryStatus = (l[7] || "").trim()
        tempC = (l[8] || "").trim().length ? Math.round(Number(l[8]) / 1000) : -1

        const n = (l[9] || "").trim().split(/\s+/)
        const now = Date.now()
        if (n.length === 3 && n[1].length) {
            const rx = Number(n[1]), tx = Number(n[2])
            if (netPrev && netPrev.iface === n[0] && now > netPrev.t) {
                const dt = (now - netPrev.t) / 1000
                rxRate = Math.max(0, (rx - netPrev.rx) / dt)
                txRate = Math.max(0, (tx - netPrev.tx) / dt)
            }
            netPrev = { iface: n[0], rx: rx, tx: tx, t: now }
        }
        wifiName = (l[10] || "").trim()
        const dbm = Number((l[11] || "").trim())
        // -90 dBm (unusable) .. -40 dBm (excellent) -> 0..100
        wifiSignal = (l[11] || "").trim().length ? Math.max(0, Math.min(100, (dbm + 90) * 2)) : -1
    }
    function gb(bytes) { return (bytes / 1073741824).toFixed(bytes >= 1e11 ? 0 : 1) }
    function speed(bps) {
        if (bps < 0) return "…"
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(bps >= 102400 ? 0 : 1) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    // Tile contents. The tiles themselves are created once (fixed count) and
    // only these values change, so the bars animate from where they are
    // instead of being rebuilt from empty on every refresh.
    function tile(i) {
        switch (i) {
        case 0: return { label: "CPU",
            value: cpu < 0 ? "…" : cpu + "%" + (tempC > 0 ? "  ·  " + tempC + "°C" : ""),
            frac: Math.max(0, cpu) / 100, warnHigh: true }
        case 1: return { label: "Memory",
            value: memTotal ? gb(memUsed) + " / " + gb(memTotal) + " GB" : "…",
            frac: memTotal ? memUsed / memTotal : 0, warnHigh: true }
        case 2: return { label: "Swap",
            value: swapTotal ? gb(swapUsed) + " / " + gb(swapTotal) + " GB" : "off",
            frac: swapTotal ? swapUsed / swapTotal : 0, warnHigh: true }
        case 3: return { label: "Disk",
            value: diskTotal ? gb(diskUsed) + " / " + gb(diskTotal) + " GB" : "…",
            frac: diskTotal ? diskUsed / diskTotal : 0, warnHigh: true }
        case 4: return { label: "Battery",
            value: battery < 0 ? "—" : battery + "%"
                   + (batteryStatus === "Charging" ? "  ·  charging" : batteryStatus === "Full" ? "  ·  full" : ""),
            frac: Math.max(0, battery) / 100, warnLow: true }
        case 5: return { label: "Wi-Fi" + (wifiName ? "  ·  " + wifiName : ""),
            value: wifiName || rxRate >= 0 ? "↓ " + speed(rxRate) + "   ↑ " + speed(txRate) : "offline",
            frac: Math.max(0, wifiSignal) / 100, warnLow: true }
        }
        return { label: "", value: "", frac: 0 }
    }

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
                                model: 6     // fixed tiles; contents come from root.tile(index)
                                delegate: ColumnLayout {
                                    id: tileItem
                                    required property int index
                                    readonly property var modelData: root.tile(index)
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 4
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: tileItem.modelData.label; color: root.subText; font.pixelSize: 10; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Item { Layout.fillWidth: true }
                                    }
                                    Text {
                                        text: tileItem.modelData.value
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
                                            width: parent.width * Math.min(1, tileItem.modelData.frac)
                                            height: parent.height
                                            radius: 2
                                            // mint normally, amber when high (battery: when low)
                                            color: (tileItem.modelData.warnLow ? (tileItem.modelData.frac > 0 && tileItem.modelData.frac < 0.2)
                                                                               : tileItem.modelData.frac > 0.85)
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
    // Each top panel ("island") is wider than its contents: left 0..830,
    // centre 830..1090, right 1090..1920, so together they cover the screen.
    // While floating, the background (tint + KWin blur shape) hugs the contents
    // as a rounded pill. When a window touches the bar, Plasma animates the
    // panel's floatingness 1 -> 0; we use that as `merge` and grow each pill to
    // fill its whole panel, so the three meet and become one flat bar. The
    // panel content is pinned so it never moves while the background grows.
    property Item panelRoot: null
    property Item panelFrame: null
    property var panelFrames: []
    property Item tint: null
    property real islandL: 0
    property real islandR: 0
    readonly property real merge: panelRoot ? Math.max(0, Math.min(1, 1 - panelRoot.floatingness)) : 0
    readonly property int islandPad: 8

    function findPanelRoot() {
        let p = root.parent
        while (p) {
            if (p.floatingTranslucentItemOffset !== undefined) return p
            p = p.parent
        }
        return null
    }
    function findContainmentItem() {
        let p = root.parent
        while (p) {
            if (p.plasmoid && p.plasmoid.pluginName === "org.kde.panel") return p
            p = p.parent
        }
        return null
    }
    // Plasma centres the content on the background frame; we resize that frame,
    // so pin the content to the panel (horizontally) instead.
    function pinContainment() {
        const c = findContainmentItem()
        const cp = c ? c.parent : null
        if (!cp || cp.parent !== panelRoot || !panelFrame) return
        cp.anchors.centerIn = undefined
        cp.x = Qt.binding(() => Math.round((panelRoot.width - cp.width) / 2))
        cp.y = Qt.binding(() => Math.round(panelFrame.y + (panelFrame.height - cp.height) / 2))
    }
    // Horizontal extent of the real widgets (spacers and this invisible styler
    // don't count), in panel coordinates.
    function collectApplets(item, out, depth) {
        if (!item || depth > 10) return
        if (item.plasmoid && item.plasmoid.pluginName && item !== root
                && item.plasmoid.pluginName !== "org.kde.panel") {
            const n = item.plasmoid.pluginName
            if (n !== "org.kde.plasma.panelspacer" && !(n === "com.pixegami.topbar" && !item.plasmoid.configuration.showLogo)
                    && item.visible && item.width > 1)
                out.push(item)
            return
        }
        for (const ch of item.children) collectApplets(ch, out, depth + 1)
    }
    function measureIsland() {
        if (!panelRoot) return
        const list = []
        collectApplets(findContainmentItem(), list, 0)
        if (showLogo) list.push(root)
        if (!list.length) return
        let l = 1e9, r = -1e9
        for (const it of list) {
            const p = it.mapToItem(panelRoot, 0, 0)
            l = Math.min(l, p.x); r = Math.max(r, p.x + it.width)
        }
        const nl = Math.max(0, Math.round(l - islandPad))
        const nr = Math.min(panelRoot.width, Math.round(r + islandPad))
        if (nl !== islandL) islandL = nl
        if (nr !== islandR) islandR = nr
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
        panelFrame = master
        panelFrames = frames.filter(f => f === master || f.anchors.fill === master)
        for (const f of panelFrames) {
            f.imagePath = "dialogs/background"    // rounded blur shape, like the dock
            f.opacity = 0
            // rounded while floating, square once merged into one bar
            if (f.enabledBorders !== undefined) f.enabledBorders = Qt.binding(() => root.merge > 0.5 ? 0 : 15)
        }
        pinContainment()
        measureIsland()
        // background: island pill -> whole panel, following Plasma's own animation
        master.x = Qt.binding(() => Math.round(root.islandL * (1 - root.merge)))
        master.width = Qt.binding(() => Math.round(root.islandR + (panelRoot.width - root.islandR) * root.merge)
                                        - Math.round(root.islandL * (1 - root.merge)))
        if (!tint) tint = Qt.createQmlObject('import QtQuick; Rectangle { z: -1 }', panelRoot, "pixegamiTint")
        tint.anchors.fill = master
        tint.radius = Qt.binding(() => 12 * (1 - root.merge))
        tint.color = Qt.binding(() => Qt.rgba(root.navy.r, root.navy.g, root.navy.b, Plasmoid.configuration.bgOpacity))
    }
    Timer { interval: 400; running: true; onTriggered: root.stylePanel() }
    Timer {
        // keep up with widgets changing size (app menu, tray icons, clock text)
        interval: 250; repeat: true; running: root.panelRoot !== null
        onTriggered: {
            root.measureIsland()
            for (const f of root.panelFrames) if (f.opacity !== 0) f.opacity = 0
        }
    }
    Component.onDestruction: if (tint) tint.destroy()
}
