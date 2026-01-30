cmake_minimum_required(VERSION 3.15)
project(AutoNestCutSolver VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags
if(MSVC)
    add_compile_options(/O2 /W4)
else()
    add_compile_options(-O3 -Wall -Wextra)
endif()

# Source files
set(SOURCES
    src/main.cpp
    src/nesting.cpp
    src/geometry.cpp
)

# Executable
add_executable(nester ${SOURCES})

# Include directories
target_include_directories(nester PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Output directory
set_target_properties(nester PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)
