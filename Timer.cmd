@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   KOMPAKT TIMER (INGEN ADMIN / MULTI-SCREEN)
echo ===================================================
echo.
set /p targetTime="Indtast tidspunkt (HHMM eller HH:MM): "

:: Fjern eventuelle kolonner
set "cleanTime=%targetTime::=%"

:: Tjek om input er 4 cifre, og indsæt kolon, så PowerShell forstår det
set "formattedTime="
if "%cleanTime:~4,1%" EQU "" (
    if "%cleanTime:~3,1%" NEQ "" (
        set "formattedTime=%cleanTime:~0,2%:%cleanTime:~2,2%"
    )
)
if "%formattedTime%"=="" set "formattedTime=%targetTime%"

echo.
echo Starter nedtælling til %formattedTime%... Hold dette vindue åbent.
echo WARNING: Computeren slukker RÅT og USIKKERT, selvom skærmen låses!
echo.
echo [BETJENING]
echo * Brug PILETASTERNE til at flytte timeren på tværs af skærme.
echo * Tryk på PAGE UP (PgUp) for at gøre timeren STØRRE.
echo * Tryk på PAGE DOWN (PgDn) for at gøre timeren MINDRE.
echo * Tryk på ESC for at AFBRYDE timeren og lukke programmet.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$psCode = {" ^
    "    Add-Type -AssemblyName System.Windows.Forms;" ^
    "    Add-Type -AssemblyName System.Drawing;" ^
    "    $DPIAPI = 'using System; using System.Runtime.InteropServices; public class Win32DPI { [DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware(); }';" ^
    "    Add-Type -TypeDefinition $DPIAPI;" ^
    "    [Win32DPI]::SetProcessDPIAware();" ^
    "    $targetInput = '%formattedTime%';" ^
    "    $parsedTime = [DateTime]::MinValue;" ^
    "    if (-not [DateTime]::TryParseExact($targetInput, @('HH:mm', 'H:mm'), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedTime)) {" ^
    "        [void][DateTime]::TryParse($targetInput, [ref]$parsedTime);" ^
    "    }" ^
    "    if ($parsedTime -eq [DateTime]::MinValue) {" ^
    "        $script:target = [DateTime]::Now.AddMinutes(5);" ^
    "    } else {" ^
    "        $script:target = [DateTime]::Today.Add($parsedTime.TimeOfDay);" ^
    "        if ($script:target -lt [DateTime]::Now) { $script:target = $script:target.AddDays(1); }" ^
    "    }" ^
    "    $form = New-Object System.Windows.Forms.Form;" ^
    "    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None;" ^
    "    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen;" ^
    "    $form.Left = $vs.Left;" ^
    "    $form.Top = $vs.Top;" ^
    "    $form.Width = $vs.Width;" ^
    "    $form.Height = $vs.Height;" ^
    "    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual;" ^
    "    $form.BackColor = [System.Drawing.Color]::Lime;" ^
    "    $form.TransparencyKey = [System.Drawing.Color]::Lime;" ^
    "    $form.TopMost = $true;" ^
    "    $primBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds;" ^
    "    $panel = New-Object System.Windows.Forms.Panel;" ^
    "    $panel.Width = 190;" ^
    "    $panel.Height = 45;" ^
    "    $panel.BackColor = [System.Drawing.Color]::Black;" ^
    "    $label = New-Object System.Windows.Forms.Label;" ^
    "    $label.Dock = [System.Windows.Forms.DockStyle]::Fill;" ^
    "    $script:fontSize = 24;" ^
    "    $label.Font = New-Object System.Drawing.Font('Arial', $script:fontSize, [System.Drawing.FontStyle]::Bold);" ^
    "    $label.ForeColor = [System.Drawing.Color]::White;" ^
    "    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter;" ^
    "    $panel.Controls.Add($label);" ^
    "    $form.Controls.Add($panel);" ^
    "    $gridSize = 40;" ^
    "    $script:currentX = [math]::Floor(($primBounds.Left + (($primBounds.Width - $panel.Width) / 2)) / $gridSize) * $gridSize;" ^
    "    $script:currentY = [math]::Floor(($primBounds.Top + 50) / $gridSize) * $gridSize;" ^
    "    $updatePosition = {" ^
    "        $minX = [math]::Floor($vs.Left / $gridSize) * $gridSize;" ^
    "        $maxX = [math]::Floor(($vs.Right - $panel.Width) / $gridSize) * $gridSize;" ^
    "        $minY = [math]::Floor($vs.Top / $gridSize) * $gridSize;" ^
    "        $maxY = [math]::Floor(($vs.Bottom - $panel.Height) / $gridSize) * $gridSize;" ^
    "        if ($script:currentX -lt $minX) { $script:currentX = $minX }" ^
    "        if ($script:currentX -gt $maxX) { $script:currentX = $maxX }" ^
    "        if ($script:currentY -lt $minY) { $script:currentY = $minY }" ^
    "        if ($script:currentY -gt $maxY) { $script:currentY = $maxY }" ^
    "        $panel.Left = $script:currentX - $vs.Left;" ^
    "        $panel.Top = $script:currentY - $vs.Top;" ^
    "    };" ^
    "    & $updatePosition;" ^
    "    $form.add_KeyDown({ " ^
    "        param($sender, $e);" ^
    "        $key = $e.KeyCode;" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Left)  { $script:currentX -= $gridSize; & $updatePosition }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Right) { $script:currentX += $gridSize; & $updatePosition }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Up)    { $script:currentY -= $gridSize; & $updatePosition }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Down)  { $script:currentY += $gridSize; & $updatePosition }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Prior) {" ^
    "            if ($script:fontSize -lt 60) {" ^
    "                $script:fontSize += 4;" ^
    "                $panel.Width += 30;" ^
    "                $panel.Height += 8;" ^
    "                $label.Font = New-Object System.Drawing.Font('Arial', $script:fontSize, [System.Drawing.FontStyle]::Bold);" ^
    "                & $updatePosition;" ^
    "            }" ^
    "        }" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Next) {" ^
    "            if ($script:fontSize -gt 12) {" ^
    "                $script:fontSize -= 4;" ^
    "                $panel.Width -= 30;" ^
    "                $panel.Height -= 8;" ^
    "                $label.Font = New-Object System.Drawing.Font('Arial', $script:fontSize, [System.Drawing.FontStyle]::Bold);" ^
    "                & $updatePosition;" ^
    "            }" ^
    "        }" ^
    "    });" ^
    "    $timer = New-Object System.Windows.Forms.Timer;" ^
    "    $timer.Interval = 1000;" ^
    "    $timer.add_Tick({ " ^
    "        $diff = $script:target - [DateTime]::Now;" ^
    "        if ($diff.TotalSeconds -le 0) {" ^
    "            $label.Text = '00:00:00';" ^
    "            $timer.Stop();" ^
    "            shutdown.exe /s /f /t 0;" ^
    "            $form.Close();" ^
    "        } else {" ^
    "            $totalHours = [Math]::Floor($diff.TotalHours);" ^
    "            $label.Text = '{0:D2}:{1:D2}:{2:D2}' -f [int]$totalHours, $diff.Minutes, $diff.Seconds;" ^
    "        }" ^
    "    });" ^
    "    $timer.Start();" ^
    "    [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
