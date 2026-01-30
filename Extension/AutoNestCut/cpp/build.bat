@echo off
REM Build script for Windows

echo Building AutoNestCut C++ Solver...

REM Create build directory
if not exist build mkdir build
cd build

REM Run CMake
cmake .. -G "Visual Studio 17 2022" -A x64
if errorlevel 1 (
    echo CMake configuration failed!
    cd ..
    exit /b 1
)

REM Build Release
cmake --build . --config Release
if errorlevel 1 (
    echo Build failed!
    cd ..
    exit /b 1
)

REM Copy executable to parent directory
copy bin\Release\nester.exe ..\nester.exe

cd ..

echo.
echo Build complete! Executable: nester.exe
echo.
