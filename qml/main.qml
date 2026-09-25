/*
    SPDX-FileCopyrightText: 2012 Luís Gabriel Lima <lampih@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents3
import org.kde.draganddrop as DnD
import plasma.applet.org.slickytail.karouselpager
import org.kde.plasma.activityswitcher as ActivitySwitcher
import org.kde.kirigami as Kirigami

import org.kde.kcmutils as KCM
import org.kde.config as KConfig

PlasmoidItem {
    id: root

    readonly property bool isActivityPager: Plasmoid.pluginName === "org.kde.plasma.activitypager"
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property real overflowMargin: Math.max(0, Plasmoid.configuration.overflowMargin ?? 1.5)
    readonly property real cellWidthFactor: 1 + 2 * overflowMargin
    readonly property real fadeStart: Math.max(0, Math.min(1, Plasmoid.configuration.fadeStart ?? 0.25))
    readonly property real fadeExponent: Math.max(0.05, Plasmoid.configuration.fadeExponent ?? 1.0)

    readonly property real aspectRatio: (((pagerModel.pagerItemSize.width * cellWidthFactor * pagerItemGrid.effectiveColumns)
        + ((pagerItemGrid.effectiveColumns * pagerItemGrid.spacing) - pagerItemGrid.spacing))
        / ((pagerModel.pagerItemSize.height * pagerItemGrid.effectiveRows)
        + ((pagerItemGrid.effectiveRows * pagerItemGrid.spacing) - pagerItemGrid.spacing)))

    Layout.minimumWidth: !root.vertical ? Math.floor(height * aspectRatio) : 1
    Layout.minimumHeight: root.vertical ? Math.floor(width / aspectRatio) : 1

    Layout.maximumWidth: !root.vertical ? Math.floor(height * aspectRatio) : Infinity
    Layout.maximumHeight: root.vertical ? Math.floor(width / aspectRatio) : Infinity

    Plasmoid.status: pagerModel.shouldShowPager ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    Layout.fillWidth: root.vertical
    Layout.fillHeight: !root.vertical

    property int dragSwitchDesktopIndex: -1
    property int wheelDelta: 0

    function colorWithAlpha(color: color, alpha: real): color {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    readonly property color windowActiveOnActiveDesktopColor: colorWithAlpha(Kirigami.Theme.textColor, 0.6)
    readonly property color windowInactiveOnActiveDesktopColor: colorWithAlpha(Kirigami.Theme.textColor, 0.35)
    readonly property color windowActiveColor: colorWithAlpha(Kirigami.Theme.textColor, 0.5)
    readonly property color windowActiveBorderColor: Kirigami.Theme.textColor
    readonly property color windowInactiveColor: colorWithAlpha(Kirigami.Theme.textColor, 0.17)
    readonly property color windowInactiveBorderColor: colorWithAlpha(Kirigami.Theme.textColor, 0.5)

    function sanitize(input: string): string {
        // Based on QQuickStyledTextPrivate::parseEntity
        const table = {
            '>': '&gt;',
            '<': '&lt;',
            '&': '&amp;',
            "'": '&apos;',
            '"': '&quot;',
            '\u00a0': '&nbsp;',
        };
        return input.replace(/[<>&'"\u00a0]/g, c => table[c]);
    }

    function generateWindowList(windows) {
        // if we have 5 windows, we would show "4 and another one" with the
        // hint that there's 1 more taking the same amount of space than just showing it
        const maximum = windows.length === 5 ? 5 : 4

        let text = "<ul><li>"
            + windows.slice(0, maximum).map(sanitize).join("</li><li>")
            + "</li></ul>";

        if (windows.length > maximum) {
            text += i18ncp("@info:tooltip overflow label", "…and %1 other window", "…and %1 other windows", windows.length - maximum)
        }

        return text
    }

    MouseArea {
        id: rootMouseArea
        anchors.fill: parent

        acceptedButtons: Qt.NoButton
        hoverEnabled: true

        onWheel: wheel => {
            // Magic number 120 for common "one click, see:
            // https://doc.qt.io/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
            root.wheelDelta += wheel.angleDelta.y || wheel.angleDelta.x;

            let increment = 0;

            while (root.wheelDelta >= 120) {
                root.wheelDelta -= 120;
                increment++;
            }

            while (root.wheelDelta <= -120) {
                root.wheelDelta += 120;
                increment--;
            }

            while (increment !== 0) {
                if (increment < 0) {
                    const nextPage = Plasmoid.configuration.wrapPage?
                        (pagerModel.currentPage + 1) % repeater.count :
                        Math.min(pagerModel.currentPage + 1, repeater.count - 1);
                    pagerModel.changePage(nextPage);
                } else {
                    const previousPage = Plasmoid.configuration.wrapPage ?
                        (repeater.count + pagerModel.currentPage - 1) % repeater.count :
                        Math.max(pagerModel.currentPage - 1, 0);
                    pagerModel.changePage(previousPage);
                }

                increment += (increment < 0) ? 1 : -1;
                root.wheelDelta = 0;
            }
        }
    }

    PagerModel {
        id: pagerModel

        enabled: root.visible

        showDesktop: (Plasmoid.configuration.currentDesktopSelected === 1)

        showOnlyCurrentScreen: Plasmoid.configuration.showOnlyCurrentScreen
        screenName: root.Screen.name
        screenGeometry: Plasmoid.containment.screenGeometry

        pagerType: root.isActivityPager ? PagerModel.Activities : PagerModel.VirtualDesktops
    }

    Connections {
        target: Plasmoid.configuration

        function onShowWindowIconsChanged() {
            // Causes the model to reset; Component.onCompleted in the
            // window delegate now gets a chance to create the icon item,
            // which it otherwise will not do.
            pagerModel.refresh();
        }

        function onDisplayedTextChanged() {
            // Causes the model to reset; Component.onCompleted in the
            // desktop delegate now gets a chance to create the label item,
            // which it otherwise will not do.
            pagerModel.refresh();
        }
    }

    Component {
        id: desktopLabelComponent

        PlasmaComponents3.Label {
            required property int index
            required property string display
            required property KSvg.FrameSvgItem desktopFrame

            anchors {
                fill: desktopFrame
                topMargin: desktopFrame.margins.top
                leftMargin: desktopFrame.margins.left
                rightMargin: desktopFrame.margins.right
                bottomMargin: desktopFrame.margins.bottom
            }

            text: Plasmoid.configuration.displayedText ? display : index + 1
            textFormat: Text.PlainText

            wrapMode: Text.NoWrap
            elide: Text.ElideRight

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            font.pixelSize: Math.min(height, Kirigami.Theme.defaultFont.pixelSize)

            z: 9999 // The label goes above everything
        }
    }

    Component {
        id: windowIconComponent

        Kirigami.Icon {
            anchors.centerIn: parent

            height: Math.min(Kirigami.Units.iconSizes.small,
                             parent.height,
                             Math.max(parent.height - (Kirigami.Units.smallSpacing * 2),
                                      Kirigami.Units.smallSpacing * 2))
            width: Math.min(Kirigami.Units.iconSizes.small,
                            parent.width,
                            Math.max(parent.width - (Kirigami.Units.smallSpacing * 2),
                                     Kirigami.Units.smallSpacing * 2))

            required property var decoration//: null

            source: decoration ?? undefined
            roundToIconSize: false
            animated: false
        }
    }

    Timer {
        id: dragTimer
        interval: 1000
        onTriggered: {
            if (root.dragSwitchDesktopIndex !== -1 && root.dragSwitchDesktopIndex !== pagerModel.currentPage) {
                pagerModel.changePage(root.dragSwitchDesktopIndex);
            }
        }
    }
    onDragSwitchDesktopIndexChanged: if (root.dragSwitchDesktopIndex === -1) {
        dragTimer.stop();
    } else {
        dragTimer.restart();
    }

    Grid {
        id: pagerItemGrid

        anchors.centerIn: parent
        spacing: 1
        rows: effectiveRows * effectiveColumns >= pagerModel.count ? effectiveRows : pagerModel.count
        columns: effectiveRows * effectiveColumns >= pagerModel.count ? effectiveColumns : pagerModel.count

        z: 1

        readonly property int effectiveRows: {
            if (!pagerModel.count) {
                return 1;
            }

            let rows = 1;

            if (root.isActivityPager && Plasmoid.configuration.pagerLayout !== 0 /*No Default*/) {
                if (Plasmoid.configuration.pagerLayout === 1 /*Horizontal*/) {
                    rows = 1;
                } else if (Plasmoid.configuration.pagerLayout === 2 /*Vertical*/) {
                    rows = pagerModel.count;
                }
            } else {
                let columns = Math.floor(pagerModel.count / pagerModel.layoutRows);

                if (pagerModel.count % pagerModel.layoutRows > 0) {
                    columns += 1;
                }

                rows = Math.floor(pagerModel.count / columns);

                if (pagerModel.count % columns > 0) {
                    rows += 1;
                }
            }

            return rows;
        }

        readonly property int effectiveColumns: {
            if (!pagerModel.count) {
                return 1;
            }

            return Math.ceil(pagerModel.count / effectiveRows);
        }

        readonly property real pagerItemSizeRatio: (pagerModel.pagerItemSize.width * root.cellWidthFactor) / pagerModel.pagerItemSize.height
        readonly property real widthScaleFactor: (columnWidth / root.cellWidthFactor) / pagerModel.pagerItemSize.width
        readonly property real heightScaleFactor: rowHeight / pagerModel.pagerItemSize.height

        states: [
            State {
                name: "vertical"
                when: root.vertical
                PropertyChanges {
                    pagerItemGrid.innerSpacing: pagerItemGrid.effectiveColumns
                    pagerItemGrid.rowHeight: Math.floor(pagerItemGrid.columnWidth / pagerItemGrid.pagerItemSizeRatio)
                    pagerItemGrid.columnWidth: Math.floor((root.width - pagerItemGrid.innerSpacing) / pagerItemGrid.effectiveColumns)
                }
            }
        ]

        property int innerSpacing: (effectiveRows - 1) * spacing
        property int rowHeight: Math.floor((root.height - innerSpacing) / effectiveRows)
        property int columnWidth: Math.floor(rowHeight * pagerItemSizeRatio)

        Repeater {
            id: repeater

            model: pagerModel

            component DesktopDelegate: PlasmaCore.ToolTipArea {
                required property string display
                required property int index
                required property var model

                readonly property /*WindowModel*/ var tasksModel: model.TasksModel
                readonly property string desktopId: (root.isActivityPager ? tasksModel?.activity : tasksModel?.virtualDesktop) ?? ""
                readonly property bool isCurrent: (index === pagerModel.currentPage)
            }

            delegate: DesktopDelegate {
                id: desktop

                mainText: display
                // our ToolTip has maximumLineCount of 8 which doesn't fit but QML doesn't
                // respect that in RichText so we effectively can put in as much as we like :)
                // it also gives us more flexibility when it comes to styling the <li>
                textFormat: Text.RichText

                function updateSubTextIfNeeded() {
                    if (!containsMouse) {
                        return;
                    }

                    let text = ""
                    let visibleWindows = []
                    let minimizedWindows = []

                    for (let i = 0, length = windowRectRepeater.count; i < length; ++i) {
                        const window = windowRectRepeater.itemAt(i) as WindowDelegate
                        if (window) {
                            if (window.minimized) {
                                minimizedWindows.push(window.display)
                            } else {
                                visibleWindows.push(window.display)
                            }
                        }
                    }

                    if (visibleWindows.length === 1) {
                        text += visibleWindows[0]
                    } else if (visibleWindows.length > 1) {
                        text += i18ncp("@info:tooltip start of list", "%1 Window:", "%1 Windows:", visibleWindows.length)
                            + root.generateWindowList(visibleWindows)
                    }

                    if (visibleWindows.length && minimizedWindows.length) {
                        if (visibleWindows.length === 1) {
                            text += "<br>"
                        }
                        text += "<br>"
                    }

                    if (minimizedWindows.length > 0) {
                        text += i18ncp("@info:tooltip", "%1 Minimized Window:", "%1 Minimized Windows:", minimizedWindows.length)
                            + root.generateWindowList(minimizedWindows)
                    }

                    if (text.length) {
                        // Get rid of the spacing <ul> would cause
                        text = "<style>ul { margin: 0; }</style>" + text
                    }

                    subText = text
                }

                width: pagerItemGrid.columnWidth
                height: pagerItemGrid.rowHeight

                // The viewport is the centered part of the cell that represents
                // the screen. The remaining width on either side is reserved for
                // windows that Karousel has scrolled out of view.
                readonly property real viewportWidth: width / root.cellWidthFactor
                readonly property real marginWidth: (width - viewportWidth) / 2

                // Vertical inset of the tiling area (panel plus Karousel margin),
                // in pager pixels. The viewport frame is extended below the
                // windows by the same amount so that it stays symmetric.
                readonly property real tilingTop: {
                    let minTop = Infinity;
                    const count = windowRectRepeater ? windowRectRepeater.count : 0;
                    for (let i = 0; i < count; ++i) {
                        const w = windowRectRepeater.itemAt(i);
                        if (w) {
                            minTop = Math.min(minTop, w.windowTop);
                        }
                    }
                    return isFinite(minTop) ? minTop : 0;
                }

                readonly property real tilingBottom: {
                    let maxBottom = -Infinity;
                    const count = windowRectRepeater ? windowRectRepeater.count : 0;
                    for (let i = 0; i < count; ++i) {
                        const w = windowRectRepeater.itemAt(i);
                        if (w) {
                            maxBottom = Math.max(maxBottom, w.windowBottom);
                        }
                    }
                    return isFinite(maxBottom) ? maxBottom : height;
                }

                // Opacity of an off-viewport outline at distance d from the
                // viewport (d == 0 at the viewport, d == 1 at the outer edge of
                // the reserved area).
                function fadeAlpha(d) {
                    if (d <= root.fadeStart) {
                        return 1.0;
                    }
                    const t = (d - root.fadeStart) / Math.max(0.0001, 1.0 - root.fadeStart);
                    return Math.pow(Math.max(0.0, 1.0 - t), root.fadeExponent);
                }

                // These states match the set of SVG prefixes for the "widgets/pager" below.
                state: {
                    if (desktopMouseArea.enabled && (desktopMouseArea.containsMouse || desktopMouseArea.activeFocus)) {
                        return "hover";
                    } else if (isCurrent) {
                        return "active";
                    } else {
                        return "normal";
                    }
                }

                component PagerFrame : KSvg.FrameSvgItem {
                    x: desktop.marginWidth
                    y: 0
                    width: desktop.viewportWidth
                    // Extend below the windows by the same amount the tiling area
                    // is inset at the top, so the frame looks symmetric.
                    height: desktop.tilingBottom + desktop.tilingTop
                    imagePath: "widgets/pager"
                    opacity: desktop.state === usedPrefix ? 1 : 0
                }

                PagerFrame {
                    id: desktopFrame
                    z: 2 // Above window outlines, but below label
                    prefix: "hover"
                }
                PagerFrame {
                    z: 3
                    prefix: "active"
                }
                PagerFrame {
                    z: 4
                    prefix: "normal"
                }

                DnD.DropArea {
                    id: droparea
                    anchors.fill: parent
                    preventStealing: true

                    onDragEnter: event => {
                        root.dragSwitchDesktopIndex = desktop.index;
                    }
                    onDragLeave: event => {
                        // new onDragEnter may happen before an old onDragLeave
                        if (root.dragSwitchDesktopIndex === desktop.index) {
                            root.dragSwitchDesktopIndex = -1;
                        }
                    }
                    onDrop: event => {
                        pagerModel.drop(event.mimeData, event.modifiers, desktop.desktopId);
                        root.dragSwitchDesktopIndex = -1;
                    }
                }

                MouseArea {
                    id: desktopMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    activeFocusOnTab: true
                    onClicked: mouse => {
                        pagerModel.changePage(desktop.index);
                    }
                    Accessible.name: Plasmoid.configuration.displayedText ? desktop.display : i18nc("@info:whatsthis Accessible name for pager section", "Desktop %1", (desktop.index + 1))
                    Accessible.description: Plasmoid.configuration.displayedText ? i18nc("@info:tooltip %1 is the name of a virtual desktop or an activity", "Switch to %1", desktop.display) : i18nc("@info:tooltip %1 is the name of a virtual desktop or an activity", "Switch to %1", (desktop.index + 1))
                    Accessible.role: Accessible.Button
                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Space:
                        case Qt.Key_Enter:
                        case Qt.Key_Return:
                        case Qt.Key_Select:
                            pagerModel.changePage(desktop.index);
                            break;
                        }
                    }
                }

                // Outlines of windows that Karousel has scrolled outside the
                // viewport. They are drawn in the reserved area on either side
                // of the viewport and fade out towards the outer edges.
                component WindowDelegate: Rectangle {
                    id: windowRect

                    required property string display
                    required property var model
                    required property var decoration
                    required property int index

                    // Draw a lighter, unfilled outline instead of a filled window.
                    property bool ghost: false

                    // These can't be required due to their role names
                    readonly property rect geometry: model.Geometry
                    readonly property bool minimized: model.IsMinimized
                    readonly property bool isActive: model.IsActive
                    readonly property int stackingOrder: model.StackingOrder

                    readonly property real windowLeft: Math.round(geometry.x * pagerItemGrid.widthScaleFactor)
                    readonly property real windowTop: Math.round(geometry.y * pagerItemGrid.heightScaleFactor)
                    readonly property real windowRight: Math.round((geometry.x + geometry.width) * pagerItemGrid.widthScaleFactor)
                    readonly property real windowBottom: Math.round((geometry.y + geometry.height) * pagerItemGrid.heightScaleFactor)
                    // Derive the size from the rounded edges so that adjacent
                    // windows share an edge exactly and stacked windows do not
                    // accumulate rounding error.
                    readonly property real windowWidth: windowRight - windowLeft
                    readonly property real windowHeight: windowBottom - windowTop
                    readonly property color solidBorderColor: isActive ? root.windowActiveBorderColor : root.windowInactiveBorderColor
                    // On the current desktop the whole outline is drawn in the accent
                    // color; off-viewport parts are a more transparent version of it.
                    readonly property color ghostBorderColor: desktop.isCurrent
                        ? root.colorWithAlpha(Kirigami.Theme.focusColor, isActive ? 0.6 : 0.45)
                        : Qt.rgba(solidBorderColor.r, solidBorderColor.g, solidBorderColor.b, solidBorderColor.a * (isActive ? 0.5 : 0.4))

                    onMinimizedChanged: desktop.updateSubTextIfNeeded()
                    onDisplayChanged: desktop.updateSubTextIfNeeded()

                    z: 1 + stackingOrder
                    // clipRect is inset by one pixel, so move the solid windows back.
                    x: ghost ? desktop.marginWidth + windowLeft : windowLeft - 1
                    y: ghost ? windowTop : windowTop - 1
                    width: windowWidth
                    height: windowHeight
                    visible: Plasmoid.configuration.showWindowOutlines && !minimized
                    color: ghost ? "transparent" : (desktop.isCurrent
                        ? (isActive ? root.windowActiveOnActiveDesktopColor : root.windowInactiveOnActiveDesktopColor)
                        : (isActive ? root.windowActiveColor : root.windowInactiveColor))

                    border.width: 1
                    border.color: ghost ? ghostBorderColor : solidBorderColor

                    Component.onCompleted: {
                        if (!ghost && Plasmoid.configuration.showWindowIcons) {
                            windowIconComponent.createObject(windowRect, { decoration: windowRect.decoration });
                        }
                    }
                }

                Item {
                    id: ghostLayer

                    anchors.fill: parent
                    z: 0

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: ghostMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Repeater {
                        model: desktop.tasksModel

                        delegate: WindowDelegate {
                            ghost: true
                        }
                    }
                }

                // Keeps the ghost outlines out of the viewport and fades them
                // away near the outer edge of the reserved area.
                Item {
                    id: ghostMask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Canvas {
                        id: maskCanvas

                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();

                            const m = desktop.marginWidth;
                            const v = desktop.viewportWidth;
                            const w = width;
                            const h = height;
                            if (m <= 0 || h <= 0) {
                                return;
                            }

                            const steps = 24;

                            // Left margin: distance from the viewport grows from
                            // t == 1 (viewport edge) to t == 0 (outer edge).
                            const left = ctx.createLinearGradient(0, 0, m, 0);
                            for (let i = 0; i <= steps; ++i) {
                                const t = i / steps;
                                left.addColorStop(t, "rgba(255,255,255," + desktop.fadeAlpha(1 - t) + ")");
                            }
                            ctx.fillStyle = left;
                            ctx.fillRect(0, 0, m, h);

                            // Right margin: distance from the viewport grows from
                            // t == 0 (viewport edge) to t == 1 (outer edge).
                            const rightX = m + v;
                            const right = ctx.createLinearGradient(rightX, 0, w, 0);
                            for (let i = 0; i <= steps; ++i) {
                                const t = i / steps;
                                right.addColorStop(t, "rgba(255,255,255," + desktop.fadeAlpha(t) + ")");
                            }
                            ctx.fillStyle = right;
                            ctx.fillRect(rightX, 0, w - rightX, h);
                        }
                    }

                    Connections {
                        target: root

                        function onFadeStartChanged() {
                            maskCanvas.requestPaint();
                        }
                        function onFadeExponentChanged() {
                            maskCanvas.requestPaint();
                        }
                        function onOverflowMarginChanged() {
                            maskCanvas.requestPaint();
                        }
                    }
                }

                Item {
                    id: clipRect

                    x: desktop.marginWidth + 1
                    y: 1
                    z: 1 // Below FrameSvg
                    width: desktop.viewportWidth - 2
                    // Leave the bottom edge open so a window's bottom border is
                    // not clipped when it reaches the bottom of the cell.
                    height: desktop.height - 1
                    clip: true

                    Repeater {
                        id: windowRectRepeater

                        model: desktop.tasksModel

                        onCountChanged: desktop.updateSubTextIfNeeded()

                        delegate: WindowDelegate {
                            ghost: false
                        }
                    }
                }

                Component.onCompleted: {
                    if (Plasmoid.configuration.displayedText < 2) {
                        desktopLabelComponent.createObject(desktop, { index, display: desktop.display, desktopFrame });
                    }
                }

                onContainsMouseChanged: updateSubTextIfNeeded()
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Show Activity Manager")
            icon.name: "activities"
            visible: root.isActivityPager
            onTriggered: ActivitySwitcher.Backend.toggleActivityManager()
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Add Virtual Desktop")
            icon.name: "list-add"
            visible: !root.isActivityPager && KConfig.KAuthorized.authorize("kcm_kwin_virtualdesktops")
            onTriggered: pagerModel.addDesktop()
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Remove Virtual Desktop")
            icon.name: "list-remove"
            visible: !root.isActivityPager && KConfig.KAuthorized.authorize("kcm_kwin_virtualdesktops")
            enabled: repeater.count > 1
            onTriggered: pagerModel.removeDesktop()
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "&Configure Activities…")
            visible: root.isActivityPager && KConfig.KAuthorized.authorize("kcm_activities")
            onTriggered: KCM.KCMLauncher.openSystemSettings("kcm_activities")
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Configure Virtual Desktops…")
            visible: !root.isActivityPager && KConfig.KAuthorized.authorize("kcm_kwin_virtualdesktops")
            onTriggered: {
                if (Qt.platform.pluginName.includes("wayland"))
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops")
                else
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops_x11")
            }
        }
    ]
}
