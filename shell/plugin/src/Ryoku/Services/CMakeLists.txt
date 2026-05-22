set(RYOKU_SERVICES_LIBRARIES
    PkgConfig::Pipewire
    PkgConfig::Aubio
)

if(Cava_FOUND)
    list(APPEND RYOKU_SERVICES_LIBRARIES PkgConfig::Cava)
endif()

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

if(Cava_FOUND)
    target_compile_definitions(ryoku-services PRIVATE RYOKU_HAS_CAVA=1)
endif()
