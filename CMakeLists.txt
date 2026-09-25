# SPDX-FileCopyrightText: 2025 slickytail
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Standalone Plasma 6 pager applet for the Karousel scrolling tiling KWin script.

cmake_minimum_required(VERSION 3.16)

project(karouselpager VERSION 0.1.0)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")
set(PLASMA_VERSION "6.0.0")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    DBus
    Qml
    Quick
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Config
    CoreAddons
    WindowSystem
)

find_package(Plasma ${PLASMA_VERSION} REQUIRED)
find_package(PlasmaActivities ${PLASMA_VERSION} REQUIRED)
find_package(LibTaskManager ${PLASMA_VERSION} REQUIRED)

add_definitions(-DTRANSLATION_DOMAIN=\"plasma_applet_org.slickytail.karouselpager\")

plasma_add_applet(org.slickytail.karouselpager
    QML_SOURCES
        qml/main.qml
        qml/config.qml
        qml/configGeneral.qml
    CPP_SOURCES
        pagermodel.cpp
        windowmodel.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

target_link_libraries(org.slickytail.karouselpager PRIVATE
    KF6::WindowSystem
    Plasma::Activities
    PW::LibTaskManager
    Qt6::Core
    Qt6::DBus
    Qt6::Qml
    Qt6::Quick
)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
