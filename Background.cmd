@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   FEJLSIKKER AUTO-RGB SPLIT og TAPETSKIFTER
echo ===================================================
echo.

:: Standardværdi er sort (000000000)
set "input_rgb=000000000"
set /p user_input="Indtast RGB (f.eks. 200200051, 1200533 eller '255 0 0'): "

if not "%user_input%"=="" (
    set "input_rgb=%user_input%"
)

:: Definer den midlertidige sti til billedfilen
set "WallpaperPath=%TEMP%\rgb_wallpaper.png"

echo Behandler dit input og genererer tapet...
:: PowerShell pakker input ud, sikrer at biblioteket indlæses, og gemmer som PNG
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Add-Type -AssemblyName System.Drawing;" ^
    "$raw = '%input_rgb%'.Trim();" ^
    "if ($raw -match '^\d+$') {" ^
    "    while ($raw.Length -lt 9) { $raw = '0' + $raw };" ^
    "    $r = [int]$raw.Substring(0,3);" ^
    "    $g = [int]$raw.Substring(3,3);" ^
    "    $b = [int]$raw.Substring(6,3);" ^
    "} else {" ^
    "    $colors = $raw -split ' ';" ^
    "    $r = [int]$colors[0]; $g = [int]$colors[1]; $b = [int]$colors[2];" ^
    "}" ^
    "if ($r -gt 255) { $r = 255 }; if ($g -gt 255) { $g = 255 }; if ($b -gt 255) { $b = 255 };" ^
    "$bmp = New-Object System.Drawing.Bitmap(1,1);" ^
    "$color = [System.Drawing.Color]::FromArgb($r, $g, $b);" ^
    "$bmp.SetPixel(0,0,$color);" ^
    "$bmp.Save('%WallpaperPath%', [System.Drawing.Imaging.ImageFormat]::Png);"

:: 1. Fjern eventuelle låste it-politikker (Policies)
echo Fjerner begrænsninger...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "Wallpaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "WallpaperStyle" /f >nul 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "Wallpaper" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "WallpaperStyle" /f >nul 2>&1

reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "Wallpaper" /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v "WallpaperStyle" /f >nul 2>&1

reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "NoChangingWallPaper" /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "Wallpaper" /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "WallpaperStyle" /f >nul 2>&1

:: 2. Indstil det nye tapet i registreringsdatabasen (Tile strækker 1-pixel billedet ud)
echo Indstiller nyt tapet i registreringsdatabasen...
reg add "HKCU\Control Panel\Desktop" /v "Wallpaper" /t REG_SZ /d "%WallpaperPath%" /f >nul
reg add "HKCU\Control Panel\Desktop" /v "WallpaperStyle" /t REG_SZ /d "0" /f >nul
reg add "HKCU\Control Panel\Desktop" /v "TileWallpaper" /t REG_SZ /d "1" /f >nul

:: 3. Tving Windows til at genindlæse tapetet med den kraftfulde Win32 API
echo Opdaterer skrivebordsmiljøet...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$api = '[DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);';" ^
    "$type = Add-Type -MemberDefinition $api -Name WallpaperAPI -PassThru;" ^
    "[void]$type::SystemParametersInfo(20, 0, '%WallpaperPath%', 3);"

:: 4. Genstart Windows Explorer for at opdatere det visuelt overalt
echo Genstarter Explorer...
taskkill /f /im explorer.exe >nul
start explorer.exe

echo.
echo Tapetet er blevet opdateret baseret på dit input!
echo.

pause
