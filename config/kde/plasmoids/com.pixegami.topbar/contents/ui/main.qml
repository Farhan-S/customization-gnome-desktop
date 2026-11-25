/*
 * Pixegami Bar: the left-hand logo button of the top bar, plus panel styling.
 *
 * - Logo button opens the Pixegami menu (applications, search, settings,
 *   about, lock / sleep / restart / shut down / log out).
 * - Styles the panel it lives in to match the Pixegami Dock: the theme's
 *   panel background is made invisible (KWin still blurs behind it) and a
 *   semi-transparent navy tint with rounded corners is drawn instead.
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
    readonly property color mint: "#86ffaf"
    readonly property color textColor: "#e8f4f0"
    readonly property color subText: "#8fa8a0"
    readonly property url logo: Qt.resolvedUrl("../images/logo.svg")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: "Pixegami"
    toolTipSubText: "Applications, settings and power"

    // ---- shell commands ---------------------------------------------------------
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.infoCmd) {
                const lines = (data["stdout"] || "").trim().split("\n")
                root.userHost = lines[0] || ""
                root.osName = lines[1] || ""
                root.uptime = (lines[2] || "").replace(/^up /, "")
            }
            disconnectSource(source)
        }
        function run(cmd) { connectSource(cmd) }
    }
    readonly property string infoCmd: 'echo "$USER@$(hostname)"; . /etc/os-release; echo "$PRETTY_NAME"; uptime -p'
    property string userHost: ""
    property string osName: ""
    property string uptime: ""
    onExpandedChanged: if (root.expanded) shell.run(root.infoCmd)

    function dbus(dest, path, method) {
        return "dbus-send --session --type=method_call --dest=" + dest + " " + path + " " + method
    }
    function act(cmd) {
        root.expanded = false
        shell.run(cmd)
    }

    readonly property var menuModel: [
        { section: true },
        { icon: "applications-all", text: "Applications", hint: "Meta",
          cmd: dbus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.activateLauncherMenu") },
        { icon: "search", text: "Search", hint: "Alt+Space",
          cmd: dbus("org.kde.krunner", "/App", "org.kde.krunner.App.display") },
        { icon: "preferences-system", text: "System Settings", cmd: "systemsettings" },
        { icon: "plasmadiscover", text: "Discover", cmd: "plasma-discover" },
        { icon: "help-about", text: "About This System", cmd: "kinfocenter" },
        { separator: true },
        { icon: "system-lock-screen", text: "Lock Screen", hint: "Meta+L", cmd: "loginctl lock-session" },
        { icon: "system-suspend", text: "Sleep", cmd: "systemctl suspend" },
        { icon: "system-reboot", text: "Restart…",
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot") },
        { icon: "system-shutdown", text: "Shut Down…",
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptShutDown") },
        { separator: true },
        { icon: "system-log-out", text: "Log Out…",
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptLogout") }
    ]

    // ---- the logo button in the bar ------------------------------------------------
    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: height + 8
        Layout.preferredWidth: height + 8
        onClicked: root.expanded = !root.expanded

        Rectangle {
            anchors.centerIn: parent
            width: parent.height - 4
            height: parent.height - 4
            radius: 8
            color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b,
                           root.expanded ? 0.18 : (button.containsMouse ? 0.10 : 0))
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.height * 0.68)
            height: width
            source: root.logo
            roundToIconSize: false
            scale: button.pressed ? 0.92 : (button.containsMouse ? 1.06 : 1)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }

    // ---- the Pixegami menu ------------------------------------------------------------
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        spacing: 2

        // header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 12
            Kirigami.Icon {
                source: root.logo
                roundToIconSize: false
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
            }
            ColumnLayout {
                spacing: 1
                Text { text: "Pixegami"; color: root.mint; font.pixelSize: 17; font.weight: Font.DemiBold }
                Text { text: root.userHost; color: root.textColor; font.pixelSize: 12; visible: text.length > 0 }
                Text {
                    text: root.osName + (root.uptime ? "  ·  up " + root.uptime : "")
                    color: root.subText; font.pixelSize: 11
                    visible: root.osName.length > 0
                    elide: Text.ElideRight
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 11
                }
            }
        }

        Repeater {
            model: root.menuModel
            delegate: Item {
                id: entry
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: modelData.section ? 4 : (modelData.separator ? 9 : 34)

                Rectangle {   // separator line
                    visible: !!entry.modelData.separator
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.15)
                }

                Rectangle {   // a menu row
                    visible: !entry.modelData.separator && !entry.modelData.section
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    radius: 8
                    color: rowMouse.containsMouse ? Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        Kirigami.Icon {
                            source: entry.modelData.icon || ""
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        Text {
                            text: entry.modelData.text || ""
                            color: rowMouse.containsMouse ? root.mint : root.textColor
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            text: entry.modelData.hint || ""
                            color: root.subText
                            font.pixelSize: 11
                            visible: text.length > 0
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
        Item { Layout.preferredHeight: 4 }
    }

    // ---- panel styling (same technique as the dock) ---------------------------------
    property Item panelRoot: null
    property Item panelFrame: null
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
        panelFrame = master
        panelFrames = frames.filter(f => f === master || f.anchors.fill === master)
        // rounded blur shape (matches the dock), theme background invisible
        for (const f of panelFrames) {
            f.imagePath = "dialogs/background"
            f.opacity = 0
        }
        if (!tint) {
            tint = Qt.createQmlObject('import QtQuick; Rectangle { z: -1 }', panelRoot, "pixegamiTint")
        }
        tint.anchors.fill = master
        tint.radius = Qt.binding(() => panelRoot.floatingness > 0.5 ? 12 : 0)
        tint.gradient = null
        tint.color = Qt.binding(() => Qt.rgba(root.navy.r, root.navy.g, root.navy.b, Plasmoid.configuration.bgOpacity))
    }
    // Plasma may rebuild bits of the panel (theme change, floating toggles): re-apply.
    Timer { interval: 400; running: true; onTriggered: root.stylePanel() }
    Timer {
        interval: 2000; repeat: true; running: root.panelRoot !== null
        onTriggered: { for (const f of root.panelFrames) if (f.opacity !== 0) f.opacity = 0 }
    }
    Component.onDestruction: if (tint) tint.destroy()
}
