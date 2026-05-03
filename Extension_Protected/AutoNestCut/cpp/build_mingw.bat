@echo off
REM Simple build script using g++ (MinGW)

echo Building AutoNestCut C++ Solver with MinGW...

g++ --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: g++ not found! Please install MinGW-w64.
    echo.
    echo Download from: https://github.com/niXman/mingw-builds-binaries/releases
    echo Install and add to PATH, then run this script again.
    pause
    exit /b 1
)

echo Compiling...
g++ -std=c++17 -O3 -Wall -Wextra ^
    src/main.cpp ^
    src/nesting.cpp ^
    src/geometry.cpp ^
    -o nester.exe

if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build successful!
echo Executable: nester.exe
echo ========================================
echo.

REM Test if it runs
echo Testing executable...
nester.exe 2>nul
if errorlevel 1 (
    echo Executable created successfully.
) else (
    echo Warning: Executable may have issues.
)

echo.
echo To test with sample data, run:
echo   nester.exe test_input.json test_output.json
echo.
