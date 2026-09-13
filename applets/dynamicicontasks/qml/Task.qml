/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import plasma.applet.org.janzon.plasma.dynamicicontasks as TaskManagerApplet
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager

PlasmaCore.ToolTipArea {
    id: task

    component PanelMediaControlButton: Item {
        id: control

        required property string iconSource
        required property string accessibleName
        required property var toolTipArea
        property bool checkable: false
        property bool checked: false

        signal triggered()

        activeFocusOnTab: true
        opacity: enabled ? 1 : 0.45

        Accessible.checkable: checkable
        Accessible.checked: checked
        Accessible.name: accessibleName
        Accessible.role: Accessible.Button
        Accessible.onPressAction: control.triggered()

        Keys.onReturnPressed: event => {
            control.triggered();
            event.accepted = true;
        }
        Keys.onEnterPressed: event => Keys.returnPressed(event)
        Keys.onSpacePressed: event => Keys.returnPressed(event)

        HoverHandler {
            id: controlHover
        }

        TapHandler {
            id: controlTap
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: control.enabled
            onTapped: {
                control.triggered();
                Qt.callLater(() => {
                    if (controlHover.hovered && control.toolTipArea.active) {
                        control.toolTipArea.showToolTip();
                    }
                });
            }
        }

        PlasmaExtras.Highlight {
            anchors.fill: parent
            hovered: controlHover.hovered || control.activeFocus
            pressed: controlTap.pressed
        }

        Kirigami.Icon {
            readonly property real iconExtent: Math.min(parent.width, parent.height)
                - Kirigami.Units.smallSpacing

            anchors.centerIn: parent
            width: iconExtent
            height: iconExtent
            source: control.iconSource
            selected: controlTap.pressed || control.checked
        }
    }

    activeFocusOnTab: true

    // To achieve a bottom-to-top layout on vertical panels, the task manager
    // is rotated by 180 degrees(see main.qml). This makes the tasks rotated,
    // so un-rotate them here to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    implicitHeight: inPopup
                    ? TaskManagerApplet.LayoutMetrics.preferredHeightInPopup()
                    : (tasksRoot.vertical
                        ? TaskManagerApplet.LayoutMetrics.preferredMinHeight()
                        : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes,
                             TaskManagerApplet.LayoutMetrics.preferredMinHeight()))
    implicitWidth: tasksRoot.vertical
        ? Math.max(TaskManagerApplet.LayoutMetrics.preferredMinWidth(), Math.min(TaskManagerApplet.LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes))
        : (expandedMediaTask
            ? mediaTaskPreferredWidth
            : 0)

    // A wide media task has an explicit content-driven preferred width. Letting
    // it fill its grid cell makes spare panel space push it straight to the
    // configured maximum instead of resting near that preferred size.
    // Let only metadata that needs additional room absorb spare grid width.
    // This keeps short media tasks near their configured minimum but gives a
    // longer title the panel space it can use before marquee becomes necessary.
    Layout.fillWidth: !expandedMediaTask || mediaTaskNeedsAdditionalWidth
    Layout.fillHeight: !inPopup
    Layout.minimumWidth: expandedMediaTask
        ? mediaTaskPreferredWidth
        : -1
    Layout.preferredWidth: expandedMediaTask
        ? mediaTaskPreferredWidth
        : -1
    Layout.maximumWidth: tasksRoot.vertical
        ? -1
        : (expandedMediaTask
            ? Math.max(
                TaskManagerApplet.LayoutMetrics.preferredMaxWidth(),
                Plasmoid.configuration.mediaPlayerTaskMinWidth,
                Plasmoid.configuration.mediaPlayerTaskMaxWidth)
            : ((model.IsLauncher && !tasksRoot.iconsOnly) ? tasksRoot.height / taskList.rows : TaskManagerApplet.LayoutMetrics.preferredMaxWidth()))
    Layout.maximumHeight: tasksRoot.vertical ? TaskManagerApplet.LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property int audioStreamIndicatorVisibility: Plasmoid.configuration.audioStreamIndicatorVisibility
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)
    property Mpris.PlayerContainer mediaPlayerData: null
    readonly property bool mediaProgressPlaying: mediaPlayerData?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool mediaProgressPaused: mediaPlayerData?.playbackStatus === Mpris.PlaybackStatus.Paused
    readonly property bool mediaPresentationExcluded: TaskManagerApplet.TaskTools.desktopIdListContains(
        Plasmoid.configuration.albumArtExcludedAppIds,
        model.LauncherUrlWithoutIcon,
        model.AppId)
    readonly property bool mediaTaskExpansionCandidate: Plasmoid.configuration.expandMediaPlayerTasks
        && !tasksRoot.vertical
        && !inPopup
        && !model.IsGroupParent
        && !mediaPresentationExcluded
        && (mediaProgressPlaying || mediaProgressPaused)
    readonly property bool expandedMediaTask: mediaTaskExpansionCandidate
    readonly property bool mediaMetadataEnabled: expandedMediaTask
        && (mediaTrackText.length > 0 || mediaArtistText.length > 0)
    readonly property string mediaTrackText: String(mediaPlayerData?.track ?? "")
    readonly property string mediaArtistText: String(mediaPlayerData?.artist ?? "")
    readonly property string mediaInlineText: mediaArtistText.length > 0 && mediaTrackText.length > 0
        ? mediaArtistText + " - " + mediaTrackText
        : (mediaTrackText.length > 0 ? mediaTrackText : mediaArtistText)
    readonly property real mediaTrackEstimatedWidth: mediaTrackText.length * Kirigami.Units.gridUnit * 0.42
    readonly property real mediaInlineEstimatedWidth: mediaInlineText.length * Kirigami.Units.gridUnit * 0.42
    readonly property real mediaTrackMarqueeWidth: Math.max(
        mediaTrackMeasure.implicitWidth, mediaTrackEstimatedWidth)
    readonly property real mediaInlineMarqueeWidth: Math.max(
        mediaInlineMeasure.implicitWidth, mediaInlineEstimatedWidth)
    // Keep the speaker/mute slot reserved for media tasks even while its
    // indicator is hidden, so hovering cannot change the task's preferred width.
    readonly property real mediaAudioIndicatorReservation: audioStreamIcon !== null
        ? Kirigami.Units.iconSizes.roundedIconSize(Math.min(height, Kirigami.Units.iconSizes.smallMedium))
            + TaskManagerApplet.LayoutMetrics.labelMargin
        : 0
    readonly property bool mediaControlsAvailable: expandedMediaTask
        && (mediaPlayerData?.canControl ?? false)
        && mediaControlsButtonCount > 0
    readonly property string mediaControlsVisibilityMode: ["always", "hover"][
        Math.max(0, Math.min(1, Plasmoid.configuration.wideMediaControlsMode))]
    readonly property bool mediaControlsAlwaysVisible: mediaControlsVisibilityMode === "always"
    readonly property bool mediaTimeVisible: Plasmoid.configuration.showWideMediaTime
        && !mediaControlsAlwaysVisible
        && !containsMouse
        && mediaMetadataEnabled
        && (mediaProgressPlaying || mediaProgressPaused)
        && (mediaPlayerData?.length ?? 0) > 0

    function formatMediaTime(seconds: real): string {
        const microsecondsPerSecond = 1000000;
        const totalSeconds = Math.max(0, Math.floor(seconds / microsecondsPerSecond));
        const minutes = Math.floor(totalSeconds / 60);
        const remaining = totalSeconds % 60;
        return minutes + ":" + (remaining < 10 ? "0" : "") + remaining;
    }
    property bool mediaControlsHoverReady: false
    readonly property string mediaControlsBackgroundMode: ["solid", "diffuse"][
        Math.max(0, Math.min(1, Plasmoid.configuration.wideMediaControlsBackgroundStyle))]
    readonly property bool mediaControlsBlendIntoTask: mediaControlsBackgroundMode === "diffuse"
    readonly property int mediaControlsButtonCount:
        (Plasmoid.configuration.showWideMediaPrevious ? 1 : 0)
        + (Plasmoid.configuration.showWideMediaPlayPause ? 1 : 0)
        + (Plasmoid.configuration.showWideMediaNext ? 1 : 0)
        + (Plasmoid.configuration.showWideMediaShuffle
           && mediaPlayerData?.shuffle !== Mpris.ShuffleStatus.Unknown ? 1 : 0)
        + (Plasmoid.configuration.showWideMediaRepeat
           && mediaPlayerData?.loopStatus !== Mpris.LoopStatus.Unknown ? 1 : 0)
    readonly property real mediaControlsButtonSize: Kirigami.Units.iconSizes.smallMedium
    readonly property real mediaControlsHorizontalPadding: Kirigami.Units.smallSpacing * 1.5
    readonly property real mediaControlsWidth: mediaControlsButtonSize * mediaControlsButtonCount
        + (Kirigami.Units.smallSpacing * Math.max(0, mediaControlsButtonCount - 1))
        + (mediaControlsHorizontalPadding * 2)
    readonly property real mediaControlsReservation: mediaControlsAvailable && mediaControlsAlwaysVisible
        ? mediaControlsWidth + TaskManagerApplet.LayoutMetrics.labelMargin
        : 0
    readonly property color mediaMetadataFadeColor: {
        const background = taskColorBackground.visible
            ? taskColorBackground.color
            : Kirigami.Theme.backgroundColor;
        const alpha = taskColorBackground.visible
            ? Math.min(0.5, Math.max(0.28, taskColorBackground.opacity))
            : 0.42;
        return Qt.rgba(background.r, background.g, background.b, alpha);
    }
    readonly property real mediaMetadataMarqueeGap: Kirigami.Units.gridUnit * 2
    readonly property real mediaTaskPreferredWidth: {
        const minimum = Math.max(TaskManagerApplet.LayoutMetrics.preferredMinWidth(), Plasmoid.configuration.mediaPlayerTaskMinWidth);
        if (!mediaMetadataEnabled) {
            return minimum;
        }
        const coverWidth = Math.max(TaskManagerApplet.LayoutMetrics.preferredMinHeight(), Kirigami.Units.iconSizes.medium);
        const measuredTextWidth = Plasmoid.configuration.mediaMetadataLayout === 2
            ? mediaInlineMeasure.implicitWidth
            : Math.max(mediaTrackMeasure.implicitWidth, mediaArtistMeasure.implicitWidth);
        // MPRIS metadata changes immediately, but Qt can polish a Text item's
        // implicit width later. Keep the content-width request responsive in
        // that gap with a conservative font-relative estimate.
        const displayedCharacterCount = Plasmoid.configuration.mediaMetadataLayout === 2
            ? mediaInlineText.length
            : Math.max(mediaTrackText.length, mediaArtistText.length);
        const estimatedTextWidth = displayedCharacterCount * Kirigami.Units.gridUnit * 0.42;
        const textWidth = Math.max(measuredTextWidth, estimatedTextWidth);
        // Match the metadata item's anchors: the cover starts after the left
        // frame margin, text starts after the configured art/metadata gap, and ends before the
        // right frame margin. The title metric is bold as the visible label is.
        const desired = taskFrame.margins.left + coverWidth
            + mediaAlbumArtMetadataGap + textWidth
            + mediaControlsReservation + mediaAudioIndicatorReservation + taskFrame.margins.right;
        return Math.min(
            Math.max(minimum, Plasmoid.configuration.mediaPlayerTaskMaxWidth),
            Math.max(minimum, desired));
    }
    readonly property bool mediaTaskNeedsAdditionalWidth: expandedMediaTask
        && mediaTaskPreferredWidth > Math.max(
            TaskManagerApplet.LayoutMetrics.preferredMinWidth(),
            Plasmoid.configuration.mediaPlayerTaskMinWidth) + 0.5
    onMediaTaskPreferredWidthChanged: {
        if (completed) {
            ++tasksRoot.mediaLayoutRevision;
            tasksRoot.requestLayout();
        }
    }
    readonly property bool mediaMetadataInline: Plasmoid.configuration.mediaMetadataLayout === 2
        || (Plasmoid.configuration.mediaMetadataLayout === 0
            && mediaMetadata.height < mediaMetadataStackedMinimumHeight)
    readonly property real mediaMetadataStackedMinimumHeight: Math.ceil(
        mediaTrackTitle.implicitHeight + mediaArtistLabel.implicitHeight)

    readonly property bool mediaAlbumArtEligible: Plasmoid.configuration.replaceMediaPlayerIconWithAlbumArt
        && !model.IsGroupParent
        && (mediaProgressPlaying || mediaProgressPaused)
        && !mediaPresentationExcluded
    readonly property bool mediaAlbumArtEnabled: mediaAlbumArtEligible
        && String(mediaPlayerData?.artUrl ?? "").length > 0
    readonly property string albumArtShapeName: ["square", "squircle", "rounded", "circle"][
        Math.max(0, Math.min(3, Plasmoid.configuration.albumArtShape))]
    readonly property bool rotateCircularAlbumArt: Plasmoid.configuration.rotateCircularAlbumArt
        && albumArtShapeName === "circle"
    readonly property string albumArtRotationStyleName: ["plain", "cd", "vinyl"][
        Math.max(0, Math.min(2, Plasmoid.configuration.albumArtRotationStyle))]
    readonly property real albumArtPadding: mediaAlbumArtEnabled
        ? Plasmoid.configuration.albumArtPadding
        : 0
    readonly property real mediaAlbumArtMetadataGap: mediaAlbumArtEligible
        ? Plasmoid.configuration.albumArtMetadataGap
        : TaskManagerApplet.LayoutMetrics.labelMargin
    readonly property real albumArtCornerRadius: {
        const size = Math.min(albumArtViewport.width, albumArtViewport.height);
        if (albumArtShapeName === "squircle") {
            return size * (Plasmoid.configuration.albumArtSquircleRoundness / 100);
        }
        if (albumArtShapeName === "rounded") {
            return size * 0.16;
        }
        if (albumArtShapeName === "circle") {
            return size / 2;
        }
        return 0;
    }
    readonly property bool mediaProgressVisible: Plasmoid.configuration.showMediaProgress
        && !inPopup
        && !model.IsGroupParent
        && (mediaProgressPlaying || mediaProgressPaused)
        && (mediaPlayerData?.length ?? 0) > 0
    readonly property real mediaProgress: mediaProgressVisible
        ? Math.max(0, Math.min(1, mediaPlayerData.position / mediaPlayerData.length))
        : 0
    readonly property string mediaPlayerColorSourceName: ["icon", "album"][
        Math.max(0, Math.min(1, Plasmoid.configuration.mediaPlayerColorSource))]
    readonly property string albumArtColorStrategyName: ["dominant", "accent", "average"][
        Math.max(0, Math.min(2, Plasmoid.configuration.albumArtColorStrategy))]
    readonly property bool mediaAlbumArtColorAvailable:
        mediaPlayerColorSourceName === "album"
        && !mediaPresentationExcluded
        && String(mediaPlayerData?.artUrl ?? "").length > 0
        && albumArtColors.readySourceUrl === String(mediaPlayerData?.artUrl ?? "")
        && albumArtColors.palette.length > 0
    readonly property color mediaAlbumArtColor: {
        const strategy = albumArtColorStrategyName;
        if (strategy === "dominant") {
            return albumArtColors.dominant;
        }
        if (strategy === "accent") {
            return albumArtColors.highlight;
        }
        if (albumArtColors.palette.length === 0) {
            return albumArtColors.highlight;
        }
        let red = 0;
        let green = 0;
        let blue = 0;
        for (const color of albumArtColors.palette) {
            red += color.r;
            green += color.g;
            blue += color.b;
        }
        const count = albumArtColors.palette.length;
        return Qt.rgba(red / count, green / count, blue / count, 1);
    }
    readonly property color mediaProgressColor: taskAccentColor

    function findMediaPlayer(): Mpris.PlayerContainer {
        if (model.IsGroupParent) {
            return null;
        }
        return TaskManagerApplet.TaskTools.mediaPlayerForTask(
            mpris2Source,
            model.LauncherUrlWithoutIcon,
            model.AppPid,
            model.AppId,
            Plasmoid.configuration.mediaPlayerIdAliases);
    }

    function refreshMediaPlayer(): void {
        mediaPlayerData = findMediaPlayer();
    }

    function restartMetadataMarquee(): void {
        mediaTrackTitle.x = 0;
        mediaInlineTitle.x = 0;

        if (!Plasmoid.configuration.scrollMediaMetadata) {
            return;
        }

        if (mediaMetadataInline) {
            if (mediaInlineEstimatedWidth > inlineMetadata.width) {
                if (Plasmoid.configuration.mediaMetadataScrollMode === 0) {
                    mediaInlineMarquee.restart();
                } else {
                    mediaInlineOneWayMarquee.restart();
                }
            }
        } else if (mediaTrackEstimatedWidth > mediaTrackViewport.width) {
            if (Plasmoid.configuration.mediaMetadataScrollMode === 0) {
                mediaTrackMarquee.restart();
            } else {
                mediaTrackOneWayMarquee.restart();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: task.mediaProgressVisible && task.mediaProgressPlaying
        triggeredOnStart: true
        onTriggered: task.mediaPlayerData?.updatePosition()
    }

    // Switching between stacked and inline metadata does not alter the track
    // string, so no label text signal is emitted to restart its marquee.
    Timer {
        id: metadataMarqueeRestartTimer

        interval: 50
        repeat: false
        onTriggered: task.restartMetadataMarquee()
    }

    Timer {
        id: mediaControlsHoverDelayTimer
        interval: Math.max(0, Plasmoid.configuration.wideMediaControlsHoverDelay)
        repeat: false
        onTriggered: task.mediaControlsHoverReady = true
    }

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && (containsMouse || mediaTaskControlsHover.hovered))
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)
    readonly property bool colorHover: !inPopup && (containsMouse || mediaTaskControlsHover.hovered)
        && Plasmoid.configuration.taskHoverEffect
    readonly property color taskAccentColor: {
        if (!Plasmoid.configuration.dynamicActiveBackground) {
            return Plasmoid.configuration.fixedActiveBackgroundColor;
        }
        const extractedColor = mediaAlbumArtColorAvailable
            ? mediaAlbumArtColor
            : (Plasmoid.configuration.activeColorSource === 1
                ? taskIconColors.dominant
                : taskIconColors.highlight);
        return ensurePanelContrast(extractedColor);
    }

    function ensurePanelContrast(extractedColor: color): color {
        if (extractedColor.a < 0.05) {
            return Plasmoid.configuration.fixedActiveBackgroundColor;
        }

        const panelLuma = Kirigami.ColorUtils.grayForColor(Kirigami.Theme.backgroundColor);
        const colorLuma = Kirigami.ColorUtils.grayForColor(extractedColor);
        if (Math.abs(panelLuma - colorLuma) < 0.22) {
            const contrastTarget = panelLuma < 0.5 ? "white" : "black";
            return Kirigami.ColorUtils.linearInterpolation(extractedColor, contrastTarget, 0.45);
        }
        return extractedColor;
    }

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    onXChanged: {
        if (!completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!completed) {
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }

    property real oldX: -1
    property real oldY: -1
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18nc("@info:usagetip %1 task name", "Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.mediaControlsHoverReady = false;
            if (!task.mediaControlsAlwaysVisible) {
                mediaControlsHoverDelayTimer.start();
            }
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            mediaControlsHoverDelayTimer.stop();
            task.mediaControlsHoverReady = false;
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: {
        updateAudioStreams({delay: false});
        refreshMediaPlayer();
    }
    onAppNameChanged: updateAudioStreams({delay: false})

    Connections {
        target: Plasmoid.configuration

        function onMediaPlayerIdAliasesChanged(): void {
            task.refreshMediaPlayer();
        }

        function onMediaMetadataLayoutChanged(): void {
            metadataMarqueeRestartTimer.restart();
        }

        function onScrollMediaMetadataChanged(): void {
            metadataMarqueeRestartTimer.restart();
        }

        function onMediaMetadataScrollModeChanged(): void {
            metadataMarqueeRestartTimer.restart();
        }
    }

    Connections {
        target: mpris2Source

        function onRowsInserted(): void {
            task.refreshMediaPlayer();
        }

        function onRowsRemoved(): void {
            task.refreshMediaPlayer();
        }

        function onDataChanged(): void {
            if (!task.mediaPlayerData) {
                task.refreshMediaPlayer();
            }
        }
    }

    onIsWindowChanged: {
        refreshMediaPlayer();
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskManagerApplet.TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("plasma.applet.org.janzon.plasma.dynamicicontasks", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();

            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);

            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskManagerApplet.TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args) as ContextMenu;
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? (smartLauncherItem?.count ?? 0) : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({showAllPlaces: true})
            } else {
                task.showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            if (task.active) {
                task.hideToolTip();
            }
            TaskManagerApplet.TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    TaskManagerApplet.TaskTools.foreachChildTask((childIndex) => {
                        tasksModel.requestVirtualDesktops(childIndex, [virtualDesktopInfo.currentDesktopByScreenGeometry(tasksModel.data(childIndex, TaskManager.AbstractTasksModel.ScreenGeometry))]);
                    }, modelIndex(), tasksModel);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = task.mediaPlayerData;
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame

        anchors {
            fill: parent

            topMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            bottomMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            leftMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            rightMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
        }

        imagePath: "widgets/tasks"
        // Custom indicator modes use the icon-derived layer below. Standard
        // mode restores the Plasma theme's own hover and task frames.
        property bool isHovered: Plasmoid.configuration.runningIndicatorStyle === 0
            && task.highlighted
        property string basePrefix: "normal"
        prefix: isHovered ? TaskManagerApplet.TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskManagerApplet.TaskTools.taskPrefix(basePrefix, Plasmoid.location)
        opacity: Plasmoid.configuration.runningIndicatorStyle === 0
            || basePrefix === "attention" ? 1 : 0

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                // This is modifying the value in the panel containment that
                // inhibits accepting drag and drop, so that we don't accidentally
                // drop the task on this panel.
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                    iconBox.grabToImage(result => {
                        if (!dragHandler.active) {
                            // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Kirigami.ImageColors {
        id: taskIconColors

        source: task.model.decoration
        fallbackDominant: Plasmoid.configuration.fixedActiveBackgroundColor
        fallbackHighlight: Plasmoid.configuration.fixedActiveBackgroundColor
    }

    // This remains independent from album-art icon replacement: a player can
    // keep its app icon while its progress indicator follows the current cover.
    // ImageColors needs the decoded Image rather than a raw MPRIS URL, and the
    // small source size keeps this color-only load inexpensive.
    Image {
        id: albumArtColorSource

        property string scheduledSourceUrl: ""

        function schedulePaletteUpdate(): void {
            const readyUrl = String(source);
            if (status !== Image.Ready || readyUrl.length === 0
                    || scheduledSourceUrl === readyUrl) {
                return;
            }

            scheduledSourceUrl = readyUrl;
            Qt.callLater(() => {
                scheduledSourceUrl = "";
                if (status !== Image.Ready || String(source) !== readyUrl) {
                    return;
                }
                albumArtColors.pendingSourceUrl = readyUrl;
                albumArtColors.update();
            });
        }

        visible: false
        asynchronous: true
        cache: true
        source: task.mediaPresentationExcluded ? "" : (task.mediaPlayerData?.artUrl ?? "")
        sourceSize.width: 128
        sourceSize.height: 128

        onSourceChanged: {
            albumArtColors.readySourceUrl = "";
            schedulePaletteUpdate();
        }
        onStatusChanged: schedulePaletteUpdate()
    }

    Kirigami.ImageColors {
        id: albumArtColors

        property string pendingSourceUrl: ""
        property string readySourceUrl: ""

        source: albumArtColorSource

        onPaletteChanged: {
            const currentSourceUrl = String(albumArtColorSource.source);
            readySourceUrl = albumArtColorSource.status === Image.Ready
                && currentSourceUrl === pendingSourceUrl
                ? pendingSourceUrl
                : "";
        }
    }

    Rectangle {
        id: taskColorBackground

        function limitedRadius(configuredRadius: real): real {
            return Math.min(configuredRadius, Math.min(width, height) / 2);
        }

        anchors.fill: parent
        anchors.margins: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
        visible: Plasmoid.configuration.runningIndicatorStyle !== 0
            && !task.inPopup
            && ((!task.model.IsLauncher && task.model.IsActive) || task.colorHover)
        radius: 0
        topLeftRadius: limitedRadius(Plasmoid.configuration.individualCornerRadii
            ? Plasmoid.configuration.activeBackgroundTopLeftRadius
            : Plasmoid.configuration.activeBackgroundRadius)
        topRightRadius: limitedRadius(Plasmoid.configuration.individualCornerRadii
            ? Plasmoid.configuration.activeBackgroundTopRightRadius
            : Plasmoid.configuration.activeBackgroundRadius)
        bottomLeftRadius: limitedRadius(Plasmoid.configuration.individualCornerRadii
            ? Plasmoid.configuration.activeBackgroundBottomLeftRadius
            : Plasmoid.configuration.activeBackgroundRadius)
        bottomRightRadius: limitedRadius(Plasmoid.configuration.individualCornerRadii
            ? Plasmoid.configuration.activeBackgroundBottomRightRadius
            : Plasmoid.configuration.activeBackgroundRadius)
        color: task.taskAccentColor
        opacity: task.model.IsActive
            ? Math.min(0.6, Plasmoid.configuration.activeBackgroundOpacity / 100)
            : Math.min(0.45, (Plasmoid.configuration.activeBackgroundOpacity / 100) * 0.72)

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: frame
        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox

        property bool firstAlbumArtLayerActive: true
        property string desiredAlbumArtUrl: task.mediaAlbumArtEnabled
            ? String(task.mediaPlayerData.artUrl)
            : ""

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
        }

        width: task.inPopup ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min(task.parent?.minimumWidth ?? 0, task.height)
        height: task.inPopup ? width : (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top)
                 - adjustMargin(false, parent.height, taskFrame.margins.bottom))

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small
                && task.smartLauncherItem && task.smartLauncherItem.countVisible
        source: "TaskBadgeOverlay.qml"

        onDesiredAlbumArtUrlChanged: updateAlbumArt(desiredAlbumArtUrl)

        Component.onCompleted: updateAlbumArt(desiredAlbumArtUrl)

        function updateAlbumArt(url) {
            if (!url) {
                if (task.mediaAlbumArtEligible) {
                    // MPRIS players often clear ArtUrl briefly between tracks. Keep
                    // the old cover while waiting instead of flashing the app icon.
                    albumArtFallbackTimer.restart();
                } else {
                    hideAlbumArt();
                }
                return;
            }

            albumArtFallbackTimer.stop();
            albumArtCleanupTimer.stop();

            const currentLayer = firstAlbumArtLayerActive ? albumArtFirst : albumArtSecond;
            if (String(currentLayer.source) === url && currentLayer.status === Image.Ready) {
                currentLayer.opacity = 1;
                return;
            }

            const loadingLayer = firstAlbumArtLayerActive ? albumArtSecond : albumArtFirst;
            const loadingFirstLayer = !firstAlbumArtLayerActive;
            loadingLayer.opacity = 0;

            // Going back to a recent track can reuse the cover that is already
            // ready in the inactive buffer. Reassigning the same source does not
            // emit statusChanged, so promote it explicitly.
            if (String(loadingLayer.source) === url && loadingLayer.status === Image.Ready) {
                commitAlbumArt(loadingFirstLayer, url);
                return;
            }

            loadingLayer.source = url;
        }

        function commitAlbumArt(firstLayer, url) {
            if (!desiredAlbumArtUrl || String(url) !== desiredAlbumArtUrl) {
                return;
            }

            firstAlbumArtLayerActive = firstLayer;
            albumArtFirst.opacity = firstLayer ? 1 : 0;
            albumArtSecond.opacity = firstLayer ? 0 : 1;
        }

        function albumArtLoadFailed(url) {
            if (String(url) === desiredAlbumArtUrl) {
                hideAlbumArt();
            }
        }

        function hideAlbumArt() {
            albumArtFallbackTimer.stop();
            albumArtFirst.opacity = 0;
            albumArtSecond.opacity = 0;
            albumArtCleanupTimer.restart();
        }

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) {
                return margin;
            }

            var margins = isVertical ? TaskManagerApplet.LayoutMetrics.horizontalMargins() : TaskManagerApplet.LayoutMetrics.verticalMargins();

            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;
        }

        Kirigami.Icon {
            id: icon

            anchors.fill: parent

            active: task.highlighted
            enabled: true
            visible: true

            source: task.model.decoration
        }

        Item {
            id: albumArtViewport

            property real albumArtRotationAngle: 0

            anchors.centerIn: parent
            width: Math.max(0, (task.albumArtShapeName === "circle"
                ? Math.min(parent.width, parent.height)
                : parent.width) - (task.albumArtPadding * 2))
            height: Math.max(0, (task.albumArtShapeName === "circle"
                ? Math.min(parent.width, parent.height)
                : parent.height) - (task.albumArtPadding * 2))

            Rectangle {
                id: albumArtMask

                anchors.fill: parent
                visible: false
                radius: task.albumArtCornerRadius
                color: "white"
            }

            Image {
                id: albumArtFirst

                anchors.fill: parent
                visible: false
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                opacity: 0

                onStatusChanged: {
                    if (status === Image.Ready) {
                        iconBox.commitAlbumArt(true, source);
                    } else if (status === Image.Error) {
                        iconBox.albumArtLoadFailed(source);
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Image {
                id: albumArtSecond

                anchors.fill: parent
                visible: false
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                opacity: 0

                onStatusChanged: {
                    if (status === Image.Ready) {
                        iconBox.commitAlbumArt(false, source);
                    } else if (status === Image.Error) {
                        iconBox.albumArtLoadFailed(source);
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            GE.OpacityMask {
                anchors.fill: parent
                source: albumArtFirst
                maskSource: albumArtMask
                visible: albumArtFirst.opacity > 0
                opacity: albumArtFirst.opacity
                rotation: albumArtViewport.albumArtRotationAngle
            }

            GE.OpacityMask {
                anchors.fill: parent
                source: albumArtSecond
                maskSource: albumArtMask
                visible: albumArtSecond.opacity > 0
                opacity: albumArtSecond.opacity
                rotation: albumArtViewport.albumArtRotationAngle
            }

            Item {
                id: albumArtDiscStyle

                anchors.fill: parent
                z: 1
                visible: task.mediaAlbumArtEnabled
                    && task.albumArtShapeName === "circle"
                    && task.albumArtRotationStyleName !== "plain"
                rotation: albumArtViewport.albumArtRotationAngle

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: task.albumArtRotationStyleName === "cd" ? 2 : 1
                    border.color: task.albumArtRotationStyleName === "cd"
                        ? Qt.rgba(1, 1, 1, 0.32)
                        : Qt.rgba(0, 0, 0, 0.48)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (task.albumArtRotationStyleName === "cd" ? 0.16 : 0.12)
                    height: width
                    radius: width / 2
                    color: task.albumArtRotationStyleName === "cd"
                        ? Qt.rgba(1, 1, 1, 0.24)
                        : Qt.rgba(0, 0, 0, 0.62)
                    border.width: 1
                    border.color: task.albumArtRotationStyleName === "cd"
                        ? Qt.rgba(1, 1, 1, 0.5)
                        : Qt.rgba(1, 1, 1, 0.25)
                }

                Rectangle {
                    visible: task.albumArtRotationStyleName === "vinyl"
                    anchors.centerIn: parent
                    width: parent.width * 0.42
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.38)
                }

                Rectangle {
                    visible: task.albumArtRotationStyleName === "vinyl"
                    anchors.centerIn: parent
                    width: parent.width * 0.68
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.28)
                }
            }

            NumberAnimation {
                target: albumArtViewport
                property: "albumArtRotationAngle"
                from: 0
                to: 360
                duration: 8000
                loops: Animation.Infinite
                running: task.mediaAlbumArtEnabled
                    && task.rotateCircularAlbumArt
                    && task.mediaProgressPlaying
            }

            Rectangle {
                id: albumArtPausedShade

                anchors.fill: parent
                z: 1
                radius: task.albumArtCornerRadius
                color: Qt.rgba(0, 0, 0, 0.5)
                visible: task.mediaAlbumArtEnabled
                    && (albumArtFirst.opacity > 0 || albumArtSecond.opacity > 0)
                opacity: task.mediaProgressPaused ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.42
                    height: width
                    source: "media-playback-pause"
                    color: Kirigami.Theme.textColor
                }
            }
        }

        Timer {
            id: albumArtFallbackTimer

            interval: 1000
            onTriggered: {
                if (!iconBox.desiredAlbumArtUrl) {
                    iconBox.hideAlbumArt();
                }
            }
        }

        Timer {
            id: albumArtCleanupTimer

            interval: 230
            onTriggered: {
                if (!iconBox.desiredAlbumArtUrl) {
                    albumArtFirst.source = "";
                    albumArtSecond.source = "";
                }
            }
        }

        Kirigami.ShadowedRectangle {
            id: albumArtAppBadge

            z: 2
            visible: (albumArtFirst.opacity > 0 || albumArtSecond.opacity > 0)
                && Plasmoid.configuration.showAppIconOnAlbumArt
            width: Math.max(10, Math.round(Math.min(iconBox.width, iconBox.height) * 0.42))
            height: width
            anchors.right: albumArtViewport.right
            anchors.bottom: albumArtViewport.bottom
            radius: width / 2
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.textColor
            shadow.size: Math.max(2, Math.round(width * 0.18))
            shadow.xOffset: 0
            shadow.yOffset: Math.max(1, Math.round(width * 0.06))
            shadow.color: Qt.rgba(0, 0, 0, 0.55)

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: Math.max(1, Math.round(parent.width * 0.12))
                source: task.model.decoration
            }
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible && !task.expandedMediaTask && task.parent

                AnchorChanges {
                    target: iconBox
                    anchors.left: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PropertyChanges {
                    iconBox.anchors.leftMargin: 0
                    iconBox.width: Math.min(task.parent.minimumWidth, tasksRoot.height)
                        - iconBox.adjustMargin(true, task.width, taskFrame.margins.left)
                        - iconBox.adjustMargin(true, task.width, taskFrame.margins.right)
                }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: task.model.IsStartup
            sourceComponent: busyIndicator
        }
    }

    Item {
        id: mediaMetadata

        visible: task.mediaMetadataEnabled
        z: 1
        anchors {
            left: iconBox.right
            leftMargin: task.mediaAlbumArtMetadataGap
            right: parent.right
            rightMargin: taskFrame.margins.right + task.mediaControlsReservation
                + task.mediaAudioIndicatorReservation
            top: parent.top
            bottom: parent.bottom
            topMargin: taskFrame.margins.top
            bottomMargin: taskFrame.margins.bottom
        }

        Column {
            id: stackedMetadata

            anchors.fill: parent
            z: 1
            visible: !task.mediaMetadataInline
            spacing: 0

            Item {
                id: mediaTrackViewport

                width: parent.width
                height: parent.height / 2
                clip: true
                onVisibleChanged: if (visible) metadataMarqueeRestartTimer.restart()
                onWidthChanged: if (visible) metadataMarqueeRestartTimer.restart()

                PlasmaComponents3.Label {
                    id: mediaTrackTitle

                    x: 0
                    width: task.mediaTrackMarqueeWidth
                    height: parent.height
                    text: task.mediaTrackText
                    font: {
                        const titleFont = Kirigami.Theme.defaultFont;
                        titleFont.bold = true;
                        return titleFont;
                    }
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: metadataMarqueeRestartTimer.restart()
                }

                // The duplicate makes a one-direction marquee wrap without a
                // visible jump: as it reaches x=0, the original starts again.
                PlasmaComponents3.Label {
                    id: mediaTrackTitleLoopCopy

                    visible: Plasmoid.configuration.scrollMediaMetadata
                        && Plasmoid.configuration.mediaMetadataScrollMode === 1
                        && task.mediaTrackEstimatedWidth > mediaTrackViewport.width
                    x: mediaTrackTitle.x + task.mediaTrackMarqueeWidth + task.mediaMetadataMarqueeGap
                    width: task.mediaTrackMarqueeWidth
                    height: parent.height
                    text: task.mediaTrackText
                    font: mediaTrackTitle.font
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                    verticalAlignment: Text.AlignVCenter
                }

                SequentialAnimation {
                    id: mediaTrackMarquee

                    running: mediaTrackViewport.visible
                        && Plasmoid.configuration.scrollMediaMetadata
                        && Plasmoid.configuration.mediaMetadataScrollMode === 0
                        && task.mediaTrackEstimatedWidth > mediaTrackViewport.width
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        target: mediaTrackTitle
                        property: "x"
                        from: 0
                        to: -(task.mediaTrackMarqueeWidth - mediaTrackViewport.width)
                        duration: Math.max(Kirigami.Units.longDuration * 3,
                            (task.mediaTrackMarqueeWidth - mediaTrackViewport.width) * 18)
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation {
                        duration: 1000
                    }
                    NumberAnimation {
                        target: mediaTrackTitle
                        property: "x"
                        to: 0
                        duration: Math.max(Kirigami.Units.longDuration * 3,
                            (task.mediaTrackMarqueeWidth - mediaTrackViewport.width) * 18)
                        easing.type: Easing.InOutSine
                    }
                }

                SequentialAnimation {
                    id: mediaTrackOneWayMarquee

                    running: mediaTrackViewport.visible
                        && Plasmoid.configuration.scrollMediaMetadata
                        && Plasmoid.configuration.mediaMetadataScrollMode === 1
                        && task.mediaTrackEstimatedWidth > mediaTrackViewport.width
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: mediaTrackTitle
                        property: "x"
                        from: 0
                        to: -(task.mediaTrackMarqueeWidth + task.mediaMetadataMarqueeGap)
                        duration: Math.max(Kirigami.Units.longDuration * 3,
                            (task.mediaTrackMarqueeWidth + task.mediaMetadataMarqueeGap) * 18)
                        easing.type: Easing.Linear
                    }
                }

                Rectangle {
                    z: 1
                    width: Math.min(Kirigami.Units.gridUnit, parent.width / 3)
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: task.mediaTrackEstimatedWidth > parent.width
                        && (Plasmoid.configuration.mediaMetadataScrollMode === 1
                            ? mediaTrackTitleLoopCopy.x + mediaTrackTitleLoopCopy.width
                                > parent.width + 0.5
                            : mediaTrackTitle.x + task.mediaTrackMarqueeWidth
                                > parent.width + 0.5)
                        && !task.highlighted && !task.model.IsActive
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(task.mediaMetadataFadeColor.r, task.mediaMetadataFadeColor.g, task.mediaMetadataFadeColor.b, 0) }
                        GradientStop { position: 1; color: task.mediaMetadataFadeColor }
                    }
                }

                Rectangle {
                    z: 1
                    width: Math.min(Kirigami.Units.gridUnit, parent.width / 3)
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: task.mediaTrackEstimatedWidth > parent.width && mediaTrackTitle.x < -0.5
                        && !task.highlighted && !task.model.IsActive
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: task.mediaMetadataFadeColor }
                        GradientStop { position: 1; color: Qt.rgba(task.mediaMetadataFadeColor.r, task.mediaMetadataFadeColor.g, task.mediaMetadataFadeColor.b, 0) }
                    }
                }
            }

            PlasmaComponents3.Label {
                id: mediaArtistLabel

                width: parent.width
                height: parent.height / 2
                text: task.mediaArtistText
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            id: mediaVisualizer

            z: 0
            opacity: Math.max(0.05, Math.min(1,
                Plasmoid.configuration.mediaVisualizerOpacity / 100))
            anchors.left: parent.left
            width: parent.width + task.mediaControlsReservation
                + task.mediaAudioIndicatorReservation
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0.05, Math.min(0.8,
                Plasmoid.configuration.mediaVisualizerMaxHeight / 100))
            visible: Plasmoid.configuration.showMediaVisualizer
                && task.mediaProgressPlaying
                && (task.tasksRoot.visualizer?.values?.length ?? 0) > 0
            clip: true

            readonly property real configuredBarWidth: Math.max(1,
                Plasmoid.configuration.mediaVisualizerBarWidth)
            readonly property real barSpacing: Math.max(0,
                Plasmoid.configuration.mediaVisualizerBarGap)
            readonly property int visibleBarCount: Math.max(1, Math.min(
                task.tasksRoot.visualizer?.values?.length ?? 1,
                Math.floor((width + barSpacing) / (configuredBarWidth + barSpacing))))

            Item {
                id: mediaVisualizerCanvas
                anchors.fill: parent
                Repeater {
                    id: mediaVisualizerBarRepeater
                    model: mediaVisualizer.visibleBarCount

                    Rectangle {
                        required property int index
                        readonly property int sourceIndex: Math.min(
                            (task.tasksRoot.visualizer?.values?.length ?? 1) - 1,
                            Math.floor(index * (task.tasksRoot.visualizer?.values?.length ?? 1)
                                / Math.max(1, mediaVisualizerBarRepeater.count)))
                        readonly property real level: task.tasksRoot.visualizer?.values?.[sourceIndex] ?? 0
                        width: Math.min(mediaVisualizer.configuredBarWidth,
                            Math.max(1, mediaVisualizerCanvas.width - x))
                        height: Math.max(1, mediaVisualizer.height * Math.min(1,
                            level * Plasmoid.configuration.mediaVisualizerSensitivity / 100))
                        x: index * (mediaVisualizer.configuredBarWidth + mediaVisualizer.barSpacing)
                        anchors.bottom: mediaVisualizerCanvas.bottom
                        radius: width / 2
                        color: task.mediaProgressColor
                        opacity: 0.82
                    }
                }
            }
        }

        Item {
            id: inlineMetadata

            anchors.fill: parent
            z: 1
            visible: task.mediaMetadataInline
            clip: true
            onVisibleChanged: if (visible) metadataMarqueeRestartTimer.restart()
            onWidthChanged: if (visible) metadataMarqueeRestartTimer.restart()

            PlasmaComponents3.Label {
                id: mediaInlineTitle

                x: 0
                width: task.mediaInlineMarqueeWidth
                height: parent.height
                text: task.mediaInlineText
                elide: Text.ElideNone
                wrapMode: Text.NoWrap
                font: Kirigami.Theme.defaultFont
                verticalAlignment: Text.AlignVCenter
                onTextChanged: metadataMarqueeRestartTimer.restart()
            }

            PlasmaComponents3.Label {
                id: mediaInlineTitleLoopCopy

                visible: Plasmoid.configuration.scrollMediaMetadata
                    && Plasmoid.configuration.mediaMetadataScrollMode === 1
                    && task.mediaInlineEstimatedWidth > inlineMetadata.width
                x: mediaInlineTitle.x + task.mediaInlineMarqueeWidth + task.mediaMetadataMarqueeGap
                width: task.mediaInlineMarqueeWidth
                height: parent.height
                text: task.mediaInlineText
                font: mediaInlineTitle.font
                elide: Text.ElideNone
                wrapMode: Text.NoWrap
                verticalAlignment: Text.AlignVCenter
            }

            SequentialAnimation {
                id: mediaInlineMarquee

                running: inlineMetadata.visible
                    && Plasmoid.configuration.scrollMediaMetadata
                    && Plasmoid.configuration.mediaMetadataScrollMode === 0
                    && task.mediaInlineEstimatedWidth > inlineMetadata.width
                loops: Animation.Infinite

                PauseAnimation {
                    duration: 1200
                }
                NumberAnimation {
                    target: mediaInlineTitle
                    property: "x"
                    from: 0
                    to: -(task.mediaInlineMarqueeWidth - inlineMetadata.width)
                    duration: Math.max(Kirigami.Units.longDuration * 3,
                        (task.mediaInlineMarqueeWidth - inlineMetadata.width) * 18)
                    easing.type: Easing.InOutSine
                }
                PauseAnimation {
                    duration: 1000
                }
                NumberAnimation {
                    target: mediaInlineTitle
                    property: "x"
                    to: 0
                    duration: Math.max(Kirigami.Units.longDuration * 3,
                        (task.mediaInlineMarqueeWidth - inlineMetadata.width) * 18)
                    easing.type: Easing.InOutSine
                    }
                }
            }

            SequentialAnimation {
                id: mediaInlineOneWayMarquee

                running: inlineMetadata.visible
                    && Plasmoid.configuration.scrollMediaMetadata
                    && Plasmoid.configuration.mediaMetadataScrollMode === 1
                    && task.mediaInlineEstimatedWidth > inlineMetadata.width
                loops: Animation.Infinite

                NumberAnimation {
                    target: mediaInlineTitle
                    property: "x"
                    from: 0
                    to: -(task.mediaInlineMarqueeWidth + task.mediaMetadataMarqueeGap)
                    duration: Math.max(Kirigami.Units.longDuration * 3,
                        (task.mediaInlineMarqueeWidth + task.mediaMetadataMarqueeGap) * 18)
                    easing.type: Easing.Linear
                }
            }

            Rectangle {
                z: 1
                width: Math.min(Kirigami.Units.gridUnit, parent.width / 3)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: task.mediaInlineEstimatedWidth > parent.width
                    && (Plasmoid.configuration.mediaMetadataScrollMode === 1
                        ? mediaInlineTitleLoopCopy.x + mediaInlineTitleLoopCopy.width
                            > parent.width + 0.5
                        : mediaInlineTitle.x + task.mediaInlineMarqueeWidth
                            > parent.width + 0.5)
                    && !task.highlighted && !task.model.IsActive
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(task.mediaMetadataFadeColor.r, task.mediaMetadataFadeColor.g, task.mediaMetadataFadeColor.b, 0) }
                    GradientStop { position: 1; color: task.mediaMetadataFadeColor }
                }
            }

            Rectangle {
                z: 1
                width: Math.min(Kirigami.Units.gridUnit, parent.width / 3)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: task.mediaInlineEstimatedWidth > parent.width && mediaInlineTitle.x < -0.5
                    && !task.highlighted && !task.model.IsActive
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: task.mediaMetadataFadeColor }
                    GradientStop { position: 1; color: Qt.rgba(task.mediaMetadataFadeColor.r, task.mediaMetadataFadeColor.g, task.mediaMetadataFadeColor.b, 0) }
                }
        }
    }

    Item {
        id: mediaTaskTimeLabel

        z: 2
        visible: task.mediaTimeVisible
        anchors.right: parent.right
        anchors.rightMargin: taskFrame.margins.right
        anchors.verticalCenter: parent.verticalCenter
        width: timeLabel.implicitWidth
        height: timeLabel.implicitHeight

        PlasmaComponents3.Label {
            id: timeLabel
            text: task.formatMediaTime(task.mediaPlayerData?.position ?? 0)
                + " / " + task.formatMediaTime(task.mediaPlayerData?.length ?? 0)
            color: task.mediaProgressColor
            opacity: 0.9
            font: Kirigami.Theme.smallFont
        }

        GE.DropShadow {
            anchors.fill: timeLabel
            z: -1
            source: timeLabel
            horizontalOffset: 1
            verticalOffset: 1
            radius: 2
            samples: 7
            color: Qt.rgba(0, 0, 0, 0.78)
        }
    }

    // Keep the diffuse field within the task even when its edge spreads beyond
    // the controls themselves. This avoids tinting neighboring panel items.
    Item {
        id: mediaControlsBackdropBounds

        visible: task.mediaControlsAvailable && task.mediaControlsBlendIntoTask
        opacity: mediaTaskControls.opacity
        z: 1.5
        anchors.fill: parent
        clip: true

        GE.RadialGradient {
            readonly property real spread: Math.round(Kirigami.Units.gridUnit * 1.25)

            x: Math.max(0, mediaTaskControls.x - spread)
            y: Math.max(0, mediaTaskControls.y - spread)
            width: Math.min(parent.width - x, mediaTaskControls.width + (spread * 2))
            height: Math.min(parent.height - y, mediaTaskControls.height + (spread * 2))
            horizontalRadius: width * 0.58
            verticalRadius: height * 0.78
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.42) }
                GradientStop { position: 0.38; color: Qt.rgba(0, 0, 0, 0.26) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
    }

    Item {
        id: mediaTaskControls

        visible: task.mediaControlsAvailable
        enabled: opacity > 0
        z: 2
        width: task.mediaControlsWidth
        height: task.mediaControlsButtonSize
        opacity: task.mediaControlsAlwaysVisible || task.mediaControlsHoverReady || task.toolTipOpen ? 1 : 0
        anchors {
            right: parent.right
            rightMargin: taskFrame.margins.right + task.mediaAudioIndicatorReservation
            verticalCenter: parent.verticalCenter
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        // The solid option is deliberately a conventional raised control
        // surface. The diffuse option below has no hard surface or shadow.
        Kirigami.ShadowedRectangle {
            visible: !task.mediaControlsBlendIntoTask
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b,
                0.78)
            shadow.size: Math.max(6, Math.round(Kirigami.Units.gridUnit * 1.75))
            shadow.xOffset: 0
            shadow.yOffset: 1
            shadow.color: Qt.rgba(0, 0, 0, 0.32)
        }

        HoverHandler {
            id: mediaTaskControlsHover
        }

        Row {
            z: 1
            anchors {
                fill: parent
                leftMargin: task.mediaControlsHorizontalPadding
                rightMargin: task.mediaControlsHorizontalPadding
            }
            spacing: Kirigami.Units.smallSpacing

            PanelMediaControlButton {
                visible: Plasmoid.configuration.showWideMediaPrevious
                width: visible ? task.mediaControlsButtonSize : 0
                height: width
                toolTipArea: task
                enabled: task.mediaPlayerData?.canGoPrevious ?? false
                iconSource: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-forward" : "media-skip-backward"
                accessibleName: i18nc("@action:button", "Previous track")
                onTriggered: task.mediaPlayerData?.Previous()
            }

            PanelMediaControlButton {
                visible: Plasmoid.configuration.showWideMediaPlayPause
                width: visible ? task.mediaControlsButtonSize : 0
                height: width
                toolTipArea: task
                enabled: task.mediaProgressPlaying
                    ? (task.mediaPlayerData?.canPause ?? false)
                    : (task.mediaPlayerData?.canPlay ?? false)
                iconSource: task.mediaProgressPlaying
                    ? "media-playback-pause" : "media-playback-start"
                accessibleName: task.mediaProgressPlaying
                    ? i18nc("@action:button", "Pause")
                    : i18nc("@action:button", "Play")
                onTriggered: {
                    if (task.mediaProgressPlaying) {
                        task.mediaPlayerData?.Pause();
                    } else {
                        task.mediaPlayerData?.Play();
                    }
                }
            }

            PanelMediaControlButton {
                visible: Plasmoid.configuration.showWideMediaNext
                width: visible ? task.mediaControlsButtonSize : 0
                height: width
                toolTipArea: task
                enabled: task.mediaPlayerData?.canGoNext ?? false
                iconSource: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-backward" : "media-skip-forward"
                accessibleName: i18nc("@action:button", "Next track")
                onTriggered: task.mediaPlayerData?.Next()
            }

            PanelMediaControlButton {
                visible: Plasmoid.configuration.showWideMediaShuffle
                    && task.mediaPlayerData?.shuffle !== Mpris.ShuffleStatus.Unknown
                width: visible ? task.mediaControlsButtonSize : 0
                height: width
                toolTipArea: task
                enabled: task.mediaPlayerData?.canControl ?? false
                checkable: true
                checked: task.mediaPlayerData?.shuffle === Mpris.ShuffleStatus.On
                iconSource: "media-playlist-shuffle"
                accessibleName: i18nc("@action:button", "Toggle shuffle")
                onTriggered: task.mediaPlayerData.shuffle = checked
                    ? Mpris.ShuffleStatus.Off : Mpris.ShuffleStatus.On
            }

            PanelMediaControlButton {
                visible: Plasmoid.configuration.showWideMediaRepeat
                    && task.mediaPlayerData?.loopStatus !== Mpris.LoopStatus.Unknown
                width: visible ? task.mediaControlsButtonSize : 0
                height: width
                toolTipArea: task
                enabled: task.mediaPlayerData?.canControl ?? false
                checkable: true
                checked: task.mediaPlayerData?.loopStatus !== Mpris.LoopStatus.None
                iconSource: task.mediaPlayerData?.loopStatus === Mpris.LoopStatus.Track
                    ? "media-repeat-single" : "media-playlist-repeat"
                accessibleName: i18nc("@action:button", "Cycle repeat mode")
                onTriggered: {
                    const loopStatus = task.mediaPlayerData.loopStatus;
                    task.mediaPlayerData.loopStatus = loopStatus === Mpris.LoopStatus.None
                        ? Mpris.LoopStatus.Playlist
                        : (loopStatus === Mpris.LoopStatus.Playlist
                            ? Mpris.LoopStatus.Track : Mpris.LoopStatus.None);
                }
            }
        }
    }

    // These are independent from the metadata item's assigned width. Using the
    // rendered labels' implicit widths creates a feedback loop because those
    // labels fill the task whose preferred width is being calculated.
    Text {
        id: mediaTrackMeasure

        opacity: 0
        width: 0
        height: 0
        text: task.mediaTrackText
        font: {
            const titleFont = Kirigami.Theme.defaultFont;
            titleFont.bold = true;
            return titleFont;
        }
    }

    Text {
        id: mediaArtistMeasure

        opacity: 0
        width: 0
        height: 0
        text: task.mediaArtistText
        font: Kirigami.Theme.smallFont
    }

    Text {
        id: mediaInlineMeasure

        opacity: 0
        width: 0
        height: 0
        text: task.mediaInlineText
        font: Kirigami.Theme.defaultFont
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher
            && !task.mediaMetadataEnabled
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= TaskManagerApplet.LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + TaskManagerApplet.LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + task.mediaControlsReservation
                + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + TaskManagerApplet.LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        // The accessible item of this element is only used for debugging
        // purposes, and it will never gain focus (thus it won't interfere
        // with screenreaders).
        Accessible.ignored: !visible
        Accessible.name: parent.Accessible.name + "-labelhint"

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }

    Item {
        id: runningIndicator

        readonly property int indicatorStyle: Plasmoid.configuration.runningIndicatorStyle
        readonly property bool verticalIndicator: Plasmoid.location === PlasmaCore.Types.LeftEdge
            || Plasmoid.location === PlasmaCore.Types.RightEdge
        readonly property real indicatorThickness: Math.min(
            Plasmoid.configuration.runningIndicatorThickness,
            verticalIndicator ? task.width / 4 : task.height / 4)
        readonly property real edgeInset: Math.max(3, Kirigami.Units.smallSpacing)
        readonly property int windowCount: Math.max(1, task.model.ChildCount || 1)
        readonly property int segmentCount: windowCount
        readonly property bool showsMediaProgress: task.mediaProgressVisible && segmentCount === 1
        readonly property int activeSegmentIndex: {
            if (!task.model.IsGroupParent) {
                return task.model.IsActive ? 0 : -1;
            }

            const activeTask = tasksModel.activeTask;
            if (!activeTask) {
                return -1;
            }

            for (let child = 0; child < windowCount; ++child) {
                if (tasksModel.makeModelIndex(task.index, child) === activeTask) {
                    return child;
                }
            }
            return -1;
        }
        readonly property real availableLength: verticalIndicator ? height : width
        readonly property real segmentGap: segmentCount > 1
            ? Math.min(2, availableLength / (segmentCount * 3))
            : 0
        readonly property real segmentLength: Math.max(0,
            (availableLength - (segmentGap * (segmentCount - 1))) / segmentCount)
        readonly property real inactiveMarkerLength: Math.min(segmentLength,
            Math.max(indicatorThickness, Plasmoid.configuration.inactiveMarkerMinimumLength))
        readonly property real emphasizedSegmentLength: Math.max(inactiveMarkerLength,
            availableLength - ((segmentCount - 1) * (inactiveMarkerLength + segmentGap)))

        function lengthFor(segmentIndex: int): real {
            if (indicatorStyle !== 2 || activeSegmentIndex < 0 || segmentCount < 2) {
                return segmentLength;
            }
            return segmentIndex === activeSegmentIndex
                ? emphasizedSegmentLength
                : inactiveMarkerLength;
        }

        function offsetFor(segmentIndex: int): real {
            let offset = 0;
            for (let segment = 0; segment < segmentIndex; ++segment) {
                offset += lengthFor(segment) + segmentGap;
            }
            return offset;
        }

        visible: indicatorStyle !== 0 && !task.inPopup && !task.model.IsStartup
            && ((!task.model.IsLauncher) || task.colorHover)
        opacity: 1
        clip: true

        width: verticalIndicator
            ? indicatorThickness
            : Math.max(0, task.width - (2 * edgeInset))
        height: verticalIndicator
            ? Math.max(0, task.height - (2 * edgeInset))
            : indicatorThickness
        x: Plasmoid.location === PlasmaCore.Types.LeftEdge
            ? 0
            : Plasmoid.location === PlasmaCore.Types.RightEdge
                ? task.width - width
                : edgeInset
        y: Plasmoid.location === PlasmaCore.Types.TopEdge
            ? 0
            : Plasmoid.location === PlasmaCore.Types.BottomEdge
                ? task.height - height
                : edgeInset

        Repeater {
            model: runningIndicator.segmentCount

            delegate: Rectangle {
                required property int index
                property bool initialized: false

                color: runningIndicator.showsMediaProgress
                    ? task.mediaProgressColor
                    : task.taskAccentColor
                opacity: {
                    if (runningIndicator.showsMediaProgress) {
                        return 0.28;
                    }

                    const taskOpacity = (task.model.IsActive || task.colorHover)
                        ? 1
                        : Plasmoid.configuration.inactiveMarkerOpacity / 100;
                    if (!task.model.IsGroupParent || runningIndicator.activeSegmentIndex < 0) {
                        return taskOpacity;
                    }
                    const segmentOpacity = index === runningIndicator.activeSegmentIndex
                        ? 1
                        : Plasmoid.configuration.inactiveMarkerOpacity / 100;
                    return taskOpacity * segmentOpacity;
                }
                radius: runningIndicator.indicatorStyle === 2
                    && runningIndicator.activeSegmentIndex >= 0
                    && index !== runningIndicator.activeSegmentIndex
                    ? Math.min(1, runningIndicator.indicatorThickness / 4)
                    : runningIndicator.indicatorThickness / 2
                width: runningIndicator.verticalIndicator
                    ? runningIndicator.width
                    : runningIndicator.lengthFor(index)
                height: runningIndicator.verticalIndicator
                    ? runningIndicator.lengthFor(index)
                    : runningIndicator.height
                x: runningIndicator.verticalIndicator
                    ? 0
                    : runningIndicator.offsetFor(index)
                y: runningIndicator.verticalIndicator
                    ? runningIndicator.offsetFor(index)
                    : 0
                scale: !Plasmoid.configuration.animateRunningIndicators || initialized ? 1 : 0
                transformOrigin: Item.Center

                Component.onCompleted: initialized = true

                Behavior on x {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on radius {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    enabled: Plasmoid.configuration.animateRunningIndicators
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack }
                }
            }
        }

        Rectangle {
            visible: runningIndicator.showsMediaProgress
            color: task.mediaProgressColor
            opacity: task.mediaProgressPlaying ? 1 : 0.6
            radius: runningIndicator.indicatorThickness / 2

            width: runningIndicator.verticalIndicator
                ? runningIndicator.width
                : runningIndicator.width * task.mediaProgress
            height: runningIndicator.verticalIndicator
                ? runningIndicator.height * task.mediaProgress
                : runningIndicator.height
            x: 0
            y: runningIndicator.verticalIndicator
                ? runningIndicator.height - height
                : 0

            Behavior on width {
                enabled: task.mediaProgressPlaying
                NumberAnimation { duration: 200; easing.type: Easing.Linear }
            }
            Behavior on height {
                enabled: task.mediaProgressPlaying
                NumberAnimation { duration: 200; easing.type: Easing.Linear }
            }
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }

    GroupExpanderOverlay {
        visible: Plasmoid.configuration.runningIndicatorStyle === 0
            && task.model.IsGroupParent
    }

    states: [
        State {
            name: "launcher"
            when: task.model.IsLauncher

            PropertyChanges {
                frame.basePrefix: ""
            }
        },
        State {
            name: "attention"
            when: task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                frame.basePrefix: "attention"
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized

            PropertyChanges {
                frame.basePrefix: "minimized"
            }
        },
        State {
            name: "active"
            when: task.model.IsActive

            PropertyChanges {
                frame.basePrefix: "focus"
            }
        }
    ]

    Component.onCompleted: {
        refreshMediaPlayer();

        if (!inPopup && model.IsWindow) {
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
