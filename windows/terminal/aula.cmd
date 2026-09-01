@echo off
rem AulaRaiz terminal entrypoint. Installed next to aularaiz-agent.exe by the
rem Windows installer; the installer also adds this directory to the user PATH.
setlocal
set "AULARAIZ_AGENT=%~dp0aularaiz-agent.exe"
if not exist "%AULARAIZ_AGENT%" (
  1>&2 echo AulaRaiz agent executable not found: "%AULARAIZ_AGENT%"
  exit /b 3
)
"%AULARAIZ_AGENT%" %*
exit /b %ERRORLEVEL%
