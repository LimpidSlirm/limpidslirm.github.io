@echo off
setlocal EnableExtensions

rem Run from the project directory even when this file is started by double-click.
cd /d "%~dp0"

rem AURIX Studio 1.10.10 is installed on this machine. Override this value if
rem Studio is installed elsewhere: set AURIX_STUDIO=C:\path\to\AURIX-Studio
if defined AURIX_STUDIO (
    set "ADS=%AURIX_STUDIO%"
) else (
    set "ADS=C:\Infineon\AURIX-Studio-1.10.10"
)
set "STUDIO=%ADS%\AURIX-studioc.exe"
set "STUDIO_INI=%ADS%\AURIX-studio.ini"
set "PROJECT=E01_gpio_demo"
set "PROJECT_DIR=%CD%"

rem Use the old workspace when it exists; otherwise keep a local workspace.
if defined AURIX_WORKSPACE (
    set "WS=%AURIX_WORKSPACE%"
) else if exist "D:\ads_workspace" (
    set "WS=D:\ads_workspace"
) else (
    set "WS=%PROJECT_DIR%\.."
)

set "ACTION=build"
if /I "%~1"=="cleanBuild" set "ACTION=cleanBuild"
if /I "%~1"=="build" set "ACTION=build"
set "LC_ALL=C"
set "LANG=C"

if not exist "%STUDIO%" (
    echo [ERROR] AURIX Studio was not found: "%STUDIO%"
    echo Set AURIX_STUDIO to the actual installation directory.
    exit /b 1
)
if not exist "%STUDIO_INI%" (
    echo [ERROR] AURIX Studio configuration was not found: "%STUDIO_INI%"
    exit /b 1
)
if not exist ".project" (
    echo [ERROR] Project file was not found: "%PROJECT_DIR%\.project"
    exit /b 1
)
if not exist "%WS%" mkdir "%WS%"
if errorlevel 1 (
    echo [ERROR] Could not create workspace: "%WS%"
    exit /b 1
)

set "BACKUP=%TEMP%\%PROJECT%_project_%RANDOM%.bak"
set "HEADLESS_INI=%TEMP%\%PROJECT%_headless_%RANDOM%.ini"
copy /Y ".project" "%BACKUP%" >nul
if errorlevel 1 (
    echo [ERROR] Could not back up .project.
    exit /b 1
)

rem Remove the graphical perspective from Studio's launcher configuration.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$lines = Get-Content -LiteralPath '%STUDIO_INI%';" ^
  "$out = New-Object System.Collections.Generic.List[string];" ^
  "for ($i = 0; $i -lt $lines.Count; $i++) {" ^
  "  if ($lines[$i] -eq '-perspective') { $i++; continue }" ^
  "  [void]$out.Add($lines[$i])" ^
  "};" ^
  "[System.IO.File]::WriteAllLines('%HEADLESS_INI%', $out, [System.Text.Encoding]::ASCII)"
if errorlevel 1 goto :failed

rem The Project Booster builder requires the graphical workbench.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path = Join-Path (Get-Location) '.project';" ^
  "$content = Get-Content -Raw -LiteralPath $path;" ^
  "$content = $content -replace '(?s)\s*<buildCommand>\s*<name>com\.infineon\.aurix\.buildsystem\.builders\.booster.*?</buildCommand>', '';" ^
  "[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::ASCII)"
if errorlevel 1 goto :failed

echo Building %PROJECT% in "%WS%"...
"%STUDIO%" --launcher.ini "%HEADLESS_INI%" --launcher.suppressErrors -nosplash ^
  -application com.tasking.managedbuilder.headlessbuild -data "%WS%" ^
  -importAll "%PROJECT_DIR%" -%ACTION% "%PROJECT%/Debug"
set "BUILD_RESULT=%ERRORLEVEL%"
goto :restore

:failed
set "BUILD_RESULT=1"

:restore
copy /Y "%BACKUP%" ".project" >nul
set "RESTORE_RESULT=%ERRORLEVEL%"
del /Q "%BACKUP%" >nul 2>&1
del /Q "%HEADLESS_INI%" >nul 2>&1
if not "%RESTORE_RESULT%"=="0" (
    echo [ERROR] Could not restore .project.
    endlocal
    exit /b 1
)
if not "%BUILD_RESULT%"=="0" (
    echo [ERROR] Build failed with exit code %BUILD_RESULT%.
    endlocal
    exit /b %BUILD_RESULT%
)
echo Build completed successfully.
endlocal

pause

exit /b 0
