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
    property alias cfg_audioStreamIndicatorVisibility: audioStreamIndicatorVisibility.currentIndex
    property alias cfg_tooltipControls: tooltipControls.checked
    property alias cfg_showMediaProgress: showMediaProgress.checked
    property alias cfg_mediaPlayerColorSource: mediaPlayerColorSource.currentIndex
    property alias cfg_albumArtColorStrategy: albumArtColorStrategy.currentIndex
    property alias cfg_expandMediaPlayerTasks: expandMediaPlayerTasks.checked
    property alias cfg_mediaPlayerTaskMinWidth: mediaPlayerTaskMinWidth.value
    property alias cfg_mediaPlayerTaskMaxWidth: mediaPlayerTaskMaxWidth.value
    property alias cfg_mediaMetadataLayout: mediaMetadataLayout.currentIndex
    property bool cfg_scrollMediaMetadata
    property int cfg_mediaMetadataScrollMode
    property alias cfg_wideMediaControlsMode: wideMediaControlsMode.currentIndex
    property alias cfg_wideMediaControlsHoverDelay: wideMediaControlsHoverDelay.value
    property alias cfg_showWideMediaPrevious: showWideMediaPrevious.checked
    property alias cfg_showWideMediaPlayPause: showWideMediaPlayPause.checked
    property alias cfg_showWideMediaNext: showWideMediaNext.checked
    property alias cfg_showWideMediaShuffle: showWideMediaShuffle.checked
    property alias cfg_showWideMediaRepeat: showWideMediaRepeat.checked
    property alias cfg_showWideMediaTime: showWideMediaTime.checked
    property alias cfg_showTooltipMediaShuffle: showTooltipMediaShuffle.checked
    property alias cfg_showTooltipMediaRepeat: showTooltipMediaRepeat.checked
    property alias cfg_showTooltipMediaPrevious: showTooltipMediaPrevious.checked
    property alias cfg_showTooltipMediaPlayPause: showTooltipMediaPlayPause.checked
    property alias cfg_showTooltipMediaNext: showTooltipMediaNext.checked
    property alias cfg_showTooltipLyrics: showTooltipLyrics.checked
    property alias cfg_tooltipLyricsVisibleLineCount: tooltipLyricsVisibleLineCount.value
    property alias cfg_showMediaVisualizer: showMediaVisualizer.checked
    property alias cfg_mediaVisualizerMaxHeight: mediaVisualizerMaxHeight.value
    property alias cfg_mediaVisualizerOpacity: mediaVisualizerOpacity.value
    property alias cfg_mediaVisualizerSensitivity: mediaVisualizerSensitivity.value
    property alias cfg_mediaVisualizerBarWidth: mediaVisualizerBarWidth.value
    property alias cfg_mediaVisualizerBarGap: mediaVisualizerBarGap.value
    property alias cfg_wideMediaControlsBackgroundStyle: wideMediaControlsBackgroundStyle.currentIndex
    property alias cfg_replaceMediaPlayerIconWithAlbumArt: replaceMediaPlayerIconWithAlbumArt.checked
    property alias cfg_showAppIconOnAlbumArt: showAppIconOnAlbumArt.checked
    property alias cfg_albumArtPadding: albumArtPadding.value
    property alias cfg_albumArtShape: albumArtShape.currentIndex
    property alias cfg_rotateCircularAlbumArt: rotateCircularAlbumArt.checked
    property alias cfg_albumArtSquircleRoundness: albumArtSquircleRoundness.value
    property alias cfg_albumArtMetadataGap: albumArtMetadataGap.value
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

        QQC2.ComboBox {
            id: audioStreamIndicatorVisibility
            Kirigami.FormData.label: i18nc("@label:listbox", "Audio indicator:")
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
            model: [
                i18nc("@item:inlistbox", "Always visible"),
                i18nc("@item:inlistbox", "Show on hover"),
                i18nc("@item:inlistbox", "Show when muted, otherwise on hover")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showMediaProgress
            Kirigami.FormData.label: i18nc("@label for media settings", "Playback:")
            text: i18nc("@option:check", "Show playback progress in the edge indicator")
        }

        QQC2.ComboBox {
            id: mediaPlayerColorSource
            Kirigami.FormData.label: i18nc("@label:listbox", "Media-player colors:")
            model: [
                i18nc("@item:inlistbox", "Application icon"),
                i18nc("@item:inlistbox", "Album art")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: albumArtColorStrategy
            Kirigami.FormData.label: i18nc("@label:listbox", "Album-art color:")
            enabled: mediaPlayerColorSource.currentIndex === 1
            model: [
                i18nc("@item:inlistbox", "Dominant color"),
                i18nc("@item:inlistbox", "Accent color"),
                i18nc("@item:inlistbox", "Average palette")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: expandMediaPlayerTasks
            Kirigami.FormData.label: i18nc("@label for media settings", "Wide task:")
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

        QQC2.ComboBox {
            id: mediaMetadataLayout
            Kirigami.FormData.label: i18nc("@label:listbox", "Metadata layout:")
            enabled: expandMediaPlayerTasks.checked
            model: [
                i18nc("@item:inlistbox", "Auto"),
                i18nc("@item:inlistbox", "Stacked"),
                i18nc("@item:inlistbox", "Inline")
            ]
        }

        QQC2.ComboBox {
            id: mediaMetadataScrollMode
            Kirigami.FormData.label: i18nc("@label:listbox", "Overflowing text:")
            enabled: expandMediaPlayerTasks.checked
            currentIndex: root.cfg_scrollMediaMetadata
                ? root.cfg_mediaMetadataScrollMode + 1
                : 0
            model: [
                i18nc("@item:inlistbox", "Disabled"),
                i18nc("@item:inlistbox", "Back and forth"),
                i18nc("@item:inlistbox", "Loop left")
            ]
            onActivated: index => {
                root.cfg_scrollMediaMetadata = index > 0;
                root.cfg_mediaMetadataScrollMode = Math.max(0, index - 1);
            }
        }

        QQC2.ComboBox {
            id: wideMediaControlsMode
            Kirigami.FormData.label: i18nc("@label:listbox", "Wide task controls:")
            enabled: expandMediaPlayerTasks.checked
            model: [
                i18nc("@item:inlistbox", "Always show"),
                i18nc("@item:inlistbox", "Show on hover")
            ]
        }

        QQC2.SpinBox {
            id: wideMediaControlsHoverDelay
            Kirigami.FormData.label: i18nc("@label:spinbox", "Hover delay:")
            from: 0
            to: 1000
            stepSize: 25
            enabled: expandMediaPlayerTasks.checked && wideMediaControlsMode.currentIndex === 1
            textFromValue: value => i18nc("@item:valuesuffix milliseconds", "%1 ms", value)
            valueFromText: text => parseInt(text)
        }

        GridLayout {
            Kirigami.FormData.label: i18nc("@label for media settings", "Media buttons:")
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                text: i18nc("@label", "Panel")
                font.bold: true
            }
            QQC2.Label {
                text: i18nc("@label", "Tooltip")
                font.bold: true
            }

            QQC2.CheckBox {
                id: showWideMediaPrevious
                text: i18nc("@option:check", "Previous track")
                enabled: expandMediaPlayerTasks.checked
            }
            QQC2.CheckBox {
                id: showTooltipMediaPrevious
                text: i18nc("@option:check", "Previous track")
                enabled: tooltipControls.checked
            }

            QQC2.CheckBox {
                id: showWideMediaPlayPause
                text: i18nc("@option:check", "Play / pause")
                enabled: expandMediaPlayerTasks.checked
            }
            QQC2.CheckBox {
                id: showTooltipMediaPlayPause
                text: i18nc("@option:check", "Play / pause")
                enabled: tooltipControls.checked
            }

            QQC2.CheckBox {
                id: showWideMediaNext
                text: i18nc("@option:check", "Next track")
                enabled: expandMediaPlayerTasks.checked
            }
            QQC2.CheckBox {
                id: showTooltipMediaNext
                text: i18nc("@option:check", "Next track")
                enabled: tooltipControls.checked
            }

            QQC2.CheckBox {
                id: showWideMediaShuffle
                text: i18nc("@option:check", "Shuffle")
                enabled: expandMediaPlayerTasks.checked
            }
            QQC2.CheckBox {
                id: showTooltipMediaShuffle
                text: i18nc("@option:check", "Shuffle")
                enabled: tooltipControls.checked
            }

            QQC2.CheckBox {
                id: showWideMediaRepeat
                text: i18nc("@option:check", "Repeat")
                enabled: expandMediaPlayerTasks.checked
            }
            QQC2.CheckBox {
                id: showTooltipMediaRepeat
                text: i18nc("@option:check", "Repeat")
                enabled: tooltipControls.checked
            }
        }

        QQC2.CheckBox {
            id: showWideMediaTime
            Kirigami.FormData.label: i18nc("@label for media settings", "Panel time:")
            text: i18nc("@option:check", "Show current / total time when not hovered")
            enabled: expandMediaPlayerTasks.checked && wideMediaControlsMode.currentIndex === 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showTooltipLyrics
            Kirigami.FormData.label: i18nc("@label for media settings", "Lyrics:")
            text: i18nc("@option:check", "Show synchronized lyrics instead of the thumbnail")
            enabled: tooltipControls.checked
        }

        QQC2.SpinBox {
            id: tooltipLyricsVisibleLineCount
            Kirigami.FormData.label: i18nc("@label:spinbox", "Visible lines:")
            from: 3
            to: 9
            stepSize: 2
            enabled: showTooltipLyrics.checked && tooltipControls.checked
            textFromValue: value => i18nc("@item:valuesuffix lines", "%1 lines", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            text: i18nc("@info", "Lyrics are fetched from LRCLIB using the active player's MPRIS metadata. Network access is required.")
            wrapMode: Text.Wrap
            color: Kirigami.Theme.disabledTextColor
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showMediaVisualizer
            Kirigami.FormData.label: i18nc("@label for media settings", "Visualizer:")
            text: i18nc("@option:check", "Show Cava audio visualizer")
        }

        QQC2.SpinBox {
            id: mediaVisualizerMaxHeight
            Kirigami.FormData.label: i18nc("@label:spinbox", "Maximum height:")
            from: 5
            to: 80
            stepSize: 5
            enabled: showMediaVisualizer.checked
            textFromValue: value => i18nc("@item:valuesuffix percent", "%1% of task height", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: mediaVisualizerOpacity
            Kirigami.FormData.label: i18nc("@label:spinbox", "Opacity:")
            from: 5
            to: 100
            stepSize: 5
            enabled: showMediaVisualizer.checked
            textFromValue: value => i18nc("@item:valuesuffix percent", "%1%", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: mediaVisualizerSensitivity
            Kirigami.FormData.label: i18nc("@label:spinbox", "Sensitivity:")
            from: 50
            to: 400
            stepSize: 10
            enabled: showMediaVisualizer.checked
            textFromValue: value => i18nc("@item:valuesuffix percent", "%1%", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: mediaVisualizerBarWidth
            Kirigami.FormData.label: i18nc("@label:spinbox", "Bar width:")
            from: 1
            to: 16
            stepSize: 1
            enabled: showMediaVisualizer.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: mediaVisualizerBarGap
            Kirigami.FormData.label: i18nc("@label:spinbox", "Bar gap:")
            from: 0
            to: 12
            stepSize: 1
            enabled: showMediaVisualizer.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.ComboBox {
            id: wideMediaControlsBackgroundStyle
            Kirigami.FormData.label: i18nc("@label:listbox", "Control background:")
            enabled: expandMediaPlayerTasks.checked
            model: [
                i18nc("@item:inlistbox", "Solid pill with shadow"),
                i18nc("@item:inlistbox", "Diffuse backdrop")
            ]
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

        QQC2.SpinBox {
            id: albumArtPadding
            Kirigami.FormData.label: i18nc("@label:spinbox", "Padding:")
            from: 0
            to: 24
            stepSize: 1
            enabled: replaceMediaPlayerIconWithAlbumArt.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.ComboBox {
            id: albumArtShape
            Kirigami.FormData.label: i18nc("@label:listbox", "Shape:")
            enabled: replaceMediaPlayerIconWithAlbumArt.checked
            model: [
                i18nc("@item:inlistbox", "Square"),
                i18nc("@item:inlistbox", "Squircle"),
                i18nc("@item:inlistbox", "Rounded"),
                i18nc("@item:inlistbox", "Circle")
            ]
        }

        QQC2.CheckBox {
            id: rotateCircularAlbumArt
            leftPadding: mirrored
                ? 0
                : albumArtShape.indicator.width + albumArtShape.spacing
            rightPadding: mirrored
                ? albumArtShape.indicator.width + albumArtShape.spacing
                : 0
            text: i18nc("@option:check", "Rotate while playing")
            enabled: replaceMediaPlayerIconWithAlbumArt.checked
                && albumArtShape.currentIndex === 3
        }

        QQC2.SpinBox {
            id: albumArtSquircleRoundness
            Kirigami.FormData.label: i18nc("@label:spinbox", "Squircle roundness:")
            from: 0
            to: 50
            stepSize: 1
            visible: albumArtShape.currentIndex === 1
            enabled: replaceMediaPlayerIconWithAlbumArt.checked && albumArtShape.currentIndex === 1
            textFromValue: value => i18nc("@item:valuesuffix percent", "%1%", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: albumArtMetadataGap
            Kirigami.FormData.label: i18nc("@label:spinbox", "Metadata gap:")
            from: 0
            to: 32
            stepSize: 1
            enabled: replaceMediaPlayerIconWithAlbumArt.checked
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.ScrollView {
            Kirigami.FormData.label: i18nc("@label", "Exclude applications:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5

        Item {
            Kirigami.FormData.isSection: true
        }

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
