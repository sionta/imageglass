@echo of
cd /d "%~dp0"
set /p <nul="Generating 'Dracula.igtheme'..."
powershell.exe -noprofile -command try { Compress-Archive -Path ./Dracula -Destination ./dracula.igtheme -Force } catch { exit $lastexitcode }
if %errorlevel% equ 0 (echo. done.) else (echo. error: %errorlevel%)
exit /b %errorlevel%
