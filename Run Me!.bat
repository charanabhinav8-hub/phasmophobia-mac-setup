@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================================
REM GENERIC GAME LAUNCHER (MANUAL SAFE MODE)
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_FILE=%SCRIPT_DIR%\launcher.log"
set "GAME_DIR=%SCRIPT_DIR%\Phasmophobia"
set "GAME_EXE=%GAME_DIR%\Launcher.exe"

echo ============================================================ >> "%LOG_FILE%"
echo Launch: %DATE% %TIME% >> "%LOG_FILE%"
echo ScriptDir: %SCRIPT_DIR% >> "%LOG_FILE%"
echo GameDir: %GAME_DIR% >> "%LOG_FILE%"
echo GameExe: %GAME_EXE% >> "%LOG_FILE%"

REM ============================================================================
REM CHECK
REM ============================================================================

if not exist "%GAME_EXE%" (
    echo [ERROR] EXE not found >> "%LOG_FILE%"
    echo ❌ EXE not found
    pause
    exit /b 1
)

REM ============================================================================
REM EXECUTE (IMPORTANT)
REM ============================================================================

pushd "%GAME_DIR%"
start "" "%GAME_EXE%"
set "START_CODE=%ERRORLEVEL%"
popd

if not "%START_CODE%"=="0" (
    echo [ERROR] Failed to launch EXE. StartCode: %START_CODE% >> "%LOG_FILE%"
    echo ❌ Failed to launch the game
    pause
    exit /b %START_CODE%
)

echo LaunchStatus: SUCCESS >> "%LOG_FILE%"
exit /b 0
