@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem =====================================================================
rem  Multisim Master Database repair
rem  Clears the user configuration cache, restores database file
rem  attributes and re-registers the DAO / Jet database engines.
rem
rem  Usage:
rem    fix_multisim_database.bat              normal repair
rem    fix_multisim_database.bat -DryRun      preview only, changes nothing
rem    fix_multisim_database.bat -Full        also delete the local data cache
rem =====================================================================

set "DRY_RUN=0"
set "FULL_RESET=0"
set "LOG=%TEMP%\multisim_db_fix.log"
set "BACKUP_ROOT=%TEMP%\multisim_db_fix_backup"
set "PF32=%ProgramFiles(x86)%"
set "CPF32=%CommonProgramFiles(x86)%"

if /i "%~1"=="-DryRun" set "DRY_RUN=1"
if /i "%~1"=="-Full" set "FULL_RESET=1"
if /i "%~1"=="/?" goto usage
if /i "%~1"=="-Help" goto usage
if /i "%~2"=="-DryRun" set "DRY_RUN=1"
if /i "%~2"=="-Full" set "FULL_RESET=1"
if /i "%~2"=="/?" goto usage
if /i "%~2"=="-Help" goto usage
goto start

:usage
echo.
echo   fix_multisim_database.bat  [-DryRun] [-Full]
echo.
echo   -DryRun   Show every step without changing anything.
echo   -Full     Also delete the whole local data cache of each version.
echo.
exit /b 0

:start
if "%DRY_RUN%"=="1" goto admin_ready

>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrator privileges...
    set "PASS_ARGS=%~1 %~2"
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "!PASS_ARGS!", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
    exit /B
)

:admin_ready
>nul 2>&1 type nul >> "%LOG%"
call :say "Multisim Master Database repair"
if "%DRY_RUN%"=="1" call :say "Mode: dry run, nothing will be changed"
if "%FULL_RESET%"=="1" call :say "Mode: full reset of the local data cache"
call :say "Log file: %LOG%"
call :say ""

set "SUITE_ROOT=%ProgramData%\National Instruments\Circuit Design Suite"
if not exist "%SUITE_ROOT%" (
    call :say "[ERROR] Circuit Design Suite data folder was not found:"
    call :say "        %SUITE_ROOT%"
    call :say "        Multisim may not be installed on this machine."
    goto fail
)

call :say "[1/5] Closing Multisim and stopping NI services"
call :kill_process "multisim.exe"
call :kill_process "ultiboard.exe"
call :kill_process "nielvishost.exe"
call :stop_service "National Instruments Device Service"
call :stop_service "NI Device Loader"
call :stop_service "National Instruments Configuration Support Service"

call :say ""
call :say "[2/5] Looking for installed versions"
set "FOUND=0"
for /d %%V in ("%SUITE_ROOT%\*") do (
    if exist "%%~fV\database" (
        set /a FOUND+=1
        call :say "      version !FOUND!: %%~nxV"
    )
)
if "!FOUND!"=="0" (
    call :say "[ERROR] No version folder with a database directory was found."
    call :say "        Check: %SUITE_ROOT%"
    goto fail
)

call :say ""
call :say "[3/5] Clearing user configuration caches"
set "STAMP=%RANDOM%%RANDOM%"
set "BACKUP_DIR=%BACKUP_ROOT%\%STAMP%"
for /d %%V in ("%SUITE_ROOT%\*") do (
    if exist "%%~fV\database" (
        set "VER=%%~nxV"
        call :clear_cache "%AppData%\National Instruments\Circuit Design Suite\!VER!\config" "roaming"
        if "%FULL_RESET%"=="1" (
            call :clear_cache "%LocalAppData%\National Instruments\Circuit Design Suite\!VER!" "local"
        ) else (
            call :clear_cache "%LocalAppData%\National Instruments\Circuit Design Suite\!VER!\config" "local"
        )
    )
)

call :say ""
call :say "[4/5] Resetting database file attributes and permissions"
for /d %%V in ("%SUITE_ROOT%\*") do (
    if exist "%%~fV\database" (
        call :fix_database "%%~fV\database"
    )
)

