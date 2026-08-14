@echo off
title Windows Baggrunds-Oplåser (Ingen Admin Krævet)
chcp 65001 >nul
echo ===================================================
echo     FJERNER RESTRIKTIONER PÅ BRUGERPROFIL
echo ===================================================
echo.

:: 1. Fjern restriktioner i brugerens eget registreringsdatabase-miljø (HKCU)
echo Låser personlige indstillinger op...

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "Wallpaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "WallpaperStyle" /f >nul 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "Wallpaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "WallpaperStyle" /f >nul 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\LocalUser\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "NoChangingWallPaper" /f >nul 2>&1

:: 2. Nulstil Windows Control Panel indstillingen for låst baggrund
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "NoChangingWallPaper" /t REG_DWORD /d 0 /f >nul 2>&1

:: 3. Genstart Windows Explorer for at gennemtvinge ændringerne i systemet med det samme
echo.
echo Genstarter Windows Explorer for at aktivere ændringer...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul
start explorer.exe

echo.
echo ===================================================
echo  FÆRDIG! Du kan nu gå ind under:
echo  Indstillinger -> Personlig tilpasning -> Baggrund
echo ===================================================
echo.
pause
