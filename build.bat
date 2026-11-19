@echo off
setlocal
rem ===========================================================================
rem  CssPacker universal build script - Delphi 12.2 (Studio 23.0)
rem  Usage: build.bat [32|64|all]   (default: all)
rem ===========================================================================

set "ROOT=%~dp0"
set "DELPHI=C:\Program Files (x86)\Embarcadero\Studio\23.0\bin"
set "SRC=%ROOT%Source"
set "LIB=%ROOT%Lib"
set "CLI=%ROOT%CLI"
set "GUI=%ROOT%GUI"
set "TESTS=%ROOT%Tests"
set "BIN=%ROOT%bin"
set "UNITOUT=%ROOT%bin\dcu"

if not exist "%BIN%" mkdir "%BIN%"
if not exist "%UNITOUT%" mkdir "%UNITOUT%"
if not exist "%UNITOUT%\32" mkdir "%UNITOUT%\32"
if not exist "%UNITOUT%\64" mkdir "%UNITOUT%\64"

set "TARGET=%1"
if "%TARGET%"=="" set "TARGET=all"

echo.
echo ============================================================
echo  CssPacker build - Delphi 12.2
echo  Target: %TARGET%
echo ============================================================

if /I "%TARGET%"=="32"   goto :build32
if /I "%TARGET%"=="64"   goto :build64
if /I "%TARGET%"=="all"  goto :buildall
echo Unknown target: %TARGET%
exit /b 1

:buildall
call :build32
if errorlevel 1 exit /b 1
call :build64
if errorlevel 1 exit /b 1
goto :eof

:build32
echo.
echo --- Win32 -------------------------------------------------
"%DELPHI%\dcc32.exe" -B -Q -W -N0"%UNITOUT%\32" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%CLI%\CssPackerCli.dpr"
if errorlevel 1 exit /b 1
"%DELPHI%\dcc32.exe" -B -Q -W -N0"%UNITOUT%\32" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%GUI%\CssPackerGui.dpr"
if errorlevel 1 exit /b 1
"%DELPHI%\dcc32.exe" -B -Q -W -N0"%UNITOUT%\32" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%TESTS%\CssPackerTests.dpr"
if errorlevel 1 exit /b 1
goto :eof

:build64
echo.
echo --- Win64 -------------------------------------------------
"%DELPHI%\dcc64.exe" -B -Q -W -N0"%UNITOUT%\64" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%CLI%\CssPackerCli.dpr"
if errorlevel 1 exit /b 1
"%DELPHI%\dcc64.exe" -B -Q -W -N0"%UNITOUT%\64" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%GUI%\CssPackerGui.dpr"
if errorlevel 1 exit /b 1
"%DELPHI%\dcc64.exe" -B -Q -W -N0"%UNITOUT%\64" -E"%BIN%" -U"%SRC%;%LIB%" -I"%SRC%;%LIB%" "%TESTS%\CssPackerTests.dpr"
if errorlevel 1 exit /b 1
goto :eof