call :say ""
call :say "[5/5] Re-registering DAO and Jet database engines"
call :register_32bit "%CPF32%\Microsoft Shared\DAO\dao360.dll"
call :register_32bit "%SystemRoot%\SysWOW64\msjet40.dll"
call :register_32bit "%SystemRoot%\SysWOW64\msjtes40.dll"
call :register_64bit "%SystemRoot%\System32\dao360.dll"
call :register_64bit "%SystemRoot%\System32\msjet40.dll"
call :register_64bit "%SystemRoot%\System32\msjtes40.dll"

call :say ""
call :say "=================================================="
call :say "Repair finished. Start Multisim and open a database."
call :say "If it still fails, check whether CPCompDev.prz inside"
call :say "the database folder has a size of 0 KB."
call :say "=================================================="
call :say ""
call :say "Log file: %LOG%"
if "%DRY_RUN%"=="0" pause
endlocal
exit /b 0

:fix_database
set "DB=%~1"
if "%DRY_RUN%"=="1" (
    call :say "      would reset attributes of %DB%"
    exit /b 0
)
attrib -r -s -h "%DB%\*.*" /s /d >nul 2>&1
icacls "%DB%" /reset /T /C /Q >nul 2>&1
if exist "%DB%\CPCompDev.prz" (
    for %%F in ("%DB%\CPCompDev.prz") do (
        if %%~zF==0 (
            call :say "      [WARN] CPCompDev.prz is 0 KB in %DB%"
        ) else (
            call :say "      CPCompDev.prz size is %%~zF bytes in %DB%"
        )
    )
)
call :say "      database path: %DB%"
exit /b 0

:clear_cache
set "CACHE=%~1"
set "SCOPE=%~2"
if exist "%CACHE%" (
    if "%DRY_RUN%"=="1" (
        call :say "      would back up and delete %SCOPE% cache: %CACHE%"
        exit /b 0
    )
    set "DEST=%BACKUP_DIR%\%SCOPE%"
    robocopy "%CACHE%" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul 2>&1
    if !ERRORLEVEL! GEQ 8 (
        call :say "      [WARN] backup failed, cache left untouched: %CACHE%"
        exit /b 0
    )
    rd /s /q "%CACHE%" >nul 2>&1
    if exist "%CACHE%" (
        call :say "      [WARN] could not fully delete %CACHE%"
    ) else (
        call :say "      cleared %SCOPE% cache: %CACHE%"
    )
) else (
    call :say "      no %SCOPE% cache: %CACHE%"
)
exit /b 0

:kill_process
tasklist /fi "imagename eq %~1" 2>nul | find /i "%~1" >nul
if errorlevel 1 (
    exit /b 0
)
if "%DRY_RUN%"=="1" (
    call :say "      would close %~1"
    exit /b 0
)
taskkill /f /im "%~1" >nul 2>&1
call :say "      closed %~1"
exit /b 0

:stop_service
sc query "%~1" >nul 2>&1
if errorlevel 1 (
    exit /b 0
)
if "%DRY_RUN%"=="1" (
    call :say "      would stop service %~1"
    exit /b 0
)
net stop "%~1" >nul 2>&1
call :say "      stop requested for service %~1"
exit /b 0

:register_32bit
if not exist "%~1" (
    exit /b 0
)
if not exist "%SystemRoot%\SysWOW64\regsvr32.exe" (
    call :say "      [WARN] no 32-bit regsvr32, skipped %~nx1"
    exit /b 0
)
if "%DRY_RUN%"=="1" (
    call :say "      would register 32-bit %~nx1"
    exit /b 0
)
"%SystemRoot%\SysWOW64\regsvr32.exe" /s "%~1" >nul 2>&1
if errorlevel 1 (
    call :say "      [WARN] failed to register %~nx1"
) else (
    call :say "      registered 32-bit %~nx1"
)
exit /b 0

:register_64bit
if not exist "%~1" (
    exit /b 0
)
if "%DRY_RUN%"=="1" (
    call :say "      would register 64-bit %~nx1"
    exit /b 0
)
"%SystemRoot%\System32\regsvr32.exe" /s "%~1" >nul 2>&1
if errorlevel 1 (
    call :say "      [WARN] failed to register %~nx1"
) else (
    call :say "      registered 64-bit %~nx1"
)
exit /b 0

:say
if "%~1"=="" (
    echo.
    >>"%LOG%" echo.
    exit /b 0
)
echo %~1
>>"%LOG%" echo %~1
exit /b 0

:fail
call :say ""
if "%DRY_RUN%"=="0" pause
endlocal
exit /b 1
