/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

RowLayout {
    id: root

    // These are supplied by the tooltip's Loader because this component is
    // loaded outside the applet's Plasmoid context.
    property bool showShuffle: true
    property bool showRepeat: true

    enabled: toolTipDelegate.playerData?.canControl ?? false
    spacing: Kirigami.Units.smallSpacing

    readonly property bool isPlaying: toolTipDelegate.playerData?.playbackStatus === Mpris.PlaybackStatus.Playing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        ScrollableTextWrapper {
            id: songTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            textItem: PlasmaComponents3.Label {
                id: songText
                maximumLineCount: artistText.visible ? 1 : 2
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: toolTipDelegate.playerData?.track ?? ""
                textFormat: Text.PlainText
            }
        }

        ScrollableTextWrapper {
            id: artistTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: artistText.height
            implicitWidth: artistText.implicitWidth
            visible: artistText.text.length > 0

            textItem: PlasmaExtras.DescriptiveLabel {
                id: artistText
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: toolTipDelegate.playerData?.artist ?? ""
                font: Kirigami.Theme.smallFont
                textFormat: Text.PlainText
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: toolTipDelegate.playerData?.canGoPrevious ?? false
        icon.name: mirrored ? "media-skip-forward" : "media-skip-backward"
        onClicked: toolTipDelegate.playerData.Previous()
    }

    PlasmaComponents3.ToolButton {
        enabled: (root.isPlaying ? toolTipDelegate.playerData?.canPause : toolTipDelegate.playerData?.canPlay) ?? false
        icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
        onClicked: {
            if (!root.isPlaying) {
                toolTipDelegate.playerData.Play();
            } else {
                toolTipDelegate.playerData.Pause();
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: toolTipDelegate.playerData?.canGoNext ?? false
        icon.name: mirrored ? "media-skip-backward" : "media-skip-forward"
        onClicked: toolTipDelegate.playerData.Next()
    }

    PlasmaComponents3.ToolButton {
        visible: root.showShuffle
            && toolTipDelegate.playerData?.shuffle !== Mpris.ShuffleStatus.Unknown
        enabled: toolTipDelegate.playerData?.canControl ?? false
        checkable: true
        checked: toolTipDelegate.playerData?.shuffle === Mpris.ShuffleStatus.On
        icon.name: "media-playlist-shuffle"
        onClicked: toolTipDelegate.playerData.shuffle = checked
            ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off
        Accessible.name: i18nc("@action:button", "Toggle shuffle")
    }

    PlasmaComponents3.ToolButton {
        visible: root.showRepeat
            && toolTipDelegate.playerData?.loopStatus !== Mpris.LoopStatus.Unknown
        enabled: toolTipDelegate.playerData?.canControl ?? false
        checkable: true
        checked: toolTipDelegate.playerData?.loopStatus !== Mpris.LoopStatus.None
        icon.name: toolTipDelegate.playerData?.loopStatus === Mpris.LoopStatus.Track
            ? "media-repeat-single" : "media-playlist-repeat"
        onClicked: {
            const loopStatus = toolTipDelegate.playerData.loopStatus;
            toolTipDelegate.playerData.loopStatus = loopStatus === Mpris.LoopStatus.None
                ? Mpris.LoopStatus.Playlist
                : (loopStatus === Mpris.LoopStatus.Playlist
                    ? Mpris.LoopStatus.Track : Mpris.LoopStatus.None);
        }
        Accessible.name: i18nc("@action:button", "Cycle repeat mode")
    }
}
