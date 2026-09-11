cmake_minimum_required(VERSION 3.16)

project(dynamic-icon-tasks VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.26 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)
include(FeatureSummary)

find_package(Qt6 6.10 CONFIG REQUIRED COMPONENTS Core DBus Gui Qml Quick)
find_package(KF6 6.26 REQUIRED COMPONENTS
    Config
    CoreAddons
    I18n
    KIO
    Notifications
    Service
    WindowSystem
)
find_package(Plasma 6.7 REQUIRED)
find_package(PlasmaActivities 6.7 REQUIRED)
find_package(PlasmaActivitiesStats 6.7 REQUIRED)
find_package(LibNotificationManager 6.7 CONFIG REQUIRED)
find_package(KSysGuard CONFIG REQUIRED)

add_definitions(-DTRANSLATION_DOMAIN="plasma_applet_org.janzon.plasma.dynamicicontasks")

plasma_add_applet(org.janzon.plasma.dynamicicontasks
    QML_SOURCES
        qml/AudioStream.qml
        qml/ConfigAppearance.qml
        qml/ConfigBehavior.qml
        qml/ConfigMedia.qml
        qml/config.qml
        qml/ContextMenu.qml
        qml/GroupDialog.qml
        qml/GroupExpanderOverlay.qml
        qml/main.qml
        qml/MouseHandler.qml
        qml/PipeWireThumbnail.qml
        qml/PlayerController.qml
        qml/PulseAudio.qml
        qml/ScrollableTextWrapper.qml
        qml/TaskBadgeOverlay.qml
        qml/TaskList.qml
        qml/TaskProgressOverlay.qml
        qml/Task.qml
        qml/ToolTipDelegate.qml
        qml/ToolTipInstance.qml
        qml/ToolTipWindowMouseArea.qml
        qml/code/LayoutMetrics.js
        qml/code/TaskTools.js
    CPP_SOURCES
        backend.cpp
        smartlauncherbackend.cpp
        smartlauncheritem.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

kconfig_add_kcfg_files(org.janzon.plasma.dynamicicontasks
    kcfg/kactivitymanagerd_plugins_settings.kcfgc
)

ecm_qt_declare_logging_category(org.janzon.plasma.dynamicicontasks
    HEADER log_settings.h
    IDENTIFIER TASKMANAGER_DEBUG
    CATEGORY_NAME org.janzon.plasma.dynamicicontasks
)

target_link_libraries(org.janzon.plasma.dynamicicontasks PRIVATE
    Qt::Core
    Qt::DBus
    Qt::Gui
    Qt::Qml
    Qt::Quick
    Plasma::Activities
    Plasma::ActivitiesStats
    KF6::ConfigGui
    KF6::I18n
    KF6::KIOCore
    KF6::KIOGui
    KF6::KIOFileWidgets
    KF6::Notifications
    Plasma::Plasma
    KSysGuard::ProcessCore
    KF6::Service
    KF6::WindowSystem
    PW::LibNotificationManager
)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
