cmake_minimum_required(VERSION 3.20)
project(CartoRigAtomicCore VERSION 0.1.0 LANGUAGES CXX)

# Native portable domain library. No Resolve SDK, GUI, OpenFX or network access.
add_library(cartorig_core STATIC
    src/core/cartorig_core.cpp
    src/render/cartorig_renderer.cpp
    src/host/inspector_session.cpp
)
target_include_directories(cartorig_core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/core>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/render>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/host>
)
target_compile_features(cartorig_core PUBLIC cxx_std_17)
set_target_properties(cartorig_core PROPERTIES POSITION_INDEPENDENT_CODE ON)

if(MSVC)
    target_compile_options(cartorig_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(cartorig_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(cartorig_core_tests tests/core_tests.cpp)
target_link_libraries(cartorig_core_tests PRIVATE cartorig_core)

add_executable(cartorig_renderer_tests tests/renderer_tests.cpp)
target_link_libraries(cartorig_renderer_tests PRIVATE cartorig_core)

add_executable(cartorig_inspector_session_tests tests/inspector_session_tests.cpp)
target_link_libraries(cartorig_inspector_session_tests PRIVATE cartorig_core)

add_executable(cartorig_real_scenario_probe tools/real_scenario_probe.cpp)
target_link_libraries(cartorig_real_scenario_probe PRIVATE cartorig_core)

add_executable(cartorig_catalog_probe tools/catalog_probe.cpp)
target_link_libraries(cartorig_catalog_probe PRIVATE cartorig_core)

enable_testing()
add_test(NAME cartorig-core-unit COMMAND cartorig_core_tests)
add_test(NAME cartorig-renderer-unit COMMAND cartorig_renderer_tests)
add_test(NAME cartorig-inspector-session COMMAND cartorig_inspector_session_tests)

# Optional real OpenFX adapter. The SDK is checked out by CI at a pinned
# AcademySoftwareFoundation/openfx commit; it is never shipped as a runtime.
option(CARTORIG_BUILD_OFX "Build native OpenFX host adapter" OFF)
if(CARTORIG_BUILD_OFX)
    find_path(OPENFX_INCLUDE_DIR NAMES ofxImageEffect.h
        HINTS "${CMAKE_CURRENT_SOURCE_DIR}/external/openfx/include"
        REQUIRED)
    add_library(CartoRigAtomic SHARED src/ofx/cartorig_ofx.cpp)
    target_include_directories(CartoRigAtomic PRIVATE "${OPENFX_INCLUDE_DIR}")
    target_link_libraries(CartoRigAtomic PRIVATE cartorig_core)
    target_compile_features(CartoRigAtomic PRIVATE cxx_std_17)
    set_target_properties(CartoRigAtomic PROPERTIES
        PREFIX "" OUTPUT_NAME "CartoRigAtomic" SUFFIX ".ofx")
    if(UNIX AND NOT APPLE)
        target_link_libraries(CartoRigAtomic PRIVATE dl)
    endif()
    if(MSVC)
        target_compile_options(CartoRigAtomic PRIVATE /W4 /permissive-)
    else()
        target_compile_options(CartoRigAtomic PRIVATE -Wall -Wextra -Wpedantic)
    endif()

    add_executable(cartorig_ofx_contract_tests tests/ofx_contract_tests.cpp)
    target_include_directories(cartorig_ofx_contract_tests PRIVATE "${OPENFX_INCLUDE_DIR}")
    target_compile_features(cartorig_ofx_contract_tests PRIVATE cxx_std_17)
    if(UNIX AND NOT APPLE)
        target_link_libraries(cartorig_ofx_contract_tests PRIVATE dl)
    endif()
    add_test(NAME cartorig-openfx-binary-contract
        COMMAND $<TARGET_FILE:cartorig_ofx_contract_tests> $<TARGET_FILE:CartoRigAtomic>)
    set_tests_properties(cartorig-openfx-binary-contract PROPERTIES
        ENVIRONMENT "CARTORIG_ATOMIC_DATA_DIR=${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures")
endif()
