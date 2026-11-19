@echo off
setlocal DisableDelayedExpansion
start "" /d "%~dp0." "%~dp0Fiefdom.exe" --rendering-method gl_compatibility --rendering-driver opengl3 %*
