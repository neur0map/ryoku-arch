set(RYOKU_SERVICES_LIBRARIES
    PkgConfig::Pipewire
    PkgConfig::Aubio
    PkgConfig::Cava
)

qml_module(ryoku-services
    URI Ryoku.Services
    SOURCES
        service.hpp service.cpp
        serviceref.hpp serviceref.cpp
        beattracker.hpp beattracker.cpp
        audiocollector.hpp audiocollector.cpp
        audioprovider.hpp audioprovider.cpp
        cavaprovider.hpp cavaprovider.cpp
    LIBRARIES
        ${RYOKU_SERVICES_LIBRARIES}
)

target_compile_definitions(ryoku-services PRIVATE RYOKU_HAS_CAVA=1)
