@echo off
setlocal EnableExtensions

rem Run from the project directory even when started by double-click.
cd /d "%~dp0"

set "FLASHER=C:\Infineon\AURIX-Studio-1.10.10\tools\AurixFlasherSoftwareTool_v3.0.4\AURIXFlasher.exe"
set "HEX=%CD%\Debug\E01_gpio_demo.hex"
set "LOG=%CD%\Debug\flash.log"
set "DEVICE_ID=0"

if not exist "%FLASHER%" (
    echo [ERROR] AURIX Flasher was not found:
    echo         "%FLASHER%"
    echo.
    echo Set FLASHER in flash.bat to the actual AURIXFlasher.exe path.
    endlocal
    exit /b 1
)

if not exist "%HEX%" (
    echo [ERROR] HEX file was not found:
    echo         "%HEX%"
    echo.
    echo Run build_headless.bat first.
    endlocal
    exit /b 1
)

if not exist "%CD%\Debug" mkdir "%CD%\Debug"

echo AURIX TC264 flashing started.
echo HEX: "%HEX%"
echo Device ID: %DEVICE_ID%
echo.
echo Connect the powered board through its DAP/DEBUG interface.
echo Do not disconnect the board while flashing.
echo.

"%FLASHER%" ^
  -hex "%HEX%" ^
  -id "%DEVICE_ID%" ^
  -erase on ^
  -prog on ^
  -ver on ^
  -connect 6 ^
  -start on ^
  -log "%LOG%"

set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" (
    echo.
    echo [ERROR] Flash failed with exit code %RESULT%.
    echo Log file:
    echo "%LOG%"
    endlocal
    exit /b %RESULT%
)

echo.
echo Flash completed successfully.
echo Verification completed successfully.
echo Log file:
echo "%LOG%"

endlocal

pause

exit /b 0
