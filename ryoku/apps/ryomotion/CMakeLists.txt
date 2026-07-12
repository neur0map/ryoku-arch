cmake_minimum_required(VERSION 3.21)
project(ryomotion VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(ryomotion
    src/main.cpp
    src/backend.cpp
)

set_source_files_properties(qml/Theme.qml qml/Project.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(ryomotion
    URI RyoMotion
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Project.qml
        qml/Stage.qml
        qml/Rail.qml
        qml/Inspector.qml
        qml/Timeline.qml
        qml/OpenSheet.qml
        qml/Icon.qml
        qml/Slider.qml
        qml/Toggle.qml
        qml/Segmented.qml
        qml/TopBtn.qml
        qml/Group.qml
    SOURCES
        src/backend.h
)

target_include_directories(ryomotion PRIVATE src)

target_link_libraries(ryomotion PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Multimedia
)

install(TARGETS ryomotion RUNTIME DESTINATION bin)
