@echo of
set /p <nul="Generating 'Dracula.igtheme'..."
powershell.exe -noprofile -command try { Compress-Archive ./Dracula -Destination ./Dracula.igtheme -Force } catch { exit 1 }
if %errorlevel% equ 0 (echo. done.) else (echo. error code: %errorlevel%)
exit /b %errorlevel%
