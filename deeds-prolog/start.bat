@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "SWIPL="
where swipl >nul 2>&1
if %ERRORLEVEL%==0 (
  for /f "delims=" %%I in ('where swipl') do (
    set "SWIPL=%%I"
    goto have_swipl
  )
)

if exist "%ProgramFiles%\swipl\bin\swipl.exe" (
  set "SWIPL=%ProgramFiles%\swipl\bin\swipl.exe"
  goto have_swipl
)
if exist "%ProgramFiles(x86)%\swipl\bin\swipl.exe" (
  set "SWIPL=%ProgramFiles(x86)%\swipl\bin\swipl.exe"
  goto have_swipl
)
if exist "C:\Program Files\swipl\bin\swipl.exe" (
  set "SWIPL=C:\Program Files\swipl\bin\swipl.exe"
  goto have_swipl
)

echo SWI-Prolog was not found.
echo.
echo Install the Windows 64-bit build from:
echo   https://www.swi-prolog.org/download/stable
echo and tick "Add SWI-Prolog to the system PATH".
echo Then open a new Command Prompt and double-click start.bat again.
echo See WINDOWS_SETUP.md for the full steps.
pause
exit /b 1

:have_swipl
echo Using SWI-Prolog: %SWIPL%
echo Starting the deeds office register at http://localhost:8080/
echo Close this window to stop the server.
echo.
"%SWIPL%" -s "%~dp0scripts\server.pl" -- %*
if errorlevel 1 (
  echo.
  echo The server stopped with an error.
  pause
)
