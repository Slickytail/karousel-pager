    /*
 *  SPDX-FileCopyrightText: 2013 David Edmundson <davidedmundson@kde.org>
 *  SPDX-FileCopyrightText: 2016 Eike Hein <hein@kde.org>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root
    readonly property bool isActivityPager: Plasmoid.pluginName === "org.kde.plasma.activitypager"

    property int cfg_displayedText
    property alias cfg_showWindowOutlines: showWindowOutlines.checked
    property alias cfg_showWindowIcons: showWindowIcons.checked
    property alias cfg_overflowMargin: overflowMargin.value
    property alias cfg_fadeStart: fadeStart.value
    property alias cfg_fadeExponent: fadeExponent.value
    property int cfg_currentDesktopSelected
    property alias cfg_pagerLayout: pagerLayout.currentIndex
    property alias cfg_showOnlyCurrentScreen: showOnlyCurrentScreen.checked
    property alias cfg_wrapPage: wrapPage.checked

    Kirigami.FormLayout {
        QQC2.ButtonGroup {
            id: displayedTextGroup
        }

        QQC2.ButtonGroup {
            id: currentDesktopSelectedGroup
        }

        QQC2.CheckBox {
            id: showWindowOutlines

            Kirigami.FormData.label: i18nc("@title:group prefix for checkbox group", "General:")

            text: i18nc("@option:check", "Show window outlines")
        }

        QQC2.CheckBox {
            id: showWindowIcons
            text: i18nc("@option:check", "Show application icons on window outlines")
            enabled: showWindowOutlines.checked
        }

        RowLayout {
            id: overflowMarginRow

            Kirigami.FormData.label: i18nc("@label:slider", "Reserved space per side:")
            enabled: showWindowOutlines.checked

            QQC2.Slider {
                id: overflowMargin
                from: 0.0
                to: 4.0
                stepSize: 0.1
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            }

            QQC2.Label {
                text: i18n("%1 desktop widths", overflowMargin.value.toFixed(2))
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            }
        }

        RowLayout {
            id: fadeStartRow

            Kirigami.FormData.label: i18nc("@label:slider", "Start fading after:")
            enabled: showWindowOutlines.checked

            QQC2.Slider {
                id: fadeStart
                from: 0.0
                to: 1.0
                stepSize: 0.05
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            }

            QQC2.Label {
                text: i18n("%1% of the reserved width", Math.round(fadeStart.value * 100))
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            }
        }

        RowLayout {
            id: fadeExponentRow

            Kirigami.FormData.label: i18nc("@label:slider", "Fade curve:")
            enabled: showWindowOutlines.checked

            QQC2.Slider {
                id: fadeExponent
                from: 0.25
                to: 4.0
                stepSize: 0.25
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            }

            QQC2.Label {
                text: fadeExponent.value.toFixed(2)
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            }
        }

        QQC2.CheckBox {
            id: showOnlyCurrentScreen
            text: i18nc("@option:check", "Show only current screen")
        }

        QQC2.CheckBox {
            id: wrapPage
            text: i18nc("@option:check", "Navigation wraps around")
        }


        Item {
            Kirigami.FormData.isSection: true
        }


        QQC2.ComboBox {
            id: pagerLayout

            Kirigami.FormData.label: i18nc("@title:listbox", "Layout:")

            model: [i18nc("@item:inlistbox The pager layout", "Default"), i18nc("@item:inlistbox The pager layout", "Horizontal"), i18nc("@item:inlistbox The pager layout", "Vertical")]
            visible: root.isActivityPager
        }


        Item {
            Kirigami.FormData.isSection: true
            visible: root.isActivityPager
        }


        QQC2.RadioButton {
            id: noTextRadio

            Kirigami.FormData.label: i18nc("@title:group prefix for radiobutton group", "Text display:")

            QQC2.ButtonGroup.group: displayedTextGroup
            text: i18nc("@option:radio text display", "No text")
            checked: root.cfg_displayedText === 2
            onToggled: if (checked) root.cfg_displayedText = 2;
        }

        QQC2.RadioButton {
            id: desktopNumberRadio
            QQC2.ButtonGroup.group: displayedTextGroup
            text: isActivityPager ? i18nc("@option:radio text display", "Activity number") : i18nc("@option:radio text display", "Desktop number")
            checked: root.cfg_displayedText === 0
            onToggled: if (checked) root.cfg_displayedText = 0;
        }

        QQC2.RadioButton {
            id: desktopNameRadio
            QQC2.ButtonGroup.group: displayedTextGroup
            text: isActivityPager ? i18nc("@option:radio text display", "Activity name") : i18nc("@option:radio text display", "Desktop name")
            checked: root.cfg_displayedText === 1
            onToggled: if (checked) root.cfg_displayedText = 1;
        }


        Item {
            Kirigami.FormData.isSection: true
        }


        QQC2.RadioButton {
            id: doesNothingRadio

            Kirigami.FormData.label: root.isActivityPager
                ? i18nc("@label Start of the sentence 'Selecting current activity does nothing/shows the desktop'", "Selecting current Activity:")
                : i18nc("@label Start of the sentence 'Selecting current virtual desktop does nothing/shows the desktop'", "Selecting current virtual desktop:")

            QQC2.ButtonGroup.group: currentDesktopSelectedGroup
            text: i18nc("option:check completes the sentence 'Selecting current activity/virtual desktop does nothing'", "Does nothing")
            checked: root.cfg_currentDesktopSelected === 0
            onToggled: if (checked) root.cfg_currentDesktopSelected = 0;
        }

        QQC2.RadioButton {
            id: showsDesktopRadio
            QQC2.ButtonGroup.group: currentDesktopSelectedGroup
            text: i18nc("option:check completes the sentence 'Selecting current activity/virtual desktop shows the desktop'", "Shows the desktop")
            checked: root.cfg_currentDesktopSelected === 1
            onToggled: if (checked) root.cfg_currentDesktopSelected = 1;
        }
    }
}
