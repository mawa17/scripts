@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   FLAPPY BIRD: DESKTOP OVERLAY EDITION
echo ===================================================
echo.
echo STYRING:
echo   - Tryk på SPACE (Mellemrum) eller PIL OP for at flyve op.
echo   - Skriv 'redskia' på tastaturet for at slå GOD MODE + KURVE til.
echo   - Tryk på ESC for at lukke spillet.
echo.
echo Starter spillet... Hold dette vindue åbent.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$psCode = {" ^
    "    Add-Type -AssemblyName System.Windows.Forms,System.Drawing;" ^
    "    $DPIAPI = 'using System; using System.Runtime.InteropServices; public class Win32DPI { [DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware(); }';" ^
    "    Add-Type -TypeDefinition $DPIAPI; [Win32DPI]::SetProcessDPIAware();" ^
    "    $form = New-Object System.Windows.Forms.Form; $form.FormBorderStyle = 0;" ^
    "    $pBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds;" ^
    "    $form.Left = $pBounds.Left; $form.Top = $pBounds.Top; $form.Width = $pBounds.Width; $form.Height = $pBounds.Height;" ^
    "    $form.StartPosition = 0; $form.BackColor = 'Lime'; $form.TransparencyKey = 'Lime'; $form.TopMost = $true;" ^
    "    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic;" ^
    "    $form.GetType().GetProperty('DoubleBuffered', $flags).SetValue($form, $true, $null);" ^
    "    $script:birdSize=24; $script:birdX=150; $script:birdY=$form.Height/2; $script:velocity=0; $script:gravity=0.5;" ^
    "    $script:score=0; $script:gameover=$false; $script:cheat=$false; $script:hist='';" ^
    "    $script:pipes = New-Object System.Collections.Generic.List[System.Drawing.Rectangle];" ^
    "    $rand = New-Object System.Random; $pipeGap = 200; $pipeW = 70;" ^
    "    function SpawnPipe { param($startX) " ^
    "        $h = $rand.Next(100, $form.Height - 400);" ^
    "        $script:pipes.Add((New-Object System.Drawing.Rectangle($startX, 0, $pipeW, $h)));" ^
    "        $script:pipes.Add((New-Object System.Drawing.Rectangle($startX, $h+$pipeGap, $pipeW, $form.Height-($h+$pipeGap))));" ^
    "    }" ^
    "    SpawnPipe($form.Width); SpawnPipe($form.Width + 400); SpawnPipe($form.Width + 800);" ^
    "    $form.add_KeyDown({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'Escape'){$form.Close()}" ^
    "        if(($k -eq 'Space' -or $k -eq 'Up' -or $k -eq 'W') -and -not $script:gameover){$script:velocity = -8.5}" ^
    "        $script:hist+=([char]$e.KeyValue).ToString().ToLower();" ^
    "        if($script:hist.Length -gt 7){$script:hist=$script:hist.Substring($script:hist.Length-7)}" ^
    "        if($script:hist -eq 'redskia'){$script:cheat=-not $script:cheat; $script:hist=''}" ^
    "    });" ^
    "    $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White);" ^
    "    $bBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black);" ^
    "    $rPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Crimson,2); $rPen.DashStyle=2;" ^
    "    $font = New-Object System.Drawing.Font('Arial',24,[System.Drawing.FontStyle]::Bold);" ^
    "    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval=16;" ^
    "    $timer.add_Tick({" ^
    "        if($script:gameover){return}" ^
    "        $script:velocity += $script:gravity;" ^
    "        $script:birdY += $script:velocity;" ^
    "        if($script:birdY -le 0){$script:birdY=0; $script:velocity=0}" ^
    "        if($script:birdY -ge ($form.Height-$script:birdSize)){$script:gameover=$true}" ^
    "        $bRect = New-Object System.Drawing.Rectangle($script:birdX, [int]$script:birdY, $script:birdSize, $script:birdSize);" ^
    "        for($i=$script:pipes.Count-1; $i -ge 0; $i-- مرتب){" ^
    "            $rect = $script:pipes[$i]; $rect.X -= 5; $script:pipes[$i] = $rect;" ^
    "            if($rect.Right -lt 0){" ^
    "                $script:pipes.RemoveAt($i);" ^
    "                if($i %% 2 -eq 0){$script:score++; SpawnPipe($form.Width)}" ^
    "                continue;" ^
    "            }" ^
    "            if(-not $script:cheat -and $rect.IntersectsWith($bRect)){$script:gameover=$true}" ^
    "        }" ^
    "        $form.Invalidate();" ^
    "    });" ^
    "    $form.add_Paint({ param($s,$e) $g=$e.Graphics;" ^
    "        if($script:cheat){" ^
    "            $simY = $script:birdY; $simV = $script:velocity;" ^
    "            for($t=0;$t -lt 150;$t+=5){" ^
    "                $nextV = $simV + ($script:gravity * 5); $nextY = $simY + $simV;" ^
    "                $g.DrawLine($rPen, ($script:birdX+$t), $simY, ($script:birdX+$t+5), $nextY);" ^
    "                $simY = $nextY; $simV = $nextV;" ^
    "            }" ^
    "        }" ^
    "        $statusStr='SCORE: {0}' -f $script:score; $sSz=$g.MeasureString($statusStr,$font); $sX=($form.Width-$sSz.Width)/2;" ^
    "        $g.FillRectangle($wBrush,$sX-10,20,$sSz.Width+20,$sSz.Height+10); $g.DrawString($statusStr,$font,$bBrush,$sX,25);" ^
    "        $g.FillRectangle($wBrush,$script:birdX,$script:birdY,$script:birdSize,$script:birdSize);" ^
    "        foreach($p in $script:pipes){$g.FillRectangle($wBrush,$p)}" ^
    "    });" ^
    "    $timer.Start(); [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
