@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   SNAKE: MULTI-SCREEN + INPUT COMMAND QUEUE
echo ===================================================
echo.

:: ===================================================
:: INDSTILLINGER (Du kan ændre værdierne herunder)
:: ===================================================
:: Sæt procentdelen af skærmen, der skal være fyldt med æbler (f.eks. 0.1 til 0.5)
set apple_percentage=0.2
:: ===================================================

echo VÆLG HASTIGHED:
echo   - 1: Langsom
echo   - 2: Normal (Anbefalet)
echo   - 3: Hurtig
echo.
set /p valg="Indtast dit valg (1, 2 eller 3): "

set interval=90
if "%valg%"=="1" set interval=130
if "%valg%"=="2" set interval=85
if "%valg%"=="3" set interval=55

echo.
echo STYRING: 
echo   - Brug W, A, S, D eller PILTASTERNE!
echo   - Kø-systemet (Queue) sikrer 100%% instant respons.
echo   - Tryk på ESC-tasten for at lukke spillet.
echo.
echo Starter spillet med %apple_percentage%%% æbler... Hold dette vindue åbent.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$psCode = {" ^
    "    Add-Type -AssemblyName System.Windows.Forms;" ^
    "    Add-Type -AssemblyName System.Drawing;" ^
    "    $DPIAPI = 'using System; using System.Runtime.InteropServices; public class Win32DPI { [DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware(); }';" ^
    "    Add-Type -TypeDefinition $DPIAPI;" ^
    "    [Win32DPI]::SetProcessDPIAware();" ^
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
    "    $form.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).SetValue($form, $true, $null);" ^
    "    $primBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds;" ^
    "    $gridSize = 40;" ^
    "    $minX = [math]::Floor($vs.Left / $gridSize) * $gridSize;" ^
    "    $maxX = [math]::Floor($vs.Right / $gridSize) * $gridSize;" ^
    "    $minY = [math]::Floor($vs.Top / $gridSize) * $gridSize;" ^
    "    $maxY = [math]::Floor($vs.Bottom / $gridSize) * $gridSize;" ^
    "    $script:snakeX = [math]::Floor(($primBounds.Left + ($primBounds.Width / 2)) / $gridSize) * $gridSize;" ^
    "    $script:snakeY = [math]::Floor(($primBounds.Top + ($primBounds.Height / 2)) / $gridSize) * $gridSize;" ^
    "    $script:dirX = $gridSize;" ^
    "    $script:dirY = 0;" ^
    "    $script:snakeLength = 4;" ^
    "    $script:score = 0;" ^
    "    $history = New-Object System.Collections.Generic.List[System.Drawing.Point];" ^
    "    $script:apples = New-Object System.Collections.Generic.List[System.Drawing.Point];" ^
    "    $script:inputQueue = New-Object System.Collections.Generic.Queue[System.Drawing.Point];" ^
    "    $rand = New-Object System.Random;" ^
    "    $totalCols = ($maxX - $minX) / $gridSize;" ^
    "    $totalRows = ($maxY - $minY) / $gridSize;" ^
    "    $totalSlots = $totalCols * $totalRows;" ^
    "    $targetApplesCount = [int]($totalSlots * (%apple_percentage% / 100));" ^
    "    if ($targetApplesCount -lt 2) { $targetApplesCount = 2 };" ^
    "    function SpawnSingleApple {" ^
    "        while ($true) {" ^
    "            $ax = $rand.Next([int]($minX / $gridSize), [int]($maxX / $gridSize)) * $gridSize;" ^
    "            $ay = $rand.Next([int]($minY / $gridSize), [int]($maxY / $gridSize)) * $gridSize;" ^
    "            $valid = $false;" ^
    "            foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {" ^
    "                if ($scr.Bounds.Contains($ax, $ay)) { $valid = $true; break }" ^
    "            }" ^
    "            if ($valid -and -not $script:apples.Contains((New-Object System.Drawing.Point($ax, $ay)))) {" ^
    "                $script:apples.Add((New-Object System.Drawing.Point($ax, $ay)));" ^
    "                break;" ^
    "            }" ^
    "        }" ^
    "    }" ^
    "    for ($i = 0; $i -lt $targetApplesCount; $i++) { SpawnSingleApple }" ^
    "    $appleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Crimson);" ^
    "    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White);" ^
    "    $bgTextBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black);" ^
    "    $font = New-Object System.Drawing.Font('Arial', 24, [System.Drawing.FontStyle]::Bold);" ^
    "    $form.add_KeyDown({" ^
    "        param($sender, $e);" ^
    "        $key = $e.KeyCode;" ^
    "        if ($key -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }" ^
    "        $lastDirX = if ($script:inputQueue.Count -gt 0) { $script:inputQueue.ToArray()[-1].X } else { $script:dirX }" ^
    "        $lastDirY = if ($script:inputQueue.Count -gt 0) { $script:inputQueue.ToArray()[-1].Y } else { $script:dirY }" ^
    "        if ($script:inputQueue.Count -lt 3) {" ^
    "            if (($key -eq [System.Windows.Forms.Keys]::Up -or $key -eq [System.Windows.Forms.Keys]::W) -and $lastDirY -eq 0) {" ^
    "                $script:inputQueue.Enqueue((New-Object System.Drawing.Point(0, -$gridSize)))" ^
    "            }" ^
    "            elseif (($key -eq [System.Windows.Forms.Keys]::Down -or $key -eq [System.Windows.Forms.Keys]::S) -and $lastDirY -eq 0) {" ^
    "                $script:inputQueue.Enqueue((New-Object System.Drawing.Point(0, $gridSize)))" ^
    "            }" ^
    "            elseif (($key -eq [System.Windows.Forms.Keys]::Left -or $key -eq [System.Windows.Forms.Keys]::A) -and $lastDirX -eq 0) {" ^
    "                $script:inputQueue.Enqueue((New-Object System.Drawing.Point(-$gridSize, 0)))" ^
    "            }" ^
    "            elseif (($key -eq [System.Windows.Forms.Keys]::Right -or $key -eq [System.Windows.Forms.Keys]::D) -and $script:lastDirX -eq 0) {" ^
    "                $script:inputQueue.Enqueue((New-Object System.Drawing.Point($gridSize, 0)))" ^
    "            }" ^
    "        }" ^
    "    });" ^
    "    $timer = New-Object System.Windows.Forms.Timer;" ^
    "    $timer.Interval = %interval%;" ^
    "    $timer.add_Tick({" ^
    "        if ($script:inputQueue.Count -gt 0) {" ^
    "            $nextDir = $script:inputQueue.Dequeue();" ^
    "            $script:dirX = $nextDir.X;" ^
    "            $script:dirY = $nextDir.Y;" ^
    "            $script:lastDirX = $nextDir.X;" ^
    "            $script:lastDirY = $nextDir.Y;" ^
    "        }" ^
    "        $script:snakeX += $script:dirX;" ^
    "        $script:snakeY += $script:dirY;" ^
    "        if ($script:snakeX -lt $minX) { $script:snakeX = $maxX - $gridSize } elseif ($script:snakeX -ge $maxX) { $script:snakeX = $minX }" ^
    "        if ($script:snakeY -lt $minY) { $script:snakeY = $maxY - $gridSize } elseif ($script:snakeY -ge $maxY) { $script:snakeY = $minY }" ^
    "        $headPoint = New-Object System.Drawing.Point($script:snakeX, $script:snakeY);" ^
    "        $history.Add($headPoint);" ^
    "        if ($history.Count -gt $script:snakeLength) { $history.RemoveAt(0) }" ^
    "        $appleIndex = $script:apples.IndexOf($headPoint);" ^
    "        if ($appleIndex -ne -1) {" ^
    "            $script:score += 1;" ^
    "            $script:snakeLength += 2;" ^
    "            $script:apples.RemoveAt($appleIndex);" ^
    "            SpawnSingleApple;" ^
    "        }" ^
    "        $form.Invalidate();" ^
    "    });" ^
    "    $form.add_Paint({" ^
    "        param($sender, $e);" ^
    "        $g = $e.Graphics;" ^
    "        $g.TranslateTransform(-$vs.Left, -$vs.Top);" ^
    "        foreach ($apple in $script:apples) {" ^
    "            $g.FillEllipse($appleBrush, $apple.X + 4, $apple.Y + 4, $gridSize - 8, $gridSize - 8);" ^
    "        }" ^
    "        $count = $history.Count;" ^
    "        for ($i = 0; $i -lt $count; $i++) {" ^
    "            $cell = $history[$i];" ^
    "            $ratio = $i / [math]::Max(1, ($count - 1));" ^
    "            $r = [int](0 + (50 - 0) * (1 - $ratio));" ^
    "            $gVal = [int](255 + (80 - 255) * (1 - $ratio));" ^
    "            $b = [int](0 + (0 - 0) * (1 - $ratio));" ^
    "            $dynamicColor = [System.Drawing.Color]::FromArgb(255, $r, $gVal, $b);" ^
    "            $brush = New-Object System.Drawing.SolidBrush($dynamicColor);" ^
    "            $g.FillRectangle($brush, $cell.X + 2, $cell.Y + 2, $gridSize - 4, $gridSize - 4);" ^
    "            $brush.Dispose();" ^
    "        }" ^
    "        $scoreX = $primBounds.Right - 220;" ^
    "        $scoreY = $primBounds.Top + 40;" ^
    "        $g.FillRectangle($bgTextBrush, $scoreX, $scoreY, 180, 50);" ^
    "        $g.DrawString(\"SCORE: $script:score\", $font, $textBrush, ($scoreX + 10), ($scoreY + 5));" ^
    "        $g.ResetTransform();" ^
    "    });" ^
    "    $timer.Start();" ^
    "    [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
