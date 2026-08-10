@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   BRICK BREAKER: SECRET CHEAT EDITION (2 BOUNCES)
echo ===================================================
echo.
echo STYRING:
echo   - Bevæg dit bat med A/D eller PILETASTERNE.
echo   - Tryk på SPACE (Mellemrum) for at skyde bolden afsted.
echo   - Skriv 'redskia' på tastaturet for at toggle laseren.
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
    "    $script:padW = 160; $script:padH = 20;" ^
    "    $script:padX = ($form.Width - $script:padW) / 2;" ^
    "    $script:padY = $form.Height - 80;" ^
    "    $script:ballS = 16; $script:ballX = $form.Width / 2; $script:ballY = $script:padY - 30;" ^
    "    $script:ballSx = 0; $script:ballSy = 0; $script:ballInPlay = $false;" ^
    "    $script:score = 0; $script:lives = 3;" ^
    "    $script:mLeft = $false; $script:mRight = $false;" ^
    "    $script:cheat = $false; $script:hist = '';" ^
    "    $script:bricks = New-Object System.Collections.Generic.List[System.Drawing.Rectangle];" ^
    "    $rows = 5; $cols = 12; $bW = ($form.Width - 140) / $cols; $bH = 30;" ^
    "    for($r=0; $r -lt $rows; $r++) {" ^
    "        for($c=0; $c -lt $cols; $c++) {" ^
    "            $bx = 70 + ($c * $bW) + ($c * 4);" ^
    "            $by = 120 + ($r * $bH) + ($r * 4);" ^
    "            $script:bricks.Add((New-Object System.Drawing.Rectangle($bx, $by, $bW, $bH)));" ^
    "        }" ^
    "    }" ^
    "    $form.add_KeyDown({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'Escape'){$form.Close()}" ^
    "        if($k -eq 'A' -or $k -eq 'Left'){$script:mLeft=$true}" ^
    "        if($k -eq 'D' -or $k -eq 'Right'){$script:mRight=$true}" ^
    "        if($k -eq 'Space' -and -not $script:ballInPlay){$script:ballSx=7; $script:ballSy=-9; $script:ballInPlay=$true}" ^
    "        $script:hist+=([char]$e.KeyValue).ToString().ToLower();" ^
    "        if($script:hist.Length -gt 7){$script:hist=$script:hist.Substring($script:hist.Length-7)}" ^
    "        if($script:hist -eq 'redskia'){$script:cheat=-not $script:cheat; $script:hist=''}" ^
    "    });" ^
    "    $form.add_KeyUp({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'A' -or $k -eq 'Left'){$script:mLeft=$false}" ^
    "        if($k -eq 'D' -or $k -eq 'Right'){$script:mRight=$false}" ^
    "    });" ^
    "    function ResetBall {" ^
    "        $script:ballInPlay = $false; $script:ballSx = 0; $script:ballSy = 0;" ^
    "        $script:ballX = $script:padX + ($script:padW / 2) - ($script:ballS / 2); $script:ballY = $script:padY - 25;" ^
    "    }" ^
    "    $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White);" ^
    "    $bBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black);" ^
    "    $rPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Crimson,2); $rPen.DashStyle=2;" ^
    "    $font = New-Object System.Drawing.Font('Arial',24,[System.Drawing.FontStyle]::Bold);" ^
    "    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval=16;" ^
    "    $timer.add_Tick({" ^
    "        if($script:mLeft -and $script:padX -gt 40){$script:padX-=14}" ^
    "        if($script:mRight -and $script:padX -lt ($form.Width-$script:padW-40)){$script:padX+=14}" ^
    "        if(-not $script:ballInPlay){$script:ballX = $script:padX + ($script:padW / 2) - ($script:ballS / 2); $script:ballY = $script:padY - 25}" ^
    "        else {" ^
    "            $script:ballX += $script:ballSx; $script:ballY += $script:ballSy;" ^
    "            if($script:ballX -le 0 -or $script:ballX -ge ($form.Width-$script:ballS)){$script:ballSx=-$script:ballSx}" ^
    "            if($script:ballY -le 0){$script:ballSy=-$script:ballSy}" ^
    "            if(($script:ballY+$script:ballS) -ge $script:padY -and $script:ballY -le ($script:padY+$script:padH)){" ^
    "                if(($script:ballX+$script:ballS) -ge $script:padX -and $script:ballX -le ($script:padX+$script:padW)){" ^
    "                    $script:ballSy = -[math]::Abs($script:ballSy);" ^
    "                    $hitPoint = ($script:ballX + ($script:ballS/2)) - ($script:padX + ($script:padW/2));" ^
    "                    $script:ballSx = ($hitPoint / ($script:padW/2)) * 9;" ^
    "                }" ^
    "            }" ^
    "            $ballRect = New-Object System.Drawing.Rectangle([int]$script:ballX, [int]$script:ballY, $script:ballS, $script:ballS);" ^
    "            for($i=$script:bricks.Count-1; $i -ge 0; $i--) {" ^
    "                if($script:bricks[$i].IntersectsWith($ballRect)) {" ^
    "                    $script:ballSy = -$script:ballSy;" ^
    "                    $script:bricks.RemoveAt($i);" ^
    "                    $script:score += 10;" ^
    "                    break;" ^
    "                }" ^
    "            }" ^
    "            if($script:ballY -gt $form.Height) {" ^
    "                $script:lives--;" ^
    "                if($script:lives -le 0){$form.Close()} else {ResetBall}" ^
    "                $form.Invalidate(); return;" ^
    "            }" ^
    "        }" ^
    "        $form.Invalidate();" ^
    "    });" ^
    "    $form.add_Paint({ param($s,$e) $g=$e.Graphics;" ^
    "        if($script:cheat -and $script:ballInPlay){" ^
    "            $sX=$script:ballX+($script:ballS/2); $sY=$script:ballY+($script:ballS/2); $sVx=$script:ballSx; $sVy=$script:ballSy;" ^
    "            for($b=0; $b -lt 2; $b++){" ^
    "                $nX=if($sVx -gt 0){$form.Width}else{0};" ^
    "                $tW=if($sVy -lt 0){(0-$sY)/$sVy}else{($form.Height-$sY)/$sVy};" ^
    "                $tP=if($sVx -ne 0){($nX-$sX)/$sVx}else{99999};" ^
    "                $t=if($tW -lt $tP -and $tW -gt 0){$tW}else{$tP};" ^
    "                if($t -gt 0 -and $t -lt 99999){" ^
    "                    $eX=$sX+($sVx*$t); $eY=$sY+($sVy*$t);" ^
    "                    $g.DrawLine($rPen,$sX,$sY,$eX,$eY); $sX=$eX; $sY=$eY;" ^
    "                    if($t -eq $tW){$sVy=-$sVy}else{$sVx=-$sVx};" ^
    "                }else{break}" ^
    "            }" ^
    "        }" ^
    "        $statusStr='SCORE: {0}   |   LIVES: {1}' -f $script:score,$script:lives; $sSz=$g.MeasureString($statusStr,$font); $sX=($form.Width-$sSz.Width)/2;" ^
    "        $g.FillRectangle($wBrush,$sX-10,20,$sSz.Width+20,$sSz.Height+10); $g.DrawString($statusStr,$font,$bBrush,$sX,25);" ^
    "        $g.FillRectangle($wBrush,$script:padX,$script:padY,$script:padW,$script:padH);" ^
    "        $g.FillRectangle($wBrush,$script:ballX,$script:ballY,$script:ballS,$script:ballS);" ^
    "        foreach($b in $script:bricks){$g.FillRectangle($wBrush,$b)}" ^
    "    });" ^
    "    $timer.Start(); [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
