import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_iconSize: iconSize.value
    property real cfg_maxZoom
    property real cfg_zoomReach
    property real cfg_bgOpacity
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_showPreviews: showPreviews.checked
    property alias cfg_showTrash: showTrash.checked
    property alias cfg_bounceOnLaunch: bounce.checked

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: "Icon size:"
            from: 24; to: 96; stepSize: 4
        }

        RowLayout {
            Kirigami.FormData.label: "Zoom:"
            QQC2.Slider {
                from: 1.0; to: 2.5; stepSize: 0.05
                value: cfg_maxZoom
                onMoved: cfg_maxZoom = value
            }
            QQC2.Label { text: cfg_maxZoom.toFixed(2) + "×" }
        }

        RowLayout {
            Kirigami.FormData.label: "Zoom reach:"
            QQC2.Slider {
                from: 1.5; to: 5.0; stepSize: 0.25
                value: cfg_zoomReach
                onMoved: cfg_zoomReach = value
            }
            QQC2.Label { text: cfg_zoomReach.toFixed(2) + " icons" }
        }

        RowLayout {
            Kirigami.FormData.label: "Background opacity:"
            QQC2.Slider {
                from: 0.0; to: 1.0; stepSize: 0.05
                value: cfg_bgOpacity
                onMoved: cfg_bgOpacity = value
            }
            QQC2.Label { text: Math.round(cfg_bgOpacity * 100) + "%" }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox { id: showLabels; Kirigami.FormData.label: "Show:"; text: "App name on hover" }
        QQC2.CheckBox { id: showPreviews; text: "Window previews on hover" }
        QQC2.CheckBox { id: showTrash; text: "Trash" }
        QQC2.CheckBox { id: bounce; text: "Bounce while an app starts" }
    }
}
