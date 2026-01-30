@echo off
echo ========================================
echo Testing AutoNestCut C++ Solver
echo ========================================
echo.

REM Check if executable exists
if not exist nester.exe (
    echo ERROR: nester.exe not found!
    echo Please run build_mingw.bat first.
    echo.
    pause
    exit /b 1
)

echo Running test with sample data...
echo.

nester.exe test_input.json test_output.json

if errorlevel 1 (
    echo.
    echo ========================================
    echo TEST FAILED!
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo TEST PASSED!
echo ========================================
echo.

if exist test_output.json (
    echo Output file created: test_output.json
    echo File size: 
    dir test_output.json | find "test_output.json"
    echo.
    echo First few lines of output:
    type test_output.json | more /E +10
) else (
    echo WARNING: Output file not created!
)

echo.
echo ========================================
echo Next step: Integration with Ruby
echo ========================================
echo.
pause
