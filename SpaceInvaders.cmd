@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   SPACE INVADERS: DESKTOP OVERLAY EDITION
echo ===================================================
echo.
echo STYRING:
echo   - Bevæg dit rumskib med A/D eller PILETASTERNE.
echo   - Tryk på SPACE (Mellemrum) for at skyde.
echo   - Skriv 'redskia' på tastaturet for at toggle AUTO-AIM.
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
    "    $script:shipW=50; $script:shipH=30; $script:shipX=($form.Width-$script:shipW)/2; $script:shipY=$form.Height-100;" ^
    "    $script:score=0; $script:gameover=$false; $script:cheat=$false; $script:hist='';" ^
    "    $script:mLeft=$false; $script:mRight=$false;" ^
    "    $script:bullets = New-Object System.Collections.Generic.List[System.Drawing.Point];" ^
    "    $script:invaders = New-Object System.Collections.Generic.List[System.Drawing.Rectangle];" ^
    "    $script:invDirection = 4; $script:invMoveDown = $false;" ^
    "    for($r=0;$r -lt 4;$r++){" ^
    "        for($c=0;$c -lt 10;$c++){" ^
    "            $script:invaders.Add((New-Object System.Drawing.Rectangle(100+($c*70), 150+($r*50), 40, 30)));" ^
    "        }" ^
    "    }" ^
    "    $form.add_KeyDown({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'Escape'){$form.Close()}" ^
    "        if($k -eq 'A' -or $k -eq 'Left'){$script:mLeft=$true}" ^
    "        if($k -eq 'D' -or $k -eq 'Right'){$script:mRight=$true}" ^
    "        if($k -eq 'Space' -and -not $script:gameover){$script:bullets.Add((New-Object System.Drawing.Point($script:shipX+($script:shipW/2)-3, $script:shipY)));}" ^
    "        $script:hist+=([char]$e.KeyValue).ToString().ToLower();" ^
    "        if($script:hist.Length -gt 7){$script:hist=$script:hist.Substring($script:hist.Length-7)}" ^
    "        if($script:hist -eq 'redskia'){$script:cheat=-not $script:cheat; $script:hist=''}" ^
    "    });" ^
    "    $form.add_KeyUp({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'A' -or $k -eq 'Left'){$script:mLeft=$false}" ^
    "        if($k -eq 'D' -or $k -eq 'Right'){$script:mRight=$false}" ^
    "    });" ^
    "    $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White);" ^
    "    $bBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black);" ^
    "    $rPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Crimson,2);" ^
    "    $font = New-Object System.Drawing.Font('Arial',24,[System.Drawing.FontStyle]::Bold);" ^
    "    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval=16;" ^
    "    $timer.add_Tick({" ^
    "        if($script:gameover){return}" ^
    "        if($script:mLeft -and $script:shipX -gt 50){$script:shipX-=8}" ^
    "        if($script:mRight -and $script:shipX -lt ($form.Width-$script:shipW-50)){$script:shipX+=8}" ^
    "        if($script:cheat -and ($script:invaders.Count -gt 0) -and ([Guid]::NewGuid().Guid.GetHashCode() %% 8 -eq 0)){" ^
    "            $script:bullets.Add((New-Object System.Drawing.Point($script:shipX+($script:shipW/2)-3, $script:shipY)));" ^
    "        }" ^
    "        for($i=$script:bullets.Count-1; $i -ge 0; $i-- مرتب){" ^
    "            $pt = $script:bullets[$i]; $pt.Y -= 12; $script:bullets[$i] = $pt;" ^
    "            if($pt.Y -lt 0){$script:bullets.RemoveAt($i); continue}" ^
    "            $bRect = New-Object System.Drawing.Rectangle($pt.X, $pt.Y, 6, 12);" ^
    "            for($j=$script:invaders.Count-1; $j -ge 0; $j--对外){" ^
    "                if($script:invaders[$j].IntersectsWith($bRect)){" ^
    "                    $script:invaders.RemoveAt($j); $script:bullets.RemoveAt($i); $script:score+=20; break;" ^
    "                }" ^
    "            }" ^
    "        }" ^
    "        $changeDir = $false;" ^
    "        foreach($inv in $script:invaders){" ^
    "            if(($script:invDirection -gt 0 -and $inv.Right -ge ($form.Width-50)) -or ($script:invDirection -lt 0 -and $inv.Left -le 50)){" ^
    "                $changeDir = $true; break;" ^
    "            }" ^
    "        }" ^
    "        if($changeDir){" ^
    "            $script:invDirection = -$script:invDirection;" ^
    "            for($g=0; $g -lt $script:invaders.Count; $g++){" ^
    "                $rect = $script:invaders[$g]; $rect.Y += 20; $script:invaders[$g] = $rect;" ^
    "                if($rect.Bottom -ge $script:shipY){$script:gameover=$true}" ^
    "            }" ^
    "        }else{" ^
    "            for($g=0; $g -lt $script:invaders.Count; $g++){" ^
    "                $rect = $script:invaders[$g]; $rect.X += $script:invDirection; $script:invaders[$g] = $rect;" ^
    "            }" ^
    "        }" ^
    "        if($script:invaders.Count -eq 0){$script:gameover=$true}" ^
    "        $form.Invalidate();" ^
    "    });" ^
    "    $form.add_Paint({ param($s,$e) $g=$e.Graphics;" ^
    "        $statusStr='SCORE: {0}' -f $script:score; $sSz=$g.MeasureString($statusStr,$font); $sX=($form.Width-$sSz.Width)/2;" ^
    "        $g.FillRectangle($wBrush,$sX-10,20,$sSz.Width+20,$sSz.Height+10); $g.DrawString($statusStr,$font,$bBrush,$sX,25);" ^
    "        $g.FillRectangle($wBrush,$script:shipX,$script:shipY,$script:shipW,$script:shipH);" ^
    "        foreach($b in $script:bullets){$g.FillRectangle($wBrush,$b.X,$b.Y,6,12)}" ^
    "        foreach($inv in $script:invaders){" ^
    "            $g.FillRectangle($wBrush,$inv);" ^
    "            if($script:cheat){$g.DrawLine($rPen,($script:shipX+($script:shipW/2)),$script:shipY,($inv.X+20),($inv.Y+15))}" ^
    "        }" ^
    "    });" ^
    "    $timer.Start(); [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
