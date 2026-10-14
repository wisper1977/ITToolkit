@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "HIDDEN_LAUNCHER=%~dp0ITToolkit-LaunchHidden.vbs"
if not exist "%HIDDEN_LAUNCHER%" (
  echo ERROR: ITToolkit-LaunchHidden.vbs is missing from "%~dp0"
  pause
  exit /b 1
)
start "" "%SystemRoot%\System32\wscript.exe" //B "%HIDDEN_LAUNCHER%"
exit /b
