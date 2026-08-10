@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   PING PONG: SECRET CHEAT EDITION (REFLECT FIX)
echo ===================================================
echo.
echo VÆLG SVÆRHEDSGRAD:
echo   - 1: Nem (Computeren er langsom)
echo   - 2: Normal (Anbefalet)
echo   - 3: Umulig (Computeren misser næsten aldrig)
echo.
set /p sværhed="Indtast dit valg (1, 2 eller 3): "

set ai_speed=8
if "%sværhed%"=="1" set ai_speed=5
if "%sværhed%"=="2" set ai_speed=10
if "%sværhed%"=="3" set ai_speed=18

echo.
echo STYRING:
echo   - Bevæg dit bat op/ned med W/S eller PILETASTERNE.
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
    "    $script:padW=20; $script:padH=120; $script:p1X=50; $script:p1Y=($form.Height-$script:padH)/2;" ^
    "    $script:p2X=$form.Width-50-$script:padW; $script:p2Y=$script:p1Y;" ^
    "    $script:ballX=$form.Width/2; $script:ballY=$form.Height/2; $script:ballS=16; $script:ballSx=8; $script:ballSy=6;" ^
    "    $script:aiSpeed=%ai_speed%; $script:p1Score=0; $script:p2Score=0; $script:mUp=$false; $script:mDown=$false;" ^
    "    $script:cheat=$false; $script:hist='';" ^
    "    $form.add_KeyDown({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'Escape'){$form.Close()}" ^
    "        if($k -eq 'W' -or $k -eq 'Up'){$script:mUp=$true}" ^
    "        if($k -eq 'S' -or $k -eq 'Down'){$script:mDown=$true}" ^
    "        $script:hist+=([char]$e.KeyValue).ToString().ToLower();" ^
    "        if($script:hist.Length -gt 7){$script:hist=$script:hist.Substring($script:hist.Length-7)}" ^
    "        if($script:hist -eq 'redskia'){$script:cheat=-not $script:cheat; $script:hist=''}" ^
    "    });" ^
    "    $form.add_KeyUp({ param($s,$e) $k=$e.KeyCode;" ^
    "        if($k -eq 'W' -or $k -eq 'Up'){$script:mUp=$false}" ^
    "        if($k -eq 'S' -or $k -eq 'Down'){$script:mDown=$false}" ^
    "    });" ^
    "    $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White);" ^
    "    $bBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black);" ^
    "    $rPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Crimson,2); $rPen.DashStyle=2;" ^
    "    $font = New-Object System.Drawing.Font('Arial',36,[System.Drawing.FontStyle]::Bold);" ^
    "    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval=16;" ^
    "    $timer.add_Tick({" ^
    "        if($script:mUp -and $script:p1Y -gt 0){$script:p1Y-=12}" ^
    "        if($script:mDown -and $script:p1Y -lt ($form.Height-$script:padH)){$script:p1Y+=12}" ^
    "        $bCy=$script:ballY+($script:ballS/2); $aCy=$script:p2Y+($script:padH/2);" ^
    "        if($bCy -lt $aCy -and $script:p2Y -gt 0){$script:p2Y-=[math]::Min($script:aiSpeed,($aCy-$bCy))}" ^
    "        if($bCy -gt $aCy -and $script:p2Y -lt ($form.Height-$script:padH)){$script:p2Y+=[math]::Min($script:aiSpeed,($bCy-$aCy))}" ^
    "        $script:ballX+=$script:ballSx; $script:ballY+=$script:ballSy;" ^
    "        if($script:ballY -le 0 -or $script:ballY -ge ($form.Height-$script:ballS)){$script:ballSy=-$script:ballSy}" ^
    "        if($script:ballX -le ($script:p1X+$script:padW) -and $script:ballX -ge $script:p1X){" ^
    "            if(($script:ballY+$script:ballS) -ge $script:p1Y -and $script:ballY -le ($script:p1Y+$script:padH)){" ^
    "                $script:ballSx=[math]::Abs($script:ballSx)+0.5;" ^
    "                $script:ballSy+=($script:ballY+($script:ballS/2)-($script:p1Y+($script:padH/2)))*0.1;" ^
    "            }" ^
    "        }" ^
    "        if(($script:ballX+$script:ballS) -ge $script:p2X -and ($script:ballX+$script:ballS) -le ($script:p2X+$script:padW)){" ^
    "            if(($script:ballY+$script:ballS) -ge $script:p2Y -and $script:ballY -le ($script:p2Y+$script:padH)){" ^
    "                $script:ballSx=-([math]::Abs($script:ballSx)+0.5);" ^
    "                $script:ballSy+=($script:ballY+($script:ballS/2)-($script:p2Y+($script:padH/2)))*0.1;" ^
    "            }" ^
    "        }" ^
    "        if($script:ballX -lt 0){$script:p2Score++; $script:ballX=$form.Width/2; $script:ballY=$form.Height/2; $script:ballSx=8}" ^
    "        if($script:ballX -gt $form.Width){$script:p1Score++; $script:ballX=$form.Width/2; $script:ballY=$form.Height/2; $script:ballSx=-8}" ^
    "        $form.Invalidate();" ^
    "    });" ^
    "    $form.add_Paint({ param($s,$e) $g=$e.Graphics;" ^
    "        if($script:cheat){" ^
    "            $sX=$script:ballX+($script:ballS/2); $sY=$script:ballY+($script:ballS/2); $sVx=$script:ballSx; $sVy=$script:ballSy;" ^
    "            for($b=0;$b -lt 4;$b++){" ^
    "                $nX=if($sVx -gt 0){$form.Width}else{0};" ^
    "                $tW=if($sVy -lt 0){(0-$sY)/$sVy}else{($form.Height-$sY)/$sVy}; $tP=($nX-$sX)/$sVx;" ^
    "                if($tW -lt $tP -and $tW -gt 0){" ^
    "                    $eX=$sX+($sVx*$tW); $eY=if($sVy -lt 0){0}else{$form.Height};" ^
    "                    $g.DrawLine($rPen,$sX,$sY,$eX,$eY); $sX=$eX; $sY=$eY; $sVy=-$sVy;" ^
    "                }else{" ^
    "                    $g.DrawLine($rPen,$sX,$sY,$nX,$sY+($sVy*$tP)); break;" ^
    "                }" ^
    "            }" ^
    "        }" ^
    "        $sStr='{0}   :   {1}' -f $script:p1Score,$script:p2Score; $sSz=$g.MeasureString($sStr,$font); $sX=($form.Width-$sSz.Width)/2;" ^
    "        $g.FillRectangle($wBrush,$sX-10,20,$sSz.Width+20,$sSz.Height+10); $g.DrawString($sStr,$font,$bBrush,$sX,25);" ^
    "        $g.FillRectangle($wBrush,$script:p1X,$script:p1Y,$script:padW,$script:padH);" ^
    "        $g.FillRectangle($wBrush,$script:p2X,$script:p2Y,$script:padW,$script:padH);" ^
    "        $g.FillRectangle($wBrush,$script:ballX,$script:ballY,$script:ballS,$script:ballS);" ^
    "    });" ^
    "    $timer.Start(); [System.Windows.Forms.Application]::Run($form);" ^
    "};" ^
    "Invoke-Command -ScriptBlock $psCode"
