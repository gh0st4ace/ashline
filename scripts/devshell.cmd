@echo off
@rem -- Path resolution ---------------------------------------------------------
@rem These launchers run under Task Scheduler, where %USERPROFILE% points at
@rem the SYSTEM profile rather than the interactive user. That is exactly WHY
@rem the original used an absolute path rather than %USERPROFILE%, so do not
@rem "simplify" it back. install.ps1 writes scripts\paths.cmd with the resolved
@rem values; without it these fall back to the defaults below.
if not defined WB_CONFIG_DIR      set "WB_CONFIG_DIR=D:\opencode-config"
if not defined WB_COLLECTIONS_DIR set "WB_COLLECTIONS_DIR=D:\opencode"
if not defined WB_TOOLS_DIR       set "WB_TOOLS_DIR=D:\Tools"
@rem --------------------------------------------------------------------------

REM Enter the Visual Studio + Windows SDK + WDK build environment for this machine.
REM
REM Why this exists: cl.exe, msbuild.exe and signtool.exe are installed but are
REM not on PATH. Visual Studio Community 2026 lives on D:, the Windows Kits on
REM D:. Nothing resolves them without explicitly entering the developer
REM environment, so every driver, hook or native build starts here.
REM
REM Usage:
REM   devshell.cmd                        interactive x64 native shell
REM   devshell.cmd x86                    32-bit host/target
REM   devshell.cmd arm64                  ARM64 host/target
REM   devshell.cmd x64 cmd /c "build ..."  run one command, then exit
REM
REM Known-good components on this machine:
REM   MSVC 14.51.36231, Windows SDK 10.0.26100.0, WDK (Lib\wdf), signtool 10.0.26100.0

setlocal enabledelayedexpansion

set "VSDEV=D:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
set "WDKBIN=D:\Windows Kits\10\bin\10.0.26100.0\x64"

if not exist "%VSDEV%" (
    echo [devshell] vcvarsall.bat not found at "%VSDEV%"
    exit /b 1
)

set "ARG1=%~1"

if "%ARG1%"=="" goto interactive

REM one-shot mode
REM NOTE: shift does NOT affect %*, it always expands to every argument.
REM So reconstruct the tail explicitly from %1..%9 after shifting.
set "ARCH=%ARG1%"
shift
call "%VSDEV%" %ARCH% >nul 2>&1
if exist "%WDKBIN%" set "PATH=%WDKBIN%;%PATH%"
echo [devshell] arch=%ARCH% running: %1 %2 %3 %4 %5 %6 %7 %8 %9
%1 %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%

:interactive
call "%VSDEV%" x64 >nul 2>&1
if exist "%WDKBIN%" set "PATH=%WDKBIN%;%PATH%"
where cl >nul 2>&1 && echo [devshell] cl      OK || echo [devshell] cl      MISSING
where link >nul 2>&1 && echo [devshell] link    OK || echo [devshell] link    MISSING
where signtool >nul 2>&1 && echo [devshell] signtool OK || echo [devshell] signtool MISSING
where msbuild >nul 2>&1 && echo [devshell] msbuild OK || echo [devshell] msbuild MISSING
echo [devshell] interactive x64 shell ready.
cmd /k
endlocal