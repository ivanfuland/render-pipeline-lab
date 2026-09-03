@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
if not defined UE_ENGINE_ROOT (
    echo ERROR: UE_ENGINE_ROOT is not set.
    if not "%RENDER_PIPELINE_DRY_RUN%"=="1" pause
    exit /b 2
)
set "SCRIPT=%PROJECT_ROOT%\Tools\Scripts\PrepareCookedSandbox.ps1"

if "%RENDER_PIPELINE_DRY_RUN%"=="1" (
    echo pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ProjectRoot "%PROJECT_ROOT%" -EngineRoot "%UE_ENGINE_ROOT%" -Iterative
    exit /b 0
)

pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ProjectRoot "%PROJECT_ROOT%" -EngineRoot "%UE_ENGINE_ROOT%" -Iterative
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" pause
exit /b %RESULT%
