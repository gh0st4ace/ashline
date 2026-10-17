@echo off
REM build_bench.bat - build the game-lab native bench with MSVC (VS 18 Community x64).
REM Usage: build_bench.bat   (from anywhere; paths are absolute)
setlocal
set VSROOT=D:\Program Files\Microsoft Visual Studio\18\Community
call "%VSROOT%\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
if errorlevel 1 exit /b 1
cd /d D:\opencode\game-lab\bench
cl /nologo /W4 /Zi /FS /DYNAMICBASE /MD bench_native.c /Fe:bench_native.exe /Fm:bench_native.map kernel32.lib user32.lib
if errorlevel 1 exit /b 1
echo BUILD OK
