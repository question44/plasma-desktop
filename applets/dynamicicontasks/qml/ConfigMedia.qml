/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: root

    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready

    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property alias cfg_tooltipControls: tooltipControls.checked
    property alias cfg_showMediaProgress: showMediaProgress.checked
    property alias cfg_expandMediaPlayerTasks: expandMediaPlayerTasks.checked
    property alias cfg_mediaPlayerTaskMinWidth: mediaPlayerTaskMinWidth.value
    property alias cfg_mediaPlayerTaskMaxWidth: mediaPlayerTaskMaxWidth.value
    property alias cfg_replaceMediaPlayerIconWithAlbumArt: replaceMediaPlayerIconWithAlbumArt.checked
    property alias cfg_showAppIconOnAlbumArt: showAppIconOnAlbumArt.checked
    property alias cfg_albumArtExcludedAppIds: albumArtExcludedAppIds.text
    property alias cfg_mediaPlayerIdAliases: mediaPlayerIdAliases.text

    function startNewLine(editor) {
        if (editor.length > 0 && !editor.text.endsWith("\n")) {
            editor.insert(editor.length, "\n");
        }
        editor.forceActiveFocus();
        editor.cursorPosition = editor.length;
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: tooltipControls
            Kirigami.FormData.label: i18nc("@label for media settings", "Controls:")
            text: i18nc("@option:check", "Show media and volume controls in tooltip")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            leftPadding: mirrored ? 0 : (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing)
            rightPadding: mirrored ? (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing) : 0
            text: i18nc("@option:check", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showMediaProgress
            Kirigami.FormData.label: i18nc("@label for media settings", "Playback:")
            text: i18nc("@option:check", "Show playback progress in the edge indicator")
        }

        QQC2.CheckBox {
            id: expandMediaPlayerTasks
            text: i18nc("@option:check", "Use a wide task for playing and paused media players")
        }

        QQC2.SpinBox {
            id: mediaPlayerTaskMinWidth
            Kirigami.FormData.label: i18nc("@label:spinbox", "Minimum width:")
            from: 100
            to: 600
            stepSize: 10
            enabled: expandMediaPlayerTasks.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
            onValueModified: {
                if (value > mediaPlayerTaskMaxWidth.value) {
                    mediaPlayerTaskMaxWidth.value = value;
                }
            }
        }

        QQC2.SpinBox {
            id: mediaPlayerTaskMaxWidth
            Kirigami.FormData.label: i18nc("@label:spinbox", "Maximum width:")
            from: 100
            to: 600
            stepSize: 10
            enabled: expandMediaPlayerTasks.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
            onValueModified: {
                if (value < mediaPlayerTaskMinWidth.value) {
                    mediaPlayerTaskMinWidth.value = value;
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            text: i18nc("@info", "The task rests at the minimum width; the maximum limits later content-driven growth. Horizontal panels only.")
            wrapMode: Text.Wrap
            color: Kirigami.Theme.disabledTextColor
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: replaceMediaPlayerIconWithAlbumArt
            Kirigami.FormData.label: i18nc("@label for media settings", "Album art:")
            text: i18nc("@option:check", "Replace media-player icon with album art")
        }

        QQC2.CheckBox {
            id: showAppIconOnAlbumArt
            leftPadding: mirrored
                ? 0
                : replaceMediaPlayerIconWithAlbumArt.indicator.width
                    + replaceMediaPlayerIconWithAlbumArt.spacing
            rightPadding: mirrored
                ? replaceMediaPlayerIconWithAlbumArt.indicator.width
                    + replaceMediaPlayerIconWithAlbumArt.spacing
                : 0
            text: i18nc("@option:check", "Show application icon in the corner")
            enabled: replaceMediaPlayerIconWithAlbumArt.checked
        }

        QQC2.ScrollView {
            Kirigami.FormData.label: i18nc("@label", "Exclude applications:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5

            QQC2.TextArea {
                id: albumArtExcludedAppIds
                placeholderText: i18nc("@info:placeholder", "application.desktop.id")
                wrapMode: TextEdit.NoWrap
                Accessible.description: i18nc("@info:whatsthis", "Enter one task desktop ID per line. These applications retain their normal icon-only task and will not use album art. Lines beginning with # are ignored.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true

            QQC2.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Excluded applications keep a normal icon-only task. One desktop ID per line, for example: com.spotify.Client")
                wrapMode: Text.Wrap
                color: Kirigami.Theme.disabledTextColor
            }

            QQC2.Button {
                text: i18nc("@action:button", "Add application")
                onClicked: root.startNewLine(albumArtExcludedAppIds)
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ScrollView {
            Kirigami.FormData.label: i18nc("@label", "Player ID mappings:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5

            QQC2.TextArea {
                id: mediaPlayerIdAliases
                placeholderText: i18nc("@info:placeholder", "task.desktop.id=mpris-id")
                wrapMode: TextEdit.NoWrap
                Accessible.description: i18nc("@info:whatsthis", "Enter one task desktop ID to MPRIS DesktopEntry mapping per line. Lines beginning with # are ignored.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true

            QQC2.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Press Enter for a new line. Example: com.spotify.Client=spotify")
                wrapMode: Text.Wrap
                color: Kirigami.Theme.disabledTextColor
            }

            QQC2.Button {
                text: i18nc("@action:button", "Add mapping")
                onClicked: root.startNewLine(mediaPlayerIdAliases)
            }
        }
    }
}
