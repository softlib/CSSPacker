@echo off
setlocal
set "ROOT=%~dp0"
echo Running CssPacker test suite...
"%ROOT%bin\CssPackerTests.exe"
exit /b %ERRORLEVEL%
