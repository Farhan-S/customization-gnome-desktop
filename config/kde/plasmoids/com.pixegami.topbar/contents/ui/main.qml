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

    function dbus(dest, path, method) {
        return "dbus-send --session --type=method_call --dest=" + dest + " " + path + " " + method
    }
    function act(cmd) {
        menu.visible = false
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

    readonly property var menuModel: [
        { icon: "view-app-grid-symbolic", text: "Applications", hint: "Meta", cmd: dashboardCmd },
        { icon: "search", text: "Search", hint: "Alt+Space",
          cmd: dbus("org.kde.krunner", "/App", "org.kde.krunner.App.display") },
        { separator: true },
        { icon: "configure-symbolic", text: "System Settings", cmd: "systemsettings" },
        { icon: "user-identity", text: "Account", cmd: "systemsettings kcm_users" },
        { icon: "help-about", text: "About This System", cmd: "kinfocenter" },
        { separator: true },
        { icon: "system-lock-screen", text: "Lock Screen", hint: "Meta+L", cmd: "loginctl lock-session" },
        { icon: "system-suspend", text: "Sleep", cmd: "systemctl suspend" },
        { icon: "system-reboot", text: "Restart…",
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot") },
        { icon: "system-shutdown", text: "Shut Down…",
          cmd: dbus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptShutDown") },
        { icon: "system-log-out", text: "Log Out…",
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

            mainItem: Rectangle {
                id: card
                width: Kirigami.Units.gridUnit * 17
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
