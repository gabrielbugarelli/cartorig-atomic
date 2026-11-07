cmake_minimum_required(VERSION 3.20)
project(CartoRigAtomicCore VERSION 0.1.0 LANGUAGES CXX)

# Native portable domain library. No Resolve SDK, GUI, OpenFX or network access.
add_library(cartorig_core STATIC
    src/core/cartorig_core.cpp
)
target_include_directories(cartorig_core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/core>
)
target_compile_features(cartorig_core PUBLIC cxx_std_17)

if(MSVC)
    target_compile_options(cartorig_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(cartorig_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(cartorig_core_tests tests/core_tests.cpp)
target_link_libraries(cartorig_core_tests PRIVATE cartorig_core)

add_executable(cartorig_catalog_probe tools/catalog_probe.cpp)
target_link_libraries(cartorig_catalog_probe PRIVATE cartorig_core)

enable_testing()
add_test(NAME cartorig-core-unit COMMAND cartorig_core_tests)
