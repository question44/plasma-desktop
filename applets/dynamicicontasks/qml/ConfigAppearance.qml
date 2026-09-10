/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

KCMUtils.SimpleKCM {
    id: root

    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: true

    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property bool cfg_tooltipControls
    property alias cfg_fill: fill.checked
    property alias cfg_maxStripes: maxStripes.value
    property alias cfg_forceStripes: forceStripes.checked
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex
    property int cfg_iconSpacing: 0
    property alias cfg_dynamicActiveBackground: dynamicActiveBackground.checked
    property alias cfg_activeColorSource: activeColorSource.currentIndex
    property alias cfg_activeBackgroundOpacity: activeBackgroundOpacity.value
    property alias cfg_activeBackgroundRadius: activeBackgroundRadius.value
    property alias cfg_individualCornerRadii: individualCornerRadii.checked
    property alias cfg_activeBackgroundTopLeftRadius: activeBackgroundTopLeftRadius.value
    property alias cfg_activeBackgroundTopRightRadius: activeBackgroundTopRightRadius.value
    property alias cfg_activeBackgroundBottomLeftRadius: activeBackgroundBottomLeftRadius.value
    property alias cfg_activeBackgroundBottomRightRadius: activeBackgroundBottomRightRadius.value
    property alias cfg_fixedActiveBackgroundColor: fixedActiveBackgroundColor.color
    property alias cfg_runningIndicatorStyle: runningIndicatorStyle.currentIndex
    property alias cfg_runningIndicatorThickness: runningIndicatorThickness.value
    property alias cfg_inactiveMarkerMinimumLength: inactiveMarkerMinimumLength.value
    property alias cfg_inactiveMarkerOpacity: inactiveMarkerOpacity.value
    property alias cfg_animateRunningIndicators: animateRunningIndicators.checked

    Component.onCompleted: {
        /* Don't rely on bindings for checking the radiobuttons
           When checking forceStripes, the condition for the checked value for the allow stripes button
           became true and that one got checked instead, stealing the checked state for the just clicked checkbox
        */
        if (maxStripes.value === 1) {
            forbidStripes.checked = true;
        } else if (!Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            allowStripes.checked = true;
        } else if (Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            forceStripes.checked = true;
        }
    }
    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:")
            text: i18nc("@option:check section General", "Show small window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            text: showToolTips.checked ? i18nc("@option:check section General", "Hide other windows when hovering over previews") : i18nc("@option:check section General", "Hide other windows when hovering over tooltips")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check section General", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            leftPadding: mirrored ? 0 : (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing)
            rightPadding: mirrored ? (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing) : 0
            text: i18nc("@option:check section General", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: tooltipControls
            text: i18nc("@option:check section General", "Show media and volume controls in tooltip")
            checked: root.cfg_tooltipControls && root.plasmaPaAvailable
            onToggled: root.cfg_tooltipControls = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: fill
            text: i18nc("@option:check section General", "Fill free space on panel")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: dynamicActiveBackground
            Kirigami.FormData.label: i18nc("@label for task appearance options", "Active and hovered tasks:")
            text: i18nc("@option:check", "Use colors extracted from application icons")
        }

        QQC2.ComboBox {
            id: activeColorSource
            enabled: dynamicActiveBackground.checked
            Kirigami.FormData.label: i18nc("@label:listbox", "Icon color:")
            model: [
                i18nc("@item:inlistbox", "Accent"),
                i18nc("@item:inlistbox", "Dominant")
            ]
        }

        KQuickControls.ColorButton {
            id: fixedActiveBackgroundColor
            visible: !dynamicActiveBackground.checked
            Kirigami.FormData.label: i18nc("@label", "Fixed color:")
        }

        QQC2.SpinBox {
            id: activeBackgroundOpacity
            Kirigami.FormData.label: i18nc("@label:spinbox", "Background opacity:")
            from: 5
            to: 60
            textFromValue: value => i18nc("@item:valuesuffix percentage", "%1%", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: activeBackgroundRadius
            visible: !individualCornerRadii.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Corner radius:")
            from: 0
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.CheckBox {
            id: individualCornerRadii
            text: i18nc("@option:check", "Configure each corner separately")
        }

        QQC2.SpinBox {
            id: activeBackgroundTopLeftRadius
            visible: individualCornerRadii.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Top-left radius:")
            from: 0
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: activeBackgroundTopRightRadius
            visible: individualCornerRadii.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Top-right radius:")
            from: 0
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: activeBackgroundBottomLeftRadius
            visible: individualCornerRadii.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Bottom-left radius:")
            from: 0
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: activeBackgroundBottomRightRadius
            visible: individualCornerRadii.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Bottom-right radius:")
            from: 0
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: runningIndicatorStyle
            Kirigami.FormData.label: i18nc("@label:listbox", "Edge indicator style:")
            model: [
                i18nc("@item:inlistbox", "Plasma standard"),
                i18nc("@item:inlistbox", "Equal window segments"),
                i18nc("@item:inlistbox", "Emphasize active window")
            ]
        }

        QQC2.SpinBox {
            id: runningIndicatorThickness
            visible: runningIndicatorStyle.currentIndex !== 0
            Kirigami.FormData.label: i18nc("@label:spinbox", "Edge indicator thickness:")
            from: 1
            to: 8
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: inactiveMarkerMinimumLength
            visible: runningIndicatorStyle.currentIndex === 2
            Kirigami.FormData.label: i18nc("@label:spinbox", "Small marker minimum length:")
            from: 1
            to: 24
            textFromValue: value => i18nc("@item:valuesuffix pixels", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            id: inactiveMarkerOpacity
            visible: runningIndicatorStyle.currentIndex === 1
                || runningIndicatorStyle.currentIndex === 2
            Kirigami.FormData.label: i18nc("@label:spinbox", "Inactive indicator opacity:")
            from: 5
            to: 100
            textFromValue: value => i18nc("@item:valuesuffix percentage", "%1%", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.CheckBox {
            id: animateRunningIndicators
            visible: runningIndicatorStyle.currentIndex === 1
                || runningIndicatorStyle.currentIndex === 2
            text: i18nc("@option:check", "Animate indicator changes")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !root.iconOnly
        }

        QQC2.ComboBox {
            id: taskMaxWidth
            visible: !root.iconOnly && !root.plasmoidVertical

            Kirigami.FormData.label: i18nc("@label:listbox", "Maximum task width:")

            model: [
                i18nc("@item:inlistbox how wide a task item should be", "Narrow"),
                i18nc("@item:inlistbox how wide a task item should be", "Medium"),
                i18nc("@item:inlistbox how wide a task item should be", "Wide")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: forbidStripes
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-column view:")
                : i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-row view:")
            onToggled: {
                if (checked) {
                    maxStripes.value = 1
                }
            }
            text: i18nc("@option:radio Never use multi-column view for Task Manager", "Never")
        }

        QQC2.RadioButton {
            id: allowStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "When panel is low on space and thick enough")
        }

        QQC2.RadioButton {
            id: forceStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "Always when panel is thick enough")
        }

        QQC2.SpinBox {
            id: maxStripes
            enabled: maxStripes.value > 1
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label:spinbox maximum number of columns for tasks", "Maximum columns:")
                : i18nc("@label:spinbox maximum number of rows for tasks", "Maximum rows:")
            from: 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            visible: root.iconOnly
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing between icons:")

            model: [
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Small"),
                    "spacing": 0
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Normal"),
                    "spacing": 1
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Large"),
                    "spacing": 3
                },
            ]

            textRole: "label"

            currentIndex: switch (root.cfg_iconSpacing) {
                case 0: return 0; // Small
                case 1: return 1; // Normal
                case 3: return 2; // Large
            }
            onActivated: index => {
                root.cfg_iconSpacing = model[currentIndex]["spacing"];
            }
        }
    }
}
