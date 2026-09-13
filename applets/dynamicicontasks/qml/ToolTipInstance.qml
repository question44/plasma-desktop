/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020-2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem

ColumnLayout {
    id: root

    required property var model
    required property int index
    required property /*QModelIndex*/ var submodelIndex
    required property int appPid
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property /*list<var>*/ var virtualDesktops // Can't use list<var> because of QTBUG-127600
    required property list<string> activities

    property bool hasTrackInATitle: false
    property int orientation: ListView.Vertical // vertical for compact single-window tooltips

    // HACK: Avoid blank space in the tooltip after closing a window
    ListView.onPooled: width = height = 0
    ListView.onReused: width = height = undefined

    readonly property string title: {
        if (!toolTipDelegate.isWin) {
            return toolTipDelegate.genericName;
        }

        let text = display;
        if (toolTipDelegate.isGroup && text === "") {
            return "";
        }

        // Normally the window title will always have " — [app name]" at the end of
        // the window-provided title. But if it doesn't, this is intentional 100%
        // of the time because the developer or user has deliberately removed that
        // part, so just display it with no more fancy processing.
        if (!text.match(/\s+(—|-|–)/)) {
            return text;
        }

        // KWin appends increasing integers in between pointy brackets to otherwise equal window titles.
        // In this case save <#number> as counter and delete it at the end of text.
        text = `${(text.match(/.*(?=\s+(—|-|–))/) || [""])[0]}${(text.match(/<\d+>/) || [""]).pop()}`;

        // In case the window title had only redundant information (i.e. appName), text is now empty.
        // Add a hyphen to indicate that and avoid empty space.
        if (text === "") {
            text = "—";
        }
        return text;
    }

    readonly property bool titleIncludesTrack: toolTipDelegate.playerData !== null && title.includes(toolTipDelegate.playerData.track)

    readonly property bool lyricsEligible: Plasmoid.configuration.showTooltipLyrics
        && toolTipDelegate.playerData !== null
        && String(toolTipDelegate.playerData.track ?? "").length > 0
        && (root.index === 0 || root.titleIncludesTrack)
    readonly property bool lyricsViewVisible: lyricsEligible
    readonly property color lyricsAccentColor: toolTipDelegate.parentTask
        ? toolTipDelegate.parentTask.mediaProgressColor
        : Kirigami.Theme.highlightColor
    readonly property real lyricsAccentMinimumLuma: 0.48
    readonly property real lyricsAccentMaximumLuma: 0.72
    readonly property color readableLyricsAccentColor: adjustedLyricsAccentColor(lyricsAccentColor)
    property var lyricsRequest: null
    property string lyricsTrackKey: ""
    property int lyricsCurrentIndex: -1
    property bool lyricsHasTiming: false
    property bool lyricsLoading: false

    ListModel {
        id: lyricsLines
    }

    function adjustedLyricsAccentColor(accentColor) {
        const accentLuma = Kirigami.ColorUtils.grayForColor(accentColor);
        if (accentLuma >= lyricsAccentMinimumLuma) {
            if (accentLuma <= lyricsAccentMaximumLuma) {
                return accentColor;
            }

            const blackMix = (accentLuma - lyricsAccentMaximumLuma) / accentLuma;
            return Kirigami.ColorUtils.linearInterpolation(accentColor, "black", blackMix);
        }

        const whiteMix = (lyricsAccentMinimumLuma - accentLuma) / (1 - accentLuma);
        return Kirigami.ColorUtils.linearInterpolation(accentColor, "white", whiteMix);
    }

    function clearLyrics() {
        lyricsLines.clear();
        lyricsCurrentIndex = -1;
        lyricsHasTiming = false;
    }

    function parseLyrics(text) {
        const parsed = [];
        const lines = String(text ?? "").split(/\r?\n/);
        for (const line of lines) {
            const stamps = line.match(/\[(\d+):(\d+(?:\.\d+)?)\]/g) || [];
            const lyric = line.replace(/\[[^\]]+\]/g, "").trim();
            if (!lyric) {
                continue;
            }
            if (stamps.length === 0) {
                parsed.push({ time: -1, lyric });
                continue;
            }
            for (const stamp of stamps) {
                const match = stamp.match(/\[(\d+):(\d+(?:\.\d+)?)\]/);
                if (match) {
                    parsed.push({ time: Number(match[1]) * 60 + Number(match[2]), lyric });
                }
            }
        }
        parsed.sort((a, b) => a.time - b.time);
        clearLyrics();
        lyricsHasTiming = parsed.some(line => line.time >= 0);
        for (const line of parsed) {
            lyricsLines.append(line);
        }
    }

    function refreshLyricsPosition() {
        if (!lyricsEligible || lyricsLines.count === 0) {
            return;
        }
        if (!lyricsHasTiming) {
            if (lyricsCurrentIndex < 0) {
                lyricsCurrentIndex = 0;
            }
            return;
        }
        const positionSeconds = Number(toolTipDelegate.playerData?.position ?? 0) / 1000000;
        let nextIndex = 0;
        for (let i = 0; i < lyricsLines.count; ++i) {
            if (Number(lyricsLines.get(i).time) <= positionSeconds) {
                nextIndex = i;
            } else {
                break;
            }
        }
        if (nextIndex !== lyricsCurrentIndex) {
            lyricsCurrentIndex = nextIndex;
        }
    }

    function refreshLyrics() {
        if (!lyricsEligible) {
            if (lyricsRequest) {
                lyricsRequest.abort();
                lyricsRequest = null;
            }
            lyricsTrackKey = "";
            lyricsLoading = false;
            clearLyrics();
            return;
        }

        const player = toolTipDelegate.playerData;
        const track = String(player.track ?? "");
        const artist = String(player.artist ?? "");
        const album = String(player.album ?? "");
        const key = `${track}\u0000${artist}\u0000${album}`;
        if (key === lyricsTrackKey) {
            refreshLyricsPosition();
            return;
        }

        lyricsTrackKey = key;
        if (lyricsRequest) {
            lyricsRequest.abort();
        }
        clearLyrics();
        lyricsLoading = true;
        const params = `track_name=${encodeURIComponent(track)}&artist_name=${encodeURIComponent(artist)}&album_name=${encodeURIComponent(album)}&duration=${Math.round(Number(player.length ?? 0) / 1000000)}`;
        const requestKey = key;
        const request = new XMLHttpRequest();
        lyricsRequest = request;
        request.open("GET", `https://lrclib.net/api/get?${params}`);
        request.setRequestHeader("User-Agent", "Dynamic Icon Tasks (https://github.com/janzon/plasma-desktop-dynamic-icon-tasks)");
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || !root || requestKey !== root.lyricsTrackKey) {
                return;
            }
            lyricsRequest = null;
            lyricsLoading = false;
            if (request.status !== 200) {
                return;
            }
            try {
                const response = JSON.parse(request.responseText);
                parseLyrics(response.syncedLyrics || response.plainLyrics || "");
                refreshLyricsPosition();
            } catch (error) {
                console.warn("Failed to parse LRCLIB response", error);
            }
        };
        request.send();
    }

    Timer {
        id: lyricsTimer
        interval: 250
        repeat: true
        running: root.lyricsEligible
        onTriggered: root.refreshLyrics()
    }

    // Lots of spacing with no thumbnails looks bad
    spacing: Plasmoid.configuration.showToolTips ? Kirigami.Units.smallSpacing : 0

    // text labels + close button
    Item {
        id: headerItem
        implicitHeight: header.height
        implicitWidth: header.implicitWidth
        Layout.fillWidth: true

        // This number controls the overall size of the window tooltips
        Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
        Layout.minimumWidth: (toolTipDelegate.isWin && Plasmoid.configuration.showToolTips) || toolTipDelegate.isGroup ? Layout.maximumWidth : 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        // match margins of DefaultToolTip.qml in plasma-framework
        Layout.margins: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips ? 0 : Kirigami.Units.gridUnit / 2

        RowLayout {
            id: header
            width: parent.width
            // match spacing of DefaultToolTip.qml in plasma-framework
            spacing: Kirigami.Units.smallSpacing

            // close button for right edge ltr and left edge rtl
            LayoutItemProxy {
                id: closeButtonFlippedItemProxy
                target: closeButton
                visible: toolTipDelegate.isWin &&
                    ((Plasmoid.location == PlasmaCore.Types.LeftEdge &&
                      Application.layoutDirection == Qt.RightToLeft) ||
                     (Plasmoid.location == PlasmaCore.Types.RightEdge &&
                      Application.layoutDirection == Qt.LeftToRight))
            }

            // all textlabels
            ColumnLayout {
                spacing: 0
                // app name
                Kirigami.Heading {
                    id: appNameHeading
                    level: 3
                    maximumLineCount: 1
                    Layout.fillWidth: true
                    lineHeight: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips ? 1 : appNameHeading.lineHeight
                    elide: Text.ElideRight
                    text: toolTipDelegate.appName
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: root.index === 0 ? 1 : 0
                    visible: (text.length !== 0) && (root.orientation === ListView.Horizontal || root.index === 0)
                    textFormat: Text.PlainText
                }
                // window title
                PlasmaComponents3.Label {
                    id: winTitle
                    Layout.fillWidth: true
                    // For horizontal grouped tasks, leave room for two lines so thumbnails align
                    Layout.preferredHeight: root.orientation === ListView.Horizontal && lineCount === 1
                        ? implicitHeight * 2
                        : implicitHeight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    property bool somethingVisible: (thumbnailSourceItem.visible ||
                        appNameHeading.visible || subtext.visible)
                    text: ((root.titleIncludesTrack && playerController.active) ||
                           (root.title === appNameHeading.text && somethingVisible))
                          ? "" : root.title
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: 0.75
                    font.bold: toolTipDelegate.isGroup && toolTipDelegate.parentTask.model.IsActive && root.index == tasksModel.activeTask.row
                    visible: root.orientation === ListView.Horizontal || text.length !== 0
                    textFormat: Text.PlainText
                }
                // subtext
                PlasmaComponents3.Label {
                    id: subtext
                    Layout.fillWidth: true
                    // For horizontal grouped tasks, leave room for two lines so thumbnails align
                    Layout.preferredHeight: root.orientation === ListView.Horizontal && lineCount === 1
                        ? implicitHeight * 2
                        : implicitHeight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    text: toolTipDelegate.isWin ? root.generateSubText() : ""
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: 0.75
                    visible: text.length !== 0 && text !== appNameHeading.text
                    textFormat: Text.PlainText
                }
            }

            // Count badge.
            // The badge itself is inside an item to better center the text in the bubble
            Item {
                Layout.alignment: !Plasmoid.configuration.showToolTips && !playerController.active && !volumeControls.active ? Qt.AlignVCenter : Qt.AlignTop
                Layout.preferredHeight: closeButton.height
                Layout.preferredWidth: closeButton.width
                visible: root.index === 0 && toolTipDelegate.smartLauncherCountVisible

                Kirigami.Badge {
                    anchors.centerIn: parent
                    text: toolTipDelegate.smartLauncherCount
                }
            }

            LayoutItemProxy {
                target: closeButton
                visible: toolTipDelegate.isWin && !closeButtonFlippedItemProxy.visible
            }

            // close button
            PlasmaComponents3.ToolButton {
                id: closeButton
                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: closeButtonFlippedItemProxy.visible ? headerItem.Layout.margins : -headerItem.Layout.margins
                Layout.leftMargin: closeButtonFlippedItemProxy.visible ? -headerItem.Layout.margins : headerItem.Layout.margins
                Layout.topMargin: -headerItem.Layout.margins
                icon.name: "window-close"
                onClicked: {
                    tasks.cancelHighlightWindows();
                    tasksModel.requestClose(root.submodelIndex);
                }
                PlasmaComponents3.ToolTip.text: i18nc("@info:tooltip Close this window", "Close window")
                PlasmaComponents3.ToolTip.visible: root.visible && hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // make the header clickable if image tooltips are disabled (and thus there is no other clickable area that activates the window)
        // headerHoverHandler has to be unloaded after the instance is pooled in order to avoid getting the old containsMouse status when the same instance is reused, so put it in a Loader.
        Loader {
            id: headerHoverHandler
            active: (root.index !== -1) && !Plasmoid.configuration.showToolTips
            z: -2
            anchors.fill: headerItem
            anchors.margins: -headerItem.Layout.margins
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }

        // There's no PlasmaComponents3 version
        PlasmaExtras.Highlight {
            id: headerHoverHighlight
            anchors.fill: headerHoverHandler
            z: -1
            visible: (headerHoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (headerHoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }
    }

    // thumbnail container
    Item {
        id: thumbnailSourceItem

        Layout.fillWidth: true
        Layout.preferredHeight: toolTipDelegate.tooltipInstancePreferredHeight

        clip: true
        visible: Plasmoid.configuration.showToolTips && toolTipDelegate.isWin

        readonly property /*undefined|WId where WId = int|string*/ var winId:
            toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined

        // There's no PlasmaComponents3 version
        PlasmaExtras.Highlight {
            anchors.fill: hoverHandler
            visible: (hoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }

        Loader {
            id: thumbnailLoader
            active: !root.lyricsViewVisible
                && !toolTipDelegate.isLauncher
                && !albumArtImage.visible
                && (Number.isInteger(thumbnailSourceItem.winId) || pipeWireLoader.item
                && !(pipeWireLoader.item as PipeWireThumbnail).hasThumbnail)
                && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            anchors.fill: hoverHandler
            // Indent a little bit so that neither the thumbnail nor the drop
            // shadow can cover up the highlight
            anchors.margins: Kirigami.Units.smallSpacing * 2

            sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

            Component {
                id: x11Thumbnail

                PlasmaCore.WindowThumbnail {
                    winId: thumbnailSourceItem.winId
                }
            }

            // when minimized, we don't have a preview on X11, so show the icon
            Component {
                id: iconItem

                Kirigami.Icon {
                    id: realIconItem
                    source: toolTipDelegate.icon
                    animated: false
                    visible: valid
                    opacity: pipeWireLoader.active ? 0 : 1

                    SequentialAnimation {
                        running: true

                        PauseAnimation {
                            duration: Kirigami.Units.humanMoment
                        }

                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: realIconItem
                            to: 1
                        }
                    }

                }
            }
        }

        Loader {
            id: pipeWireLoader
            anchors.fill: hoverHandler
            // Indent a little bit so that neither the thumbnail nor the drop
            // shadow can cover up the highlight
            anchors.margins: thumbnailLoader.anchors.margins

            active: !root.lyricsViewVisible
                && Plasmoid.configuration.showToolTips
                && !toolTipDelegate.isLauncher
                && !albumArtImage.visible
                && KWindowSystem.isPlatformWayland
                && root.index !== -1
            asynchronous: true
            //In a loader since we might not have PipeWire available yet (WITH_PIPEWIRE could be undefined in plasma-workspace/libtaskmanager/declarative/taskmanagerplugin.cpp)
            source: "PipeWireThumbnail.qml"
        }

        Loader {
            active: !root.lyricsViewVisible
                && Plasmoid.configuration.showToolTips
                && (((pipeWireLoader.item as PipeWireThumbnail)?.hasThumbnail ?? false) || (thumbnailLoader.status === Loader.Ready && !root.isMinimized))
            asynchronous: true
            visible: active
            anchors.fill: pipeWireLoader.active ? pipeWireLoader : thumbnailLoader

            sourceComponent: GE.DropShadow {
                horizontalOffset: 0
                verticalOffset: 3
                radius: 8
                samples: Math.round(radius * 1.5)
                color: "Black"
                source: pipeWireLoader.active ? pipeWireLoader.item : thumbnailLoader.item // source could be undefined when albumArt is available, so put it in a Loader.
            }
        }

        Loader {
            active: !root.lyricsViewVisible
                && Plasmoid.configuration.showToolTips
                && albumArtImage.visible
                && albumArtImage.status === Image.Ready
                && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            anchors.centerIn: hoverHandler

            sourceComponent: ShaderEffect {
                id: albumArtBackground
                readonly property Image source: albumArtImage

                // Manual implementation of Image.PreserveAspectCrop
                readonly property real scaleFactor: Math.max(hoverHandler.width / source.paintedWidth, hoverHandler.height / source.paintedHeight)
                width: Math.round(source.paintedWidth * scaleFactor)
                height: Math.round(source.paintedHeight * scaleFactor)
                layer.enabled: true
                opacity: 0.25
                layer.effect: GE.FastBlur {
                    source: albumArtBackground
                    anchors.fill: source
                    radius: 30
                }
            }
        }

        Image {
            id: albumArtImage
            // also Image.Loading to prevent loading thumbnails just because the album art takes a split second to load
            // if this is a group tooltip, we check if window title and track match, to allow distinguishing the different windows
            // if this app is a browser, we also check the title, so album art is not shown when the user is on some other tab
            // in all other cases we can safely show the album art without checking the title
            readonly property bool available: (status === Image.Ready || status === Image.Loading)
                && (!(toolTipDelegate.isGroup || backend.applicationCategories(launcherUrl).includes("WebBrowser")) || root.titleIncludesTrack)

            anchors.fill: hoverHandler
            // Indent by one pixel to make sure we never cover up the entire highlight
            anchors.margins: 1
            sourceSize: Qt.size(parent.width, parent.height)

            asynchronous: true
            retainWhileLoading: true
            source: toolTipDelegate.playerData?.artUrl ?? ""
            fillMode: Image.PreserveAspectFit
            visible: available && !root.lyricsViewVisible
        }

        // Lyrics use a heavily blurred, aspect-cropped version of the album art
        // as a full-bleed background so the text remains visually connected to
        // the track without competing with the readable lyric lines.
        Image {
            id: lyricsBackdropImage
            anchors.fill: parent
            source: toolTipDelegate.playerData?.artUrl ?? ""
            sourceSize: Qt.size(parent.width, parent.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.lyricsViewVisible && status === Image.Ready
            opacity: 0.7
        }

        GE.FastBlur {
            id: lyricsBackdropBlur
            anchors.fill: lyricsBackdropImage
            source: lyricsBackdropImage
            radius: 52
            transparentBorder: true
            visible: lyricsBackdropImage.visible
            opacity: 0.95
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.lyricsViewVisible && lyricsBackdropImage.visible ? 0.38 : 0
        }

        Item {
            id: lyricsView
            anchors.fill: parent
            visible: root.lyricsViewVisible
            clip: true

            ListView {
                id: lyricsListView
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                model: lyricsLines
                interactive: false
                spacing: Kirigami.Units.smallSpacing / 2
                clip: true
                currentIndex: root.lyricsCurrentIndex
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.max(0, (height - (lyricsLineMetrics.height * 1.5)) / 2)
                preferredHighlightEnd: preferredHighlightBegin + lyricsLineMetrics.height
                highlightMoveDuration: Kirigami.Units.shortDuration
                highlightMoveVelocity: -1

                delegate: Item {
                    id: lyricDelegate
                    required property string lyric
                    required property real time
                    required property int index
                    width: lyricsListView.width
                    height: lyricText.implicitHeight

                    readonly property bool current: index === root.lyricsCurrentIndex
                    readonly property real distance: Math.abs(index - root.lyricsCurrentIndex)
                    readonly property real targetScale: lyricDelegate.current ? 1 : 0.98

                    PlasmaComponents3.Label {
                        id: lyricText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: lyricDelegate.lyric
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        color: lyricDelegate.current ? root.readableLyricsAccentColor : Kirigami.Theme.textColor
                        opacity: lyricDelegate.current ? 1 : Math.max(0.22, 0.72 - lyricDelegate.distance * 0.14)
                        font.bold: lyricDelegate.current
                        scale: lyricDelegate.targetScale
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        layer.enabled: !lyricDelegate.current
                        layer.effect: GE.FastBlur {
                            radius: 1.5
                        }
                    }

                }

                TextMetrics {
                    id: lyricsLineMetrics
                    text: "Current lyric line"
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Kirigami.Units.gridUnit * 1.8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.82) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Kirigami.Units.gridUnit * 1.8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                }
            }

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                visible: lyricsLines.count === 0
                text: root.lyricsLoading ? i18nc("@info", "Loading lyrics…") : i18nc("@info", "No synchronized lyrics")
                color: Kirigami.Theme.textColor
                opacity: 0.7
            }
        }

        // hoverHandler has to be unloaded after the instance is pooled in order to avoid getting the old containsMouse status when the same instance is reused, so put it in a Loader.
        Loader {
            id: hoverHandler
            active: root.index !== -1
            anchors.fill: parent
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }
    }

    // Player controls row, load on demand so group tooltips could be loaded faster
    Loader {
        id: playerController
        // Only load for one entry, as the controls only apply to one window.
        // If this is changed in the future, test for index != -1 to avoid loading
        // when the instance is going to be destroyed
        active: (toolTipDelegate.parentTask?.tooltipControlsEnabled
             && toolTipDelegate.playerData
             && ((root.hasTrackInATitle && albumArtImage.available) || (!root.hasTrackInATitle && root.index == 0))) ?? false

        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: headerItem.Layout.maximumWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins

        source: "PlayerController.qml"
    }

    Binding {
        target: playerController.item
        property: "showShuffle"
        value: Plasmoid.configuration.showTooltipMediaShuffle
        when: playerController.item !== null
    }

    Binding {
        target: playerController.item
        property: "showRepeat"
        value: Plasmoid.configuration.showTooltipMediaRepeat
        when: playerController.item !== null
    }

    Binding {
        target: playerController.item
        property: "showPrevious"
        value: Plasmoid.configuration.showTooltipMediaPrevious
        when: playerController.item !== null
    }

    Binding {
        target: playerController.item
        property: "showPlayPause"
        value: Plasmoid.configuration.showTooltipMediaPlayPause
        when: playerController.item !== null
    }

    Binding {
        target: playerController.item
        property: "showNext"
        value: Plasmoid.configuration.showTooltipMediaNext
        when: playerController.item !== null
    }

    Loader {
        id: mediaSeekControls
        active: (toolTipDelegate.parentTask?.tooltipControlsEnabled
             && toolTipDelegate.playerData?.canControl
             && (toolTipDelegate.playerData?.length ?? 0) > 0
             && ((root.hasTrackInATitle && albumArtImage.available) || (!root.hasTrackInATitle && root.index == 0))) ?? false
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: headerItem.Layout.maximumWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins
        sourceComponent: PlasmaComponents3.Slider {
            id: seekSlider

            from: 0
            to: toolTipDelegate.playerData?.length ?? 0
            stepSize: 0.1
            value: toolTipDelegate.playerData?.position ?? 0
            // Some players (notably Spotify) expose Seek but report CanSeek
            // unreliably. Keep the control usable for controllable players.
            enabled: (toolTipDelegate.playerData?.canSeek
                || toolTipDelegate.playerData?.canControl) ?? false
            Accessible.name: i18nc("Accessibility data on media seek slider", "Seek in media")

            Binding {
                target: seekSlider
                property: "value"
                value: toolTipDelegate.playerData?.position ?? 0
                when: !seekSlider.pressed
            }

            onMoved: {
                const offset = value - (toolTipDelegate.playerData?.position ?? 0);
                toolTipDelegate.playerData?.Seek(offset);
            }
        }
    }

    // Volume controls
    Loader {
        id: volumeControls
        active: toolTipDelegate.parentTask !== null
             && pulseAudio.item !== null
             && toolTipDelegate.parentTask.tooltipControlsEnabled
             && toolTipDelegate.parentTask.hasAudioStream
             // Only load for one entry, as the controls only apply to one window.
             // If this is changed in the future, test for index != -1 to avoid loading
             // when the instance is going to be destroyed
             && ((hasTrackInATitle && albumArtImage.available) || (!hasTrackInATitle && root.index == 0))
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: headerItem.Layout.maximumWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins
        sourceComponent: RowLayout {
            PlasmaComponents3.ToolButton { // Mute button
                id: muteButton
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.name: {
                    let finalIcon = ""

                    if (checked) {
                        finalIcon = "audio-volume-muted"
                    } else if (slider.displayValue <= 25) {
                        finalIcon = "audio-volume-low"
                    } else if (slider.displayValue <= 75) {
                        finalIcon = "audio-volume-medium"
                    } else {
                        finalIcon = "audio-volume-high"
                    }

                    if (mirrored) {
                        finalIcon = finalIcon + "-rtl"
                    }

                    return finalIcon
                }
                onClicked: toolTipDelegate.parentTask.toggleMuted()
                checked: toolTipDelegate.parentTask.muted

                PlasmaComponents3.ToolTip {
                    text: muteButton.checked
                        ? i18nc("button to unmute app", "Unmute %1", toolTipDelegate.parentTask.appName)
                        : i18nc("button to mute app", "Mute %1", toolTipDelegate.parentTask.appName)
                }
            }

            PlasmaComponents3.Slider {
                id: slider

                readonly property int displayValue: Math.round(value / to * 100)
                readonly property int loudestVolume: toolTipDelegate.parentTask.audioStreams
                    .reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                Layout.fillWidth: true
                from: pulseAudio.item.minimalVolume
                to: pulseAudio.item.normalVolume
                value: loudestVolume
                stepSize: to / 100
                opacity: toolTipDelegate.parentTask.muted ? 0.5 : 1

                Accessible.name: i18nc("Accessibility data on volume slider", "Adjust volume for %1", toolTipDelegate.parentTask.appName)

                onMoved: toolTipDelegate.parentTask.audioStreams.forEach((stream) => {
                    let v = Math.max(from, value)
                    if (v > 0 && loudestVolume > 0) { // prevent divide by 0
                        // adjust volume relative to the loudest stream
                        v = Math.min(Math.round(stream.volume / loudestVolume * v), to)
                    }
                    stream.model.Volume = v
                    stream.model.Muted = v === 0
                })
            }
            PlasmaComponents3.Label { // percent label
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumWidth: percentMetrics.advanceWidth
                horizontalAlignment: Qt.AlignRight
                text: i18nc("volume percentage", "%1%", slider.displayValue)
                textFormat: Text.PlainText
                TextMetrics {
                    id: percentMetrics
                    text: i18nc("only used for sizing, should be widest possible string", "100%")
                }
            }
        }
    }

    function generateSubText(): string {
        const subTextEntries = [];

        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(i18nc("Comma-separated list of desktops", "On %1",
                    virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(i18nc("Which virtual desktop a window is currently on",
                "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities
                .filter(activity => activity !== activityInfo.currentActivity)
                .map(activity => activityInfo.activityName(activity))
                .filter(activityName => activityName !== "");

            if (Plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(i18nc("Activities a window is currently on (apart from the current one)",
                        "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(i18nc("Which activities a window is currently on",
                    "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }
}
