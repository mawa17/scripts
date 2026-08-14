@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   RAINBOW RAYS PARTY (INGEN ADMIN / MULTI-SCREEN)
echo ===================================================
echo.
echo [INFO] Programmet åbner nu en gennemsigtig skærm.
echo.
echo [BETJENING]
echo * HOLD VENSTRE MUSEKNAP NEDE for at skyde med regnbuestråler!
echo * Tryk på ESC for at LUKKE spillet og gøre alt normalt igen.
echo.
echo Starter grafik... Vent venligst.

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
    "    $pb = New-Object System.Windows.Forms.PictureBox;" ^
    "    $pb.Dock = [System.Windows.Forms.DockStyle]::Fill;" ^
    "    $pb.BackColor = [System.Drawing.Color]::Lime;" ^
    "    $form.Controls.Add($pb);" ^
    "    $script:particles = New-Object System.Collections.Generic.List[PSCustomObject];" ^
    "    $script:isMouseDown = $false;" ^
    "    $script:rand = New-Object System.Random;" ^
    "    $pb.add_MouseDown({ param($s,$e); if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:isMouseDown = $true } });" ^
    "    $pb.add_MouseUp({ param($s,$e); if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:isMouseDown = $false } });" ^
    "    $form.add_KeyDown({ param($s,$e); if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() } });" ^
    "    $mainTimer = New-Object System.Windows.Forms.Timer;" ^
    "    $mainTimer.Interval = 16;" ^
    "    $mainTimer.add_Tick({ " ^
    "        if ($script:isMouseDown) {" ^
    "            $mPos = [System.Windows.Forms.Cursor]::Position;" ^
    "            $localX = $mPos.X - $vs.Left;" ^
    "            $localY = $mPos.Y - $vs.Top;" ^
    "            for ($i=0; $i -lt 5; $i++) {" ^
    "                $angle = $script:rand.NextDouble() * [Math]::PI * 2;" ^
    "                $speed = $script:rand.Next(5, 15);" ^
    "                $color = [System.Drawing.Color]::FromArgb(255, $script:rand.Next(50,256), $script:rand.Next(50,256), $script:rand.Next(50,256));" ^
    "                $p = [PSCustomObject]@{ X=$localX; Y=$localY; VX=[Math]::Cos($angle)*$speed; VY=[Math]::Sin($angle)*$speed; Size=$script:rand.Next(10,25); Life=1.0; Color=$color };" ^
    "                $script:particles.Add($p);" ^
    "            }" ^
    "        }" ^
    "        $toRemove = New-Object System.Collections.Generic.List[PSCustomObject];" ^
    "        foreach ($p in $script:particles) {" ^
    "            $p.X += $p.VX;" ^
    "            $p.Y += $p.VY;" ^
    "            $p.Life -= 0.02;" ^
    "            if ($p.X -le 0 -or $p.X + $p.Size -ge $vs.Width) { $p.VX = -$p.VX; $p.X = [Math]::Max(0, [Math]::Min($p.X, $vs.Width - $p.Size)) };" ^
    "            if ($p.Y -le 0 -or $p.Y + $p.Size -ge $vs.Height) { $p.VY = -$p.VY; $p.Y = [Math]::Max(0, [Math]::Min($p.Y, $vs.Height - $p.Size)) };" ^
    "            if ($p.Life -le 0) { $toRemove.Add($p) };" ^
    "        }" ^
    "        foreach ($p in $toRemove) { [void]$script:particles.Remove($p) };" ^
    "        $pb.Invalidate();" ^
    "    });" ^
    "    $pb.add_Paint({ " ^
    "        param($s,$e);" ^
    "        $g = $e.Graphics;" ^
    "        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias;" ^
    "        foreach ($p in $script:particles) {" ^
    "            $alpha = [Math]::Max(0, [Math]::Min([int]($p.Life * 255), 255));" ^
    "            $brushColor = [System.Drawing.Color]::FromArgb($alpha, $p.Color.R, $p.Color.G, $p.Color.B);" ^
    "            $brush = New-Object System.Drawing.SolidBrush($brushColor);" ^
    "            $g.FillEllipse($brush, $p.X, $p.Y, $p.Size, $p.Size);" ^
    "            $brush.Dispose();" ^
    "        }" ^
    "    });" ^
    "    $form.add_Load({ $mainTimer.Start() });" ^
    "    [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
