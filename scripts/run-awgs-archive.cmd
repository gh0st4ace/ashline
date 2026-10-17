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

rem Launcher for Task Scheduler. Absolute paths: under SYSTEM, %USERPROFILE%
rem points at the system profile, not at the operator's.
set "PATH=%PATH%;C:\Program Files\Git\cmd"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%WB_CONFIG_DIR%\update-awgs-archive.ps1" ^
  -ArchiveDir "%WB_COLLECTIONS_DIR%\awesome-game-security-archive" ^
  -Cache "%WB_COLLECTIONS_DIR%\ags-archive.tar.gz"
exit /b 0