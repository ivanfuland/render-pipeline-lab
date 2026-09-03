@echo off
setlocal

set "DEBUG_MODE=%~1"
set "PHASE=%~2"
set "SHADOW_MODE=%~3"
if not defined DEBUG_MODE set "DEBUG_MODE=ThreadBoundary"
if not defined PHASE set "PHASE=Phase1"
if not defined SHADOW_MODE set "SHADOW_MODE=On"

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "SCRIPT=%PROJECT_ROOT%\Tools\Scripts\StartStagedDebug.ps1"

if "%RENDER_PIPELINE_DRY_RUN%"=="1" (
    echo pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ProjectRoot "%PROJECT_ROOT%" -DebugMode %DEBUG_MODE% -Phase %PHASE% -ShadowMode %SHADOW_MODE% -WaitForAttach
    exit /b 0
)

pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ProjectRoot "%PROJECT_ROOT%" -DebugMode %DEBUG_MODE% -Phase %PHASE% -ShadowMode %SHADOW_MODE% -WaitForAttach
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" pause
exit /b %RESULT%
