@echo off
setlocal EnableExtensions
chcp 65001 >nul

rem ============================================================
rem 001 - CMD BOOTSTRAP
rem ============================================================

set "EMULATED_CMD=%~f0"
set "PSFILE=%TEMP%\EmulatedDesktop_%RANDOM%_%RANDOM%.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$a=Get-Content -LiteralPath $env:EMULATED_CMD;" ^
 "$i=[Array]::IndexOf($a,'#=== POWERSHELL START ===');" ^
 "if($i -lt 0){Write-Host 'ERROR: PowerShell marker not found';exit 1};" ^
 "$a[($i+1)..($a.Length-1)] | Set-Content -LiteralPath $env:PSFILE -Encoding UTF8"

if not exist "%PSFILE%" (
    echo.
    echo ERROR: Could not create PowerShell payload.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
set "EXITCODE=%ERRORLEVEL%"

del "%PSFILE%" >nul 2>&1

if not "%EXITCODE%"=="0" (
    echo.
    echo ============================================
    echo Emulated Desktop stopped with error %EXITCODE%
    echo ============================================
    pause
)

exit /b %EXITCODE%


#=== POWERSHELL START ===

# ============================================================
# 002 - ASSEMBLIES
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================
# 003 - SETTINGS
# ============================================================

$settingsDirectory = Join-Path $env:LOCALAPPDATA "EmulatedDesktop"
$settingsFile = Join-Path $settingsDirectory "settings.json"

if (-not (Test-Path -LiteralPath $settingsDirectory)) {
    New-Item -ItemType Directory -Path $settingsDirectory -Force |
        Out-Null
}

$defaultSettings = [ordered]@{
    BackgroundType  = "Color"
    BackgroundColor = "#0B0F14"
    ImagePath       = ""
    ImageMode       = "Fill"
    IconScale       = 72
    Positions       = @{}
}

$settings = [ordered]@{
    BackgroundType  = "Color"
    BackgroundColor = "#0B0F14"
    ImagePath       = ""
    ImageMode       = "Fill"
    IconScale       = 72
    Positions       = @{}
}

# ============================================================
# 004 - LOAD SETTINGS
# ============================================================

if (Test-Path -LiteralPath $settingsFile) {
    try {
        $loaded = Get-Content `
            -LiteralPath $settingsFile `
            -Raw `
            -ErrorAction Stop |
            ConvertFrom-Json

        if ($null -ne $loaded) {

            if ($null -ne $loaded.BackgroundType) {
                $settings.BackgroundType = [string]$loaded.BackgroundType
            }

            if ($null -ne $loaded.BackgroundColor) {
                $settings.BackgroundColor = [string]$loaded.BackgroundColor
            }

            if ($null -ne $loaded.ImagePath) {
                $settings.ImagePath = [string]$loaded.ImagePath
            }

            if ($null -ne $loaded.ImageMode) {
                $settings.ImageMode = [string]$loaded.ImageMode
            }

            if ($null -ne $loaded.IconScale) {
                try {
                    $settings.IconScale = [int]$loaded.IconScale
                }
                catch {
                    $settings.IconScale = 72
                }
            }

            if ($null -ne $loaded.Positions) {
                foreach ($p in $loaded.Positions.PSObject.Properties) {
                    try {
                        $settings.Positions[$p.Name] = @{
                            X = [int]$p.Value.X
                            Y = [int]$p.Value.Y
                        }
                    }
                    catch {
                    }
                }
            }
        }
    }
    catch {
        $settings.Positions = @{}
    }
}

# ============================================================
# 005 - NORMALIZE SETTINGS
# ============================================================

$settings.IconScale = [Math]::Max(
    48,
    [Math]::Min(160, [int]$settings.IconScale)
)

if ([string]::IsNullOrWhiteSpace($settings.BackgroundColor)) {
    $settings.BackgroundColor = "#0B0F14"
}

if ([string]::IsNullOrWhiteSpace($settings.BackgroundType)) {
    $settings.BackgroundType = "Color"
}

if ([string]::IsNullOrWhiteSpace($settings.ImageMode)) {
    $settings.ImageMode = "Fill"
}

# ============================================================
# 006 - GLOBAL STATE
# ============================================================

$script:forms = @()
$script:primaryForm = $null
$script:settingsForm = $null

$script:backgroundImage = $null

$script:contextMenu = $null
$script:itemContextMenu = $null

$script:desktopPanels = @()
$script:desktopControls = @()
$script:iconBitmaps = @()

$script:dragPanel = $null
$script:dragOffset = $null
$script:isDragging = $false

# FIX: real selection state
$script:selectedPath = $null

$script:refreshing = $false

# ============================================================
# 007 - COLORS
# ============================================================

$script:Colors = @{
    Background  = [System.Drawing.Color]::FromArgb(11,15,20)
    TopBar      = [System.Drawing.Color]::FromArgb(18,23,29)

    Panel       = [System.Drawing.Color]::FromArgb(28,34,42)
    PanelHover  = [System.Drawing.Color]::FromArgb(47,61,77)

    Button      = [System.Drawing.Color]::FromArgb(42,49,59)
    ButtonHover = [System.Drawing.Color]::FromArgb(54,65,78)

    Text        = [System.Drawing.Color]::FromArgb(245,247,250)
    Muted       = [System.Drawing.Color]::FromArgb(135,145,158)

    Accent      = [System.Drawing.Color]::FromArgb(60,135,225)
    AccentHover = [System.Drawing.Color]::FromArgb(78,153,240)

    Danger      = [System.Drawing.Color]::FromArgb(65,40,44)
}

# ============================================================
# 008 - DESKTOP PATH
# ============================================================

$desktopPath = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::Desktop
)

if (
    [string]::IsNullOrWhiteSpace($desktopPath) -or
    -not (Test-Path -LiteralPath $desktopPath)
) {
    $desktopPath = Join-Path $env:USERPROFILE "Desktop"
}

# ============================================================
# 009 - DOUBLE BUFFER
# ============================================================

function Enable-DoubleBuffer {
    param(
        [System.Windows.Forms.Control]$Control
    )

    if ($null -eq $Control) {
        return
    }

    try {
        $property = $Control.GetType().GetProperty(
            "DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor
            [System.Reflection.BindingFlags]::NonPublic
        )

        if ($null -ne $property) {
            $property.SetValue($Control, $true, $null)
        }
    }
    catch {
    }
}

# ============================================================
# 010 - COLOR
# ============================================================

function Get-ColorFromHex {
    param(
        [string]$Hex
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Hex)) {
            return [System.Drawing.Color]::FromArgb(11,15,20)
        }

        return [System.Drawing.ColorTranslator]::FromHtml($Hex)
    }
    catch {
        return [System.Drawing.Color]::FromArgb(11,15,20)
    }
}

# ============================================================
# 011 - SAVE SETTINGS
# ============================================================

function Save-DesktopSettings {

    try {

        $object = [ordered]@{
            BackgroundType  = [string]$settings.BackgroundType
            BackgroundColor = [string]$settings.BackgroundColor
            ImagePath       = [string]$settings.ImagePath
            ImageMode       = [string]$settings.ImageMode
            IconScale       = [int]$settings.IconScale
            Positions       = $settings.Positions
        }

        $json = $object | ConvertTo-Json -Depth 10

        [System.IO.File]::WriteAllText(
            $settingsFile,
            $json,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    catch {
    }
}

# ============================================================
# 012 - BACKGROUND IMAGE
# ============================================================

function Load-BackgroundImage {

    if ($script:backgroundImage) {
        try {
            $script:backgroundImage.Dispose()
        }
        catch {
        }

        $script:backgroundImage = $null
    }

    if ($settings.BackgroundType -ne "Image") {
        return
    }

    if ([string]::IsNullOrWhiteSpace($settings.ImagePath)) {
        return
    }

    if (-not (Test-Path -LiteralPath $settings.ImagePath)) {
        return
    }

    try {

        $source = [System.Drawing.Image]::FromFile(
            $settings.ImagePath
        )

        $script:backgroundImage =
            New-Object System.Drawing.Bitmap($source)

        $source.Dispose()
    }
    catch {
        $script:backgroundImage = $null
    }
}

# ============================================================
# 013 - PAINT BACKGROUND
# ============================================================

function Paint-DesktopBackground {

    param(
        [System.Windows.Forms.PaintEventArgs]$Event
    )

    if ($null -eq $Event) {
        return
    }

    $g = $Event.Graphics

    $g.Clear(
        (Get-ColorFromHex $settings.BackgroundColor)
    )

    if (
        $settings.BackgroundType -ne "Image" -or
        $null -eq $script:backgroundImage
    ) {
        return
    }

    $image = $script:backgroundImage

    if ($image.Width -le 0 -or $image.Height -le 0) {
        return
    }

    $width = $Event.ClipRectangle.Width
    $height = $Event.ClipRectangle.Height

    try {

        $g.InterpolationMode =
            [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $g.PixelOffsetMode =
            [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $g.CompositingQuality =
            [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $mode = [string]$settings.ImageMode

        if ($mode -eq "Stretch") {

            $g.DrawImage(
                $image,
                (New-Object System.Drawing.Rectangle(
                    0,0,$width,$height
                ))
            )
        }
        elseif ($mode -eq "Center") {

            $x = [int](($width - $image.Width) / 2)
            $y = [int](($height - $image.Height) / 2)

            $g.DrawImage(
                $image,
                $x,
                $y,
                $image.Width,
                $image.Height
            )
        }
        elseif ($mode -eq "Tile") {

            $brush = New-Object System.Drawing.TextureBrush($image)

            try {
                $g.FillRectangle(
                    $brush,
                    0,
                    0,
                    $width,
                    $height
                )
            }
            finally {
                $brush.Dispose()
            }
        }
        else {

            if ($mode -eq "Fit") {
                $scale = [Math]::Min(
                    $width / [double]$image.Width,
                    $height / [double]$image.Height
                )
            }
            else {
                $scale = [Math]::Max(
                    $width / [double]$image.Width,
                    $height / [double]$image.Height
                )
            }

            $newWidth = [int]($image.Width * $scale)
            $newHeight = [int]($image.Height * $scale)

            $x = [int](($width - $newWidth) / 2)
            $y = [int](($height - $newHeight) / 2)

            $g.DrawImage(
                $image,
                (New-Object System.Drawing.Rectangle(
                    $x,
                    $y,
                    $newWidth,
                    $newHeight
                ))
            )
        }
    }
    catch {
    }
}

# ============================================================
# 014 - APPLY BACKGROUND
# ============================================================

function Apply-Background {

    param(
        [System.Windows.Forms.Form]$Form
    )

    if ($null -eq $Form) {
        return
    }

    try {

        $Form.BackColor =
            Get-ColorFromHex $settings.BackgroundColor

        $Form.Invalidate()
    }
    catch {
    }
}

# ============================================================
# 015 - WINDOWS ICON ENGINE
# ============================================================

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;

public static class WindowsJumboIcons
{
    public const int SHIL_JUMBO = 0x4;
    public const int ILD_TRANSPARENT = 0x00000001;
    public const int ILD_IMAGE = 0x00000020;

    public const uint SHGFI_SYSICONINDEX = 0x00004000;
    public const uint SHGFI_LARGEICON = 0x00000000;

    public const uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
    public const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct SHFILEINFO
    {
        public IntPtr hIcon;
        public int iIcon;
        public uint dwAttributes;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szDisplayName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
        public string szTypeName;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SHGetFileInfo(
        string pszPath,
        uint dwFileAttributes,
        out SHFILEINFO psfi,
        uint cbFileInfo,
        uint uFlags
    );

    [DllImport("shell32.dll", EntryPoint = "#727")]
    public static extern int SHGetImageList(
        int iImageList,
        ref Guid riid,
        ref IImageList ppv
    );

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

    [ComImport]
    [Guid("46EB5926-582E-4017-9FDF-E8998DAA0950")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IImageList
    {
        [PreserveSig] int Add(IntPtr hbmImage, IntPtr hbmMask, ref int pi);
        [PreserveSig] int ReplaceIcon(int i, IntPtr hicon, ref int pi);
        [PreserveSig] int SetOverlayImage(int iImage, int iOverlay);
        [PreserveSig] int Replace(int i, IntPtr hbmImage, IntPtr hbmMask);
        [PreserveSig] int AddMasked(IntPtr hbmImage, int crMask, ref int pi);
        [PreserveSig] int Draw(IntPtr pimldp);
        [PreserveSig] int Remove(int i);
        [PreserveSig] int GetIcon(int i, int flags, ref IntPtr picon);
        [PreserveSig] int GetImageInfo(int i, IntPtr pImageInfo);
        [PreserveSig] int Copy(int iDst, IImageList punkSrc, int iSrc, int uFlags);
        [PreserveSig] int Merge(int i1, IImageList punk2, int i2,
            int dx, int dy, ref Guid riid, ref IntPtr ppv);
        [PreserveSig] int Clone(ref Guid riid, ref IntPtr ppv);
        [PreserveSig] int GetImageRect(int i, IntPtr prc);
        [PreserveSig] int GetIconSize(ref int cx, ref int cy);
        [PreserveSig] int SetIconSize(int cx, int cy);
        [PreserveSig] int GetImageCount(ref int pi);
        [PreserveSig] int SetImageCount(int uNewCount);
        [PreserveSig] int SetBkColor(int clrBk, ref int pclr);
        [PreserveSig] int GetBkColor(ref int pclr);
        [PreserveSig] int BeginDrag(int iTrack, int dxHotspot, int dyHotspot);
        [PreserveSig] int EndDrag();
        [PreserveSig] int DragEnter(IntPtr hwndLock, int x, int y);
        [PreserveSig] int DragLeave(IntPtr hwndLock);
        [PreserveSig] int DragMove(int x, int y);
        [PreserveSig] int SetDragCursorImage(
            ref IImageList punk,
            int iDrag,
            int dxHotspot,
            int dyHotspot
        );
        [PreserveSig] int DragShowNolock(int fShow);
        [PreserveSig] int GetDragImage(
            IntPtr ppt,
            IntPtr pptHotspot,
            ref Guid riid,
            ref IntPtr ppv
        );
        [PreserveSig] int GetItemFlags(int i, ref int dwFlags);
        [PreserveSig] int GetOverlayImage(int iOverlay, ref int piIndex);
    }

    public static Bitmap GetIcon(string path, bool directory)
    {
        SHFILEINFO info;

        uint attrs = directory
            ? FILE_ATTRIBUTE_DIRECTORY
            : FILE_ATTRIBUTE_NORMAL;

        IntPtr result = SHGetFileInfo(
            path,
            attrs,
            out info,
            (uint)Marshal.SizeOf(typeof(SHFILEINFO)),
            SHGFI_SYSICONINDEX | SHGFI_LARGEICON
        );

        if (result == IntPtr.Zero)
            return null;

        Guid iid =
            new Guid("46EB5926-582E-4017-9FDF-E8998DAA0950");

        IImageList imageList = null;

        int hr = SHGetImageList(
            SHIL_JUMBO,
            ref iid,
            ref imageList
        );

        if (hr != 0 || imageList == null)
            return null;

        IntPtr hIcon = IntPtr.Zero;

        try
        {
            hr = imageList.GetIcon(
                info.iIcon,
                ILD_TRANSPARENT | ILD_IMAGE,
                ref hIcon
            );

            if (hr != 0 || hIcon == IntPtr.Zero)
                return null;

            using (Icon icon = Icon.FromHandle(hIcon))
            {
                return icon.ToBitmap();
            }
        }
        finally
        {
            if (hIcon != IntPtr.Zero)
                DestroyIcon(hIcon);
        }
    }
}
'@ -ReferencedAssemblies @(
    "System.Drawing",
    "System.Windows.Forms"
)

# ============================================================
# 016 - RESIZE ICON
# ============================================================

function Resize-IconBitmap {

    param(
        [System.Drawing.Bitmap]$Source,
        [int]$Size
    )

    if ($null -eq $Source) {
        return $null
    }

    try {

        $result = New-Object System.Drawing.Bitmap(
            $Size,
            $Size,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )

        $g = [System.Drawing.Graphics]::FromImage($result)

        try {

            $g.Clear([System.Drawing.Color]::Transparent)

            $g.CompositingMode =
                [System.Drawing.Drawing2D.CompositingMode]::SourceCopy

            $g.CompositingQuality =
                [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

            $g.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

            $ratio = [Math]::Min(
                $Size / [double]$Source.Width,
                $Size / [double]$Source.Height
            )

            $w = [int]($Source.Width * $ratio)
            $h = [int]($Source.Height * $ratio)

            $x = [int](($Size - $w) / 2)
            $y = [int](($Size - $h) / 2)

            $g.DrawImage(
                $Source,
                (New-Object System.Drawing.Rectangle(
                    $x,$y,$w,$h
                ))
            )
        }
        finally {
            $g.Dispose()
        }

        return $result
    }
    catch {
        return $null
    }
}

# ============================================================
# 017 - GET DESKTOP ICON
# ============================================================

function Get-DesktopIcon {

    param(
        [System.IO.FileInfo]$Item,
        [int]$Size
    )

    $raw = $null

    try {
        $raw = [WindowsJumboIcons]::GetIcon(
            $Item.FullName,
            $Item.PSIsContainer
        )
    }
    catch {
    }

    if ($null -eq $raw) {

        try {
            if ($Item.PSIsContainer) {
                $raw =
                    [System.Drawing.SystemIcons]::WinLogo.ToBitmap()
            }
            else {
                $raw =
                    [System.Drawing.SystemIcons]::Application.ToBitmap()
            }
        }
        catch {
            return $null
        }
    }

    $scaled = Resize-IconBitmap $raw $Size

    try {
        $raw.Dispose()
    }
    catch {
    }

    return $scaled
}

# ============================================================
# 018 - DISPOSE DESKTOP
# ============================================================

function Dispose-DesktopControls {

    foreach ($control in @($script:desktopControls)) {

        if ($null -ne $control) {
            try {
                $control.Dispose()
            }
            catch {
            }
        }
    }

    $script:desktopControls = @()

    foreach ($panel in @($script:desktopPanels)) {

        if ($null -ne $panel) {
            try {
                $panel.Dispose()
            }
            catch {
            }
        }
    }

    $script:desktopPanels = @()

    foreach ($bitmap in @($script:iconBitmaps)) {

        if ($null -ne $bitmap) {
            try {
                $bitmap.Dispose()
            }
            catch {
            }
        }
    }

    $script:iconBitmaps = @()
}

# ============================================================
# 019 - OPEN ITEM
# ============================================================

function Open-DesktopItem {

    param(
        [string]$Path
    )

    if (
        [string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path)
    ) {
        return
    }

    try {
        Start-Process -FilePath $Path -ErrorAction Stop
    }
    catch {
        try {
            Invoke-Item -LiteralPath $Path -ErrorAction SilentlyContinue
        }
        catch {
        }
    }
}

# ============================================================
# 020 - POSITION
# ============================================================

function Get-SavedPosition {

    param(
        [string]$Path
    )

    if ($settings.Positions.ContainsKey($Path)) {

        try {
            return New-Object System.Drawing.Point(
                [int]$settings.Positions[$Path].X,
                [int]$settings.Positions[$Path].Y
            )
        }
        catch {
        }
    }

    return $null
}

function Save-ItemPosition {

    param(
        [string]$Path,
        [int]$X,
        [int]$Y
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $settings.Positions[$Path] = @{
        X = $X
        Y = $Y
    }

    Save-DesktopSettings
}

# ============================================================
# 021 - SAVE ALL POSITIONS
# ============================================================

function Save-AllPositions {

    foreach ($panel in @($script:desktopPanels)) {

        if ($null -eq $panel) {
            continue
        }

        $path = [string]$panel.Tag

        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        Save-ItemPosition `
            -Path $path `
            -X $panel.Left `
            -Y $panel.Top
    }
}

# ============================================================
# 022 - FREE POSITION
# ============================================================

function Get-FreePosition {

    param(
        [int]$Index,
        [int]$CellWidth,
        [int]$CellHeight
    )

    $columns = [Math]::Max(
        1,
        [int][Math]::Floor(
            [Math]::Max(
                300,
                $script:primaryForm.ClientSize.Width - 20
            ) / $CellWidth
        )
    )

    $column = $Index % $columns
    $row = [int][Math]::Floor($Index / $columns)

    return New-Object System.Drawing.Point(
        14 + ($column * $CellWidth),
        100 + ($row * $CellHeight)
    )
}

# ============================================================
# 023 - ICON SIZE
# ============================================================

function Change-IconScale {

    param(
        [int]$Delta
    )

    $newSize = [int]$settings.IconScale + $Delta

    $newSize = [Math]::Max(
        48,
        [Math]::Min(160, $newSize)
    )

    if ($newSize -eq $settings.IconScale) {
        return
    }

    Save-AllPositions

    $settings.IconScale = $newSize

    Save-DesktopSettings

    Build-DesktopIcons
}

# ============================================================
# 024 - RENAME
# ============================================================

function Rename-DesktopItem {

    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {

        $item = Get-Item `
            -LiteralPath $Path `
            -ErrorAction Stop

        $dialog = New-Object System.Windows.Forms.Form

        $dialog.Text = "Rename"
        $dialog.Width = 470
        $dialog.Height = 190

        $dialog.StartPosition =
            [System.Windows.Forms.FormStartPosition]::CenterScreen

        $dialog.FormBorderStyle =
            [System.Windows.Forms.FormBorderStyle]::FixedDialog

        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false

        $dialog.BackColor =
            [System.Drawing.Color]::FromArgb(22,27,34)

        Enable-DoubleBuffer $dialog

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "New name"
        $label.Left = 24
        $label.Top = 20
        $label.AutoSize = $true
        $label.ForeColor = $script:Colors.Text

        $dialog.Controls.Add($label)

        $box = New-Object System.Windows.Forms.TextBox

        $box.Left = 24
        $box.Top = 48
        $box.Width = 400
        $box.Height = 28
        $box.Text = $item.Name

        $dialog.Controls.Add($box)

        $ok = New-Object System.Windows.Forms.Button

        $ok.Text = "Rename"
        $ok.Left = 235
        $ok.Top = 92
        $ok.Width = 90
        $ok.Height = 34

        $ok.BackColor = $script:Colors.Accent
        $ok.ForeColor = $script:Colors.Text
        $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $ok.FlatAppearance.BorderSize = 0

        $dialog.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button

        $cancel.Text = "Cancel"
        $cancel.Left = 334
        $cancel.Top = 92
        $cancel.Width = 90
        $cancel.Height = 34

        $cancel.BackColor = $script:Colors.Button
        $cancel.ForeColor = $script:Colors.Text
        $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $cancel.FlatAppearance.BorderSize = 0

        $dialog.Controls.Add($cancel)

        $dialog.AcceptButton = $ok
        $dialog.CancelButton = $cancel

        $ok.Add_Click({

            $newName = $box.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($newName)) {
                return
            }

            try {

                $oldPath = $Path

                Rename-Item `
                    -LiteralPath $oldPath `
                    -NewName $newName `
                    -ErrorAction Stop

                $newPath = Join-Path `
                    (Split-Path -Parent $oldPath) `
                    $newName

                if ($settings.Positions.ContainsKey($oldPath)) {

                    $oldPosition =
                        $settings.Positions[$oldPath]

                    $settings.Positions.Remove($oldPath)

                    $settings.Positions[$newPath] = @{
                        X = [int]$oldPosition.X
                        Y = [int]$oldPosition.Y
                    }
                }

                $script:selectedPath = $newPath

                Save-DesktopSettings

                $dialog.Close()

                Refresh-Desktop
            }
            catch {

                [System.Windows.Forms.MessageBox]::Show(
                    "Could not rename the item.",
                    "Rename",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        })

        $cancel.Add_Click({
            $dialog.Close()
        })

        $box.SelectAll()
        $box.Focus()

        [void]$dialog.ShowDialog()

        $dialog.Dispose()
    }
    catch {
    }
}

# ============================================================
# 025 - DELETE
# ============================================================

function Delete-DesktopItem {

    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {

        $item = Get-Item `
            -LiteralPath $Path `
            -ErrorAction Stop

        $result =
            [System.Windows.Forms.MessageBox]::Show(
                "Move '$($item.Name)' to the Recycle Bin?",
                "Delete",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

        if (
            $result -ne
            [System.Windows.Forms.DialogResult]::Yes
        ) {
            return
        }

        $shell = New-Object -ComObject Shell.Application

        $folder = $shell.Namespace(
            (Split-Path -Parent $Path)
        )

        $shellItem = $folder.ParseName(
            (Split-Path -Leaf $Path)
        )

        if ($null -ne $shellItem) {
            $shellItem.InvokeVerb("delete")
        }

        if ($settings.Positions.ContainsKey($Path)) {
            $settings.Positions.Remove($Path)
            Save-DesktopSettings
        }

        if ($script:selectedPath -eq $Path) {
            $script:selectedPath = $null
        }

        Refresh-Desktop
    }
    catch {
    }
}

# ============================================================
# 026 - PROPERTIES
# ============================================================

function Show-ItemProperties {

    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {

        $shell = New-Object -ComObject Shell.Application

        $folder = $shell.Namespace(
            (Split-Path -Parent $Path)
        )

        $item = $folder.ParseName(
            (Split-Path -Leaf $Path)
        )

        if ($null -ne $item) {
            $item.InvokeVerb("properties")
        }
    }
    catch {
    }
}

# ============================================================
# 027 - NEW FOLDER
# ============================================================

function New-DesktopFolder {

    try {

        $number = 0

        do {

            if ($number -eq 0) {
                $name = "New Folder"
            }
            else {
                $name = "New Folder ($number)"
            }

            $path = Join-Path $desktopPath $name
            $number++

        }
        while (Test-Path -LiteralPath $path)

        New-Item `
            -ItemType Directory `
            -Path $path `
            -Force |
            Out-Null

        Refresh-Desktop
    }
    catch {
    }
}

# ============================================================
# 028 - NEW TEXT FILE
# ============================================================

function New-DesktopTextFile {

    try {

        $number = 0

        do {

            if ($number -eq 0) {
                $name = "New Text Document.txt"
            }
            else {
                $name = "New Text Document ($number).txt"
            }

            $path = Join-Path $desktopPath $name
            $number++

        }
        while (Test-Path -LiteralPath $path)

        [System.IO.File]::WriteAllText(
            $path,
            ""
        )

        Refresh-Desktop
    }
    catch {
    }
}

# ============================================================
# 029 - HOVER
# ============================================================

function Set-ItemHover {

    param(
        [System.Windows.Forms.Panel]$Panel,
        [bool]$Hover
    )

    if ($null -eq $Panel) {
        return
    }

    try {

        if ($Hover) {
            $color = $script:Colors.PanelHover
        }
        else {
            $color = $script:Colors.Panel
        }

        $Panel.BackColor = $color

        foreach ($child in $Panel.Controls) {

            if ($null -ne $child) {
                $child.BackColor = $color
            }
        }

        $Panel.Invalidate()
    }
    catch {
    }
}

# ============================================================
# 030 - CONTEXT MENUS
# ============================================================

function Create-ContextMenus {

    # ---------------- DESKTOP ----------------

    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $menu.BackColor =
        [System.Drawing.Color]::FromArgb(25,30,37)

    $menu.ForeColor = $script:Colors.Text

    $menu.ShowImageMargin = $false
    $menu.ShowCheckMargin = $false

    $settingsItem = $menu.Items.Add("Settings")
    $refreshItem = $menu.Items.Add("Refresh")

    [void]$menu.Items.Add(
        (New-Object System.Windows.Forms.ToolStripSeparator)
    )

    $newFolderItem = $menu.Items.Add("New Folder")
    $newFileItem = $menu.Items.Add("New Text Document")

    [void]$menu.Items.Add(
        (New-Object System.Windows.Forms.ToolStripSeparator)
    )

    $increaseItem = $menu.Items.Add("Increase Icon Size")
    $decreaseItem = $menu.Items.Add("Decrease Icon Size")

    $settingsItem.Add_Click({
        Show-Settings
    })

    $refreshItem.Add_Click({
        Refresh-Desktop
    })

    $newFolderItem.Add_Click({
        New-DesktopFolder
    })

    $newFileItem.Add_Click({
        New-DesktopTextFile
    })

    $increaseItem.Add_Click({
        Change-IconScale 8
    })

    $decreaseItem.Add_Click({
        Change-IconScale -8
    })

    $script:contextMenu = $menu

    # ---------------- ITEM ----------------

    $itemMenu =
        New-Object System.Windows.Forms.ContextMenuStrip

    $itemMenu.BackColor =
        [System.Drawing.Color]::FromArgb(25,30,37)

    $itemMenu.ForeColor = $script:Colors.Text

    $itemMenu.ShowImageMargin = $false
    $itemMenu.ShowCheckMargin = $false

    $openItem = $itemMenu.Items.Add("Open")

    [void]$itemMenu.Items.Add(
        (New-Object System.Windows.Forms.ToolStripSeparator)
    )

    $renameItem = $itemMenu.Items.Add("Rename")
    $deleteItem = $itemMenu.Items.Add("Delete")

    [void]$itemMenu.Items.Add(
        (New-Object System.Windows.Forms.ToolStripSeparator)
    )

    $propertiesItem = $itemMenu.Items.Add("Properties")

    $openItem.Add_Click({

        $path = [string]$itemMenu.Tag

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $script:selectedPath = $path
            Open-DesktopItem $path
        }
    })

    $renameItem.Add_Click({

        $path = [string]$itemMenu.Tag

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $script:selectedPath = $path
            Rename-DesktopItem $path
        }
    })

    $deleteItem.Add_Click({

        $path = [string]$itemMenu.Tag

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $script:selectedPath = $path
            Delete-DesktopItem $path
        }
    })

    $propertiesItem.Add_Click({

        $path = [string]$itemMenu.Tag

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $script:selectedPath = $path
            Show-ItemProperties $path
        }
    })

    $script:itemContextMenu = $itemMenu
}

# ============================================================
# 031 - ITEM CONTEXT MENU
# ============================================================

function Show-ItemContextMenu {

    param(
        [string]$Path,
        [System.Drawing.Point]$ScreenPoint
    )

    if ($null -eq $script:itemContextMenu) {
        return
    }

    $script:selectedPath = $Path
    $script:itemContextMenu.Tag = $Path

    try {
        $script:itemContextMenu.Show($ScreenPoint)
    }
    catch {
    }
}

# ============================================================
# 032 - REFRESH
# ============================================================

function Refresh-Desktop {

    if ($script:refreshing) {
        return
    }

    if (
        $null -eq $script:primaryForm -or
        $script:primaryForm.IsDisposed
    ) {
        return
    }

    Save-AllPositions

    Build-DesktopIcons
}

# ============================================================
# 033 - RESET SETTINGS
# ============================================================

function Reset-DesktopSettings {

    $settings.BackgroundType =
        $defaultSettings.BackgroundType

    $settings.BackgroundColor =
        $defaultSettings.BackgroundColor

    $settings.ImagePath =
        $defaultSettings.ImagePath

    $settings.ImageMode =
        $defaultSettings.ImageMode

    $settings.IconScale =
        $defaultSettings.IconScale

    $settings.Positions = @{}

    $script:selectedPath = $null

    Save-DesktopSettings

    Load-BackgroundImage

    foreach ($form in $script:forms) {

        if (
            $null -ne $form -and
            -not $form.IsDisposed
        ) {
            Apply-Background $form
        }
    }

    Build-DesktopIcons
}

# ============================================================
# 034 - SETTINGS WINDOW
# ============================================================

function Show-Settings {

    if (
        $script:settingsForm -and
        -not $script:settingsForm.IsDisposed
    ) {
        $script:settingsForm.Activate()
        return
    }

    $sf = New-Object System.Windows.Forms.Form

    $script:settingsForm = $sf

    $sf.Text = "Emulated Desktop - Settings"
    $sf.Width = 560
    $sf.Height = 620

    $sf.StartPosition =
        [System.Windows.Forms.FormStartPosition]::CenterScreen

    $sf.FormBorderStyle =
        [System.Windows.Forms.FormBorderStyle]::FixedDialog

    $sf.MaximizeBox = $false
    $sf.MinimizeBox = $false

    $sf.BackColor =
        [System.Drawing.Color]::FromArgb(20,25,31)

    Enable-DoubleBuffer $sf

    # HEADER

    $header = New-Object System.Windows.Forms.Panel

    $header.Left = 0
    $header.Top = 0
    $header.Width = 544
    $header.Height = 88

    $header.BackColor =
        [System.Drawing.Color]::FromArgb(27,33,41)

    $sf.Controls.Add($header)

    $title = New-Object System.Windows.Forms.Label

    $title.Text = "Desktop Settings"
    $title.Left = 26
    $title.Top = 17
    $title.AutoSize = $true

    $title.ForeColor = $script:Colors.Text

    $title.Font =
        New-Object System.Drawing.Font(
            "Segoe UI",
            17,
            [System.Drawing.FontStyle]::Bold
        )

    $header.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label

    $subtitle.Text =
        "Appearance, wallpaper, icons and layout"

    $subtitle.Left = 28
    $subtitle.Top = 51
    $subtitle.AutoSize = $true

    $subtitle.ForeColor = $script:Colors.Muted

    $header.Controls.Add($subtitle)

    # BACKGROUND TITLE

    $backgroundTitle =
        New-Object System.Windows.Forms.Label

    $backgroundTitle.Text = "BACKGROUND"
    $backgroundTitle.Left = 28
    $backgroundTitle.Top = 108
    $backgroundTitle.AutoSize = $true

    $backgroundTitle.ForeColor =
        [System.Drawing.Color]::FromArgb(95,160,230)

    $backgroundTitle.Font =
        New-Object System.Drawing.Font(
            "Segoe UI",
            9,
            [System.Drawing.FontStyle]::Bold
        )

    $sf.Controls.Add($backgroundTitle)

    # RADIO COLOR

    $radioColor =
        New-Object System.Windows.Forms.RadioButton

    $radioColor.Text = "Solid color"
    $radioColor.Left = 30
    $radioColor.Top = 138
    $radioColor.AutoSize = $true

    $radioColor.ForeColor = $script:Colors.Text

    $radioColor.Checked =
        ($settings.BackgroundType -eq "Color")

    $sf.Controls.Add($radioColor)

    # RADIO IMAGE

    $radioImage =
        New-Object System.Windows.Forms.RadioButton

    $radioImage.Text = "Image"
    $radioImage.Left = 160
    $radioImage.Top = 138
    $radioImage.AutoSize = $true

    $radioImage.ForeColor = $script:Colors.Text

    $radioImage.Checked =
        ($settings.BackgroundType -eq "Image")

    $sf.Controls.Add($radioImage)

    # COLOR BUTTON

    $colorButton =
        New-Object System.Windows.Forms.Button

    $colorButton.Text = "Choose Color"
    $colorButton.Left = 28
    $colorButton.Top = 172
    $colorButton.Width = 150
    $colorButton.Height = 36

    $colorButton.BackColor = $script:Colors.Button
    $colorButton.ForeColor = $script:Colors.Text

    $colorButton.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $colorButton.FlatAppearance.BorderSize = 0

    $colorButton.Add_Click({

        $dialog =
            New-Object System.Windows.Forms.ColorDialog

        $dialog.FullOpen = $true

        $dialog.Color =
            Get-ColorFromHex $settings.BackgroundColor

        if (
            $dialog.ShowDialog() -eq
            [System.Windows.Forms.DialogResult]::OK
        ) {

            $settings.BackgroundColor =
                [System.Drawing.ColorTranslator]::ToHtml(
                    $dialog.Color
                )

            $radioColor.Checked = $true
        }

        $dialog.Dispose()
    })

    $sf.Controls.Add($colorButton)

    # IMAGE BUTTON

    $imageButton =
        New-Object System.Windows.Forms.Button

    $imageButton.Text = "Choose Image"
    $imageButton.Left = 192
    $imageButton.Top = 172
    $imageButton.Width = 150
    $imageButton.Height = 36

    $imageButton.BackColor = $script:Colors.Button
    $imageButton.ForeColor = $script:Colors.Text

    $imageButton.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $imageButton.FlatAppearance.BorderSize = 0

    $imageButton.Add_Click({

        $dialog =
            New-Object System.Windows.Forms.OpenFileDialog

        $dialog.Filter =
            "Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*"

        $dialog.Title = "Choose desktop wallpaper"

        if (
            $dialog.ShowDialog() -eq
            [System.Windows.Forms.DialogResult]::OK
        ) {

            $settings.ImagePath =
                $dialog.FileName

            $radioImage.Checked = $true

            $currentLabel.Text =
                $dialog.FileName
        }

        $dialog.Dispose()
    })

    $sf.Controls.Add($imageButton)

    # IMAGE MODE

    $modeLabel =
        New-Object System.Windows.Forms.Label

    $modeLabel.Text = "Image mode"
    $modeLabel.Left = 28
    $modeLabel.Top = 225
    $modeLabel.AutoSize = $true
    $modeLabel.ForeColor = $script:Colors.Muted

    $sf.Controls.Add($modeLabel)

    $modeCombo =
        New-Object System.Windows.Forms.ComboBox

    foreach ($mode in @(
        "Fill",
        "Fit",
        "Stretch",
        "Center",
        "Tile"
    )) {
        [void]$modeCombo.Items.Add($mode)
    }

    $modeCombo.Left = 28
    $modeCombo.Top = 249
    $modeCombo.Width = 314

    $modeCombo.DropDownStyle =
        [System.Windows.Forms.ComboBoxStyle]::DropDownList

    $modeCombo.SelectedItem =
        $settings.ImageMode

    if ($modeCombo.SelectedIndex -lt 0) {
        $modeCombo.SelectedIndex = 0
    }

    $sf.Controls.Add($modeCombo)

    # CURRENT IMAGE

    $currentLabel =
        New-Object System.Windows.Forms.Label

    if (
        [string]::IsNullOrWhiteSpace($settings.ImagePath)
    ) {
        $currentLabel.Text = "No image selected"
    }
    else {
        $currentLabel.Text = $settings.ImagePath
    }

    $currentLabel.Left = 28
    $currentLabel.Top = 290
    $currentLabel.Width = 490
    $currentLabel.Height = 34

    $currentLabel.ForeColor = $script:Colors.Muted
    $currentLabel.AutoEllipsis = $true

    $sf.Controls.Add($currentLabel)

    # ICON TITLE

    $iconTitle =
        New-Object System.Windows.Forms.Label

    $iconTitle.Text = "ICON SIZE"
    $iconTitle.Left = 28
    $iconTitle.Top = 343
    $iconTitle.AutoSize = $true

    $iconTitle.ForeColor =
        [System.Drawing.Color]::FromArgb(95,160,230)

    $iconTitle.Font =
        New-Object System.Drawing.Font(
            "Segoe UI",
            9,
            [System.Drawing.FontStyle]::Bold
        )

    $sf.Controls.Add($iconTitle)

    # ICON SLIDER

    $iconSlider =
        New-Object System.Windows.Forms.TrackBar

    $iconSlider.Left = 28
    $iconSlider.Top = 370
    $iconSlider.Width = 350

    $iconSlider.Minimum = 48
    $iconSlider.Maximum = 160
    $iconSlider.TickFrequency = 8
    $iconSlider.Value = [int]$settings.IconScale

    $sf.Controls.Add($iconSlider)

    $iconSizeLabel =
        New-Object System.Windows.Forms.Label

    $iconSizeLabel.Text =
        "$($iconSlider.Value) px"

    $iconSizeLabel.Left = 395
    $iconSizeLabel.Top = 376
    $iconSizeLabel.Width = 100

    $iconSizeLabel.ForeColor = $script:Colors.Text

    $sf.Controls.Add($iconSizeLabel)

    $iconSlider.Add_Scroll({

        $iconSizeLabel.Text =
            "$($iconSlider.Value) px"
    })

    # INFO

    $info =
        New-Object System.Windows.Forms.Label

    $info.Text =
        "Drag icons to position them.`r`n" +
        "Positions are saved automatically.`r`n" +
        "F2 renames the selected icon."

    $info.Left = 28
    $info.Top = 420
    $info.Width = 480
    $info.Height = 60

    $info.ForeColor = $script:Colors.Muted

    $sf.Controls.Add($info)

    # RESET

    $reset =
        New-Object System.Windows.Forms.Button

    $reset.Text = "Revert to Defaults"
    $reset.Left = 28
    $reset.Top = 485
    $reset.Width = 180
    $reset.Height = 38

    $reset.BackColor = $script:Colors.Danger
    $reset.ForeColor =
        [System.Drawing.Color]::FromArgb(240,205,210)

    $reset.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $reset.FlatAppearance.BorderSize = 0

    $reset.Add_Click({

        $answer =
            [System.Windows.Forms.MessageBox]::Show(
                "Reset wallpaper, icon size and icon positions?",
                "Revert to Defaults",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

        if (
            $answer -eq
            [System.Windows.Forms.DialogResult]::Yes
        ) {

            Reset-DesktopSettings

            $radioColor.Checked = $true

            $iconSlider.Value =
                [int]$defaultSettings.IconScale

            $iconSizeLabel.Text =
                "$($iconSlider.Value) px"

            $modeCombo.SelectedItem =
                $defaultSettings.ImageMode

            $currentLabel.Text =
                "No image selected"
        }
    })

    $sf.Controls.Add($reset)

    # CANCEL

    $cancel =
        New-Object System.Windows.Forms.Button

    $cancel.Text = "Cancel"
    $cancel.Left = 218
    $cancel.Top = 485
    $cancel.Width = 100
    $cancel.Height = 38

    $cancel.BackColor = $script:Colors.Button
    $cancel.ForeColor = $script:Colors.Text

    $cancel.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $cancel.FlatAppearance.BorderSize = 0

    $cancel.Add_Click({
        $sf.Close()
    })

    $sf.Controls.Add($cancel)

    # APPLY

    $apply =
        New-Object System.Windows.Forms.Button

    $apply.Text = "Apply"
    $apply.Left = 328
    $apply.Top = 485
    $apply.Width = 190
    $apply.Height = 38

    $apply.BackColor = $script:Colors.Accent
    $apply.ForeColor = $script:Colors.Text

    $apply.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $apply.FlatAppearance.BorderSize = 0

    $apply.Add_Click({

        if ($radioImage.Checked) {
            $settings.BackgroundType = "Image"
        }
        else {
            $settings.BackgroundType = "Color"
        }

        if ($null -ne $modeCombo.SelectedItem) {
            $settings.ImageMode =
                [string]$modeCombo.SelectedItem
        }

        $settings.IconScale =
            [int]$iconSlider.Value

        Save-AllPositions
        Save-DesktopSettings

        Load-BackgroundImage

        foreach ($form in $script:forms) {

            if (
                $null -ne $form -and
                -not $form.IsDisposed
            ) {
                Apply-Background $form
            }
        }

        Build-DesktopIcons

        $sf.Close()
    })

    $sf.Controls.Add($apply)

    # SHORTCUTS

    $shortcuts =
        New-Object System.Windows.Forms.Label

    $shortcuts.Text =
        "F5 Refresh    PageUp/PageDown Resize    F2 Rename    ESC Exit"

    $shortcuts.Left = 28
    $shortcuts.Top = 540
    $shortcuts.Width = 500
    $shortcuts.Height = 24

    $shortcuts.ForeColor =
        [System.Drawing.Color]::FromArgb(105,115,128)

    $sf.Controls.Add($shortcuts)

    [void]$sf.ShowDialog()

    $script:settingsForm = $null

    try {
        $sf.Dispose()
    }
    catch {
    }
}

# ============================================================
# 035 - BUILD DESKTOP ICONS
# ============================================================

function Build-DesktopIcons {

    if (
        $null -eq $script:primaryForm -or
        $script:primaryForm.IsDisposed
    ) {
        return
    }

    if ($script:refreshing) {
        return
    }

    $script:refreshing = $true

    try {

        Save-AllPositions

        $form = $script:primaryForm

        $form.SuspendLayout()

        Dispose-DesktopControls

        $items = @()

        try {

            $items = @(
                Get-ChildItem `
                    -LiteralPath $desktopPath `
                    -Force `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -ne "desktop.ini"
                } |
                Sort-Object `
                    @{Expression={-not $_.PSIsContainer}},
                    @{Expression={$_.Name}}
            )
        }
        catch {
            $items = @()
        }

        $iconSize = [int]$settings.IconScale

        $cellWidth =
            [Math]::Max(
                115,
                $iconSize + 35
            )

        $cellHeight =
            [Math]::Max(
                125,
                $iconSize + 55
            )

        $index = 0

        foreach ($item in $items) {

            try {

                $path = $item.FullName

                $panel =
                    New-Object System.Windows.Forms.Panel

                $panel.Width =
                    [int]$cellWidth - 10

                $panel.Height =
                    [int]$cellHeight

                $panel.BackColor =
                    $script:Colors.Panel

                $panel.Tag = $path

                Enable-DoubleBuffer $panel

                $saved =
                    Get-SavedPosition $path

                if ($null -ne $saved) {

                    $panel.Left = $saved.X
                    $panel.Top = $saved.Y
                }
                else {

                    $position =
                        Get-FreePosition `
                            -Index $index `
                            -CellWidth $cellWidth `
                            -CellHeight $cellHeight

                    $panel.Left = $position.X
                    $panel.Top = $position.Y

                    Save-ItemPosition `
                        -Path $path `
                        -X $panel.Left `
                        -Y $panel.Top
                }

                # ---------------- ICON ----------------

                $picture =
                    New-Object System.Windows.Forms.PictureBox

                $picture.Width = $iconSize
                $picture.Height = $iconSize

                $picture.Left =
                    [int](($panel.Width - $iconSize) / 2)

                $picture.Top = 5

                $picture.BackColor =
                    $script:Colors.Panel

                $picture.SizeMode =
                    [System.Windows.Forms.PictureBoxSizeMode]::CenterImage

                $picture.Tag = $path

                Enable-DoubleBuffer $picture

                $bitmap =
                    Get-DesktopIcon `
                        -Item $item `
                        -Size $iconSize

                if ($null -ne $bitmap) {

                    $picture.Image = $bitmap

                    $script:iconBitmaps += $bitmap
                }

                # ---------------- LABEL ----------------

                $label =
                    New-Object System.Windows.Forms.Label

                $label.Width = $panel.Width
                $label.Height = 40

                $label.Left = 0
                $label.Top = $iconSize + 8

                $label.Text = $item.Name

                $label.ForeColor =
                    $script:Colors.Text

                $label.BackColor =
                    $script:Colors.Panel

                $label.Font =
                    New-Object System.Drawing.Font(
                        "Segoe UI",
                        9
                    )

                $label.TextAlign =
                    [System.Drawing.ContentAlignment]::TopCenter

                $label.AutoEllipsis = $true
                $label.Tag = $path

                # ====================================================
                # EVENTS
                # ====================================================

                $enter = {

                    param($sender,$e)

                    try {

                        $target = $sender

                        if (
                            $target -is
                            [System.Windows.Forms.PictureBox]
                        ) {
                            $target = $target.Parent
                        }

                        if (
                            $target -is
                            [System.Windows.Forms.Label]
                        ) {
                            $target = $target.Parent
                        }

                        Set-ItemHover $target $true
                    }
                    catch {
                    }
                }

                $leave = {

                    param($sender,$e)

                    try {

                        $target = $sender

                        if (
                            $target -is
                            [System.Windows.Forms.PictureBox]
                        ) {
                            $target = $target.Parent
                        }

                        if (
                            $target -is
                            [System.Windows.Forms.Label]
                        ) {
                            $target = $target.Parent
                        }

                        Set-ItemHover $target $false
                    }
                    catch {
                    }
                }

                # ====================================================
                # DOUBLE CLICK
                # ====================================================

                $doubleClick = {

                    param($sender,$e)

                    try {

                        $pathToOpen = [string]$sender.Tag

                        if (
                            -not [string]::IsNullOrWhiteSpace(
                                $pathToOpen
                            )
                        ) {

                            $script:selectedPath = $pathToOpen

                            Open-DesktopItem $pathToOpen
                        }
                    }
                    catch {
                    }
                }

                # ====================================================
                # RIGHT CLICK
                # ====================================================

                $rightClick = {

                    param($sender,$e)

                    try {

                        if (
                            $e.Button -ne
                            [System.Windows.Forms.MouseButtons]::Right
                        ) {
                            return
                        }

                        $pathToOpen = [string]$sender.Tag

                        if (
                            [string]::IsNullOrWhiteSpace(
                                $pathToOpen
                            )
                        ) {
                            return
                        }

                        $script:selectedPath = $pathToOpen

                        $screenPoint =
                            $sender.PointToScreen(
                                $e.Location
                            )

                        Show-ItemContextMenu `
                            -Path $pathToOpen `
                            -ScreenPoint $screenPoint
                    }
                    catch {
                    }
                }

                # ====================================================
                # MOUSE DOWN
                # ====================================================

                $mouseDown = {

                    param($sender,$e)

                    try {

                        if (
                            $e.Button -ne
                            [System.Windows.Forms.MouseButtons]::Left
                        ) {
                            return
                        }

                        $target = $sender

                        if (
                            $target -is
                            [System.Windows.Forms.PictureBox]
                        ) {
                            $target = $target.Parent
                        }

                        if (
                            $target -is
                            [System.Windows.Forms.Label]
                        ) {
                            $target = $target.Parent
                        }

                        if ($null -eq $target) {
                            return
                        }

                        $path = [string]$target.Tag

                        if ([string]::IsNullOrWhiteSpace($path)) {
                            return
                        }

                        # FIX:
                        # Selection survives mouse release.
                        $script:selectedPath = $path

                        $screenPoint =
                            $sender.PointToScreen(
                                $e.Location
                            )

                        $localPoint =
                            $target.PointToClient(
                                $screenPoint
                            )

                        $script:dragPanel = $target

                        $script:dragOffset =
                            New-Object System.Drawing.Point(
                                $localPoint.X,
                                $localPoint.Y
                            )

                        $script:isDragging = $false

                        # FIX:
                        # Keep mouse events while dragging.
                        $target.Capture = $true

                        $target.BringToFront()

                        Set-ItemHover `
                            -Panel $target `
                            -Hover $true
                    }
                    catch {
                    }
                }

                # ====================================================
                # MOUSE MOVE
                # ====================================================

                $mouseMove = {

                    param($sender,$e)

                    try {

                        if ($null -eq $script:dragPanel) {
                            return
                        }

                        if (
                            [System.Windows.Forms.Control]::MouseButtons -ne
                            [System.Windows.Forms.MouseButtons]::Left
                        ) {
                            return
                        }

                        $screenPoint =
                            [System.Windows.Forms.Cursor]::Position

                        $clientPoint =
                            $script:primaryForm.PointToClient(
                                $screenPoint
                            )

                        $newX =
                            $clientPoint.X -
                            $script:dragOffset.X

                        $newY =
                            $clientPoint.Y -
                            $script:dragOffset.Y

                        if (
                            [Math]::Abs(
                                $newX -
                                $script:dragPanel.Left
                            ) -gt 2 -or
                            [Math]::Abs(
                                $newY -
                                $script:dragPanel.Top
                            ) -gt 2
                        ) {
                            $script:isDragging = $true
                        }

                        if ($newX -lt 0) {
                            $newX = 0
                        }

                        if ($newY -lt 76) {
                            $newY = 76
                        }

                        $maxX =
                            [Math]::Max(
                                0,
                                $script:primaryForm.ClientSize.Width -
                                $script:dragPanel.Width
                            )

                        $maxY =
                            [Math]::Max(
                                76,
                                $script:primaryForm.ClientSize.Height -
                                $script:dragPanel.Height -
                                8
                            )

                        if ($newX -gt $maxX) {
                            $newX = $maxX
                        }

                        if ($newY -gt $maxY) {
                            $newY = $maxY
                        }

                        $script:dragPanel.Left = $newX
                        $script:dragPanel.Top = $newY

                        $script:dragPanel.Invalidate()
                    }
                    catch {
                    }
                }

                # ====================================================
                # MOUSE UP
                # ====================================================

                $mouseUp = {

                    param($sender,$e)

                    try {

                        if (
                            $e.Button -ne
                            [System.Windows.Forms.MouseButtons]::Left
                        ) {
                            return
                        }

                        if ($null -ne $script:dragPanel) {

                            $panel = $script:dragPanel

                            try {
                                $panel.Capture = $false
                            }
                            catch {
                            }

                            $pathToSave =
                                [string]$panel.Tag

                            if (
                                -not [string]::IsNullOrWhiteSpace(
                                    $pathToSave
                                )
                            ) {

                                Save-ItemPosition `
                                    -Path $pathToSave `
                                    -X $panel.Left `
                                    -Y $panel.Top

                                $script:selectedPath =
                                    $pathToSave
                            }
                        }

                        $script:dragPanel = $null
                        $script:dragOffset = $null
                        $script:isDragging = $false
                    }
                    catch {

                        try {
                            if ($null -ne $script:dragPanel) {
                                $script:dragPanel.Capture = $false
                            }
                        }
                        catch {
                        }

                        $script:dragPanel = $null
                        $script:dragOffset = $null
                        $script:isDragging = $false
                    }
                }

                # ====================================================
                # ATTACH EVENTS
                # ====================================================

                $panel.Add_MouseEnter($enter)
                $panel.Add_MouseLeave($leave)

                $picture.Add_MouseEnter($enter)
                $picture.Add_MouseLeave($leave)

                $label.Add_MouseEnter($enter)
                $label.Add_MouseLeave($leave)

                $panel.Add_MouseDown($mouseDown)
                $panel.Add_MouseMove($mouseMove)
                $panel.Add_MouseUp($mouseUp)

                $picture.Add_MouseDown($mouseDown)
                $picture.Add_MouseMove($mouseMove)
                $picture.Add_MouseUp($mouseUp)

                $label.Add_MouseDown($mouseDown)
                $label.Add_MouseMove($mouseMove)
                $label.Add_MouseUp($mouseUp)

                $panel.Add_MouseDoubleClick($doubleClick)
                $picture.Add_MouseDoubleClick($doubleClick)
                $label.Add_MouseDoubleClick($doubleClick)

                $panel.Add_MouseUp($rightClick)
                $picture.Add_MouseUp($rightClick)
                $label.Add_MouseUp($rightClick)

                # ====================================================
                # CONTROLS
                # ====================================================

                $panel.Controls.Add($picture)
                $panel.Controls.Add($label)

                $form.Controls.Add($panel)

                $script:desktopPanels += $panel
                $script:desktopControls += $picture
                $script:desktopControls += $label

                $index++
            }
            catch {
            }
        }

        # ========================================================
        # STATUS
        # ========================================================

        $status =
            New-Object System.Windows.Forms.Label

        $status.Text =
            "$index items    |    F5 Refresh    |    PageUp/PageDown Resize    |    F2 Rename"

        $status.Left = 20

        $status.Top =
            [Math]::Max(
                90,
                $form.ClientSize.Height - 28
            )

        $status.AutoSize = $true

        $status.ForeColor =
            [System.Drawing.Color]::FromArgb(
                105,115,128
            )

        $status.BackColor =
            $script:Colors.TopBar

        $status.Font =
            New-Object System.Drawing.Font(
                "Segoe UI",
                8
            )

        # FIX: status must not steal mouse input.
        $status.Enabled = $false
        $status.TabStop = $false

        $form.Controls.Add($status)

        $script:desktopControls += $status

        $form.ResumeLayout($true)

        $form.Invalidate()
    }
    finally {
        $script:refreshing = $false
    }
}

# ============================================================
# 036 - CREATE FORMS
# ============================================================

$screens =
    [System.Windows.Forms.Screen]::AllScreens

foreach ($screen in $screens) {

    $form =
        New-Object System.Windows.Forms.Form

    $form.FormBorderStyle =
        [System.Windows.Forms.FormBorderStyle]::None

    $form.StartPosition =
        [System.Windows.Forms.FormStartPosition]::Manual

    $form.Left =
        $screen.WorkingArea.Left

    $form.Top =
        $screen.WorkingArea.Top

    $form.Width =
        $screen.WorkingArea.Width

    $form.Height =
        $screen.WorkingArea.Height

    $form.ShowInTaskbar = $false
    $form.KeyPreview = $true

    $form.Text = "Emulated Desktop"

    $form.BackColor =
        $script:Colors.Background

    Enable-DoubleBuffer $form

    $form.Add_Paint({

        param($sender,$e)

        Paint-DesktopBackground $e
    })

    $script:forms += $form
}

# ============================================================
# 037 - PRIMARY FORM
# ============================================================

$primaryScreen =
    [System.Windows.Forms.Screen]::PrimaryScreen

foreach ($form in $script:forms) {

    if (
        $form.Left -eq
        $primaryScreen.WorkingArea.Left -and
        $form.Top -eq
        $primaryScreen.WorkingArea.Top
    ) {

        $script:primaryForm = $form
        break
    }
}

if ($null -eq $script:primaryForm) {
    $script:primaryForm = $script:forms[0]
}

# ============================================================
# 038 - TOP BAR
# ============================================================

$topBar =
    New-Object System.Windows.Forms.Panel

$topBar.Left = 0
$topBar.Top = 0

$topBar.Width =
    $script:primaryForm.ClientSize.Width

$topBar.Height = 58

$topBar.BackColor =
    $script:Colors.TopBar

Enable-DoubleBuffer $topBar

$script:primaryForm.Controls.Add($topBar)

# ============================================================
# 039 - TITLE
# ============================================================

$title =
    New-Object System.Windows.Forms.Label

$title.Text = "EMULATED DESKTOP"
$title.Left = 20
$title.Top = 10
$title.AutoSize = $true

$title.ForeColor = $script:Colors.Text
$title.BackColor = $script:Colors.TopBar

$title.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10,
        [System.Drawing.FontStyle]::Bold
    )

$topBar.Controls.Add($title)

$subtitle =
    New-Object System.Windows.Forms.Label

$subtitle.Text = "Windows desktop environment"
$subtitle.Left = 20
$subtitle.Top = 32
$subtitle.AutoSize = $true

$subtitle.ForeColor = $script:Colors.Muted
$subtitle.BackColor = $script:Colors.TopBar

$topBar.Controls.Add($subtitle)

# ============================================================
# 040 - SETTINGS BUTTON
# ============================================================

$settingsButton =
    New-Object System.Windows.Forms.Button

$settingsButton.Text = "Settings"

$settingsButton.Width = 112
$settingsButton.Height = 34

$settingsButton.Left =
    $topBar.Width - 128

$settingsButton.Top = 12

$settingsButton.BackColor =
    $script:Colors.Button

$settingsButton.ForeColor =
    $script:Colors.Text

$settingsButton.FlatStyle =
    [System.Windows.Forms.FlatStyle]::Flat

$settingsButton.FlatAppearance.BorderSize = 0

$settingsButton.Cursor =
    [System.Windows.Forms.Cursors]::Hand

$settingsButton.Add_Click({
    Show-Settings
})

$topBar.Controls.Add($settingsButton)

# ============================================================
# 041 - PATH
# ============================================================

$pathLabel =
    New-Object System.Windows.Forms.Label

$pathLabel.Text =
    $desktopPath

$pathLabel.Left = 20
$pathLabel.Top = 66
$pathLabel.AutoSize = $true

$pathLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        100,110,123
    )

$pathLabel.BackColor =
    [System.Drawing.Color]::Transparent

$pathLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        8
    )

$script:primaryForm.Controls.Add($pathLabel)

# ============================================================
# 042 - CONTEXT MENUS
# ============================================================

Create-ContextMenus

# ============================================================
# 043 - DESKTOP RIGHT CLICK
# ============================================================

$desktopMouseUp = {

    param($sender,$e)

    try {

        if (
            $e.Button -ne
            [System.Windows.Forms.MouseButtons]::Right
        ) {
            return
        }

        if ($sender -eq $script:primaryForm) {

            $script:contextMenu.Show(
                $sender,
                $e.Location
            )
        }
    }
    catch {
    }
}

foreach ($form in $script:forms) {
    $form.Add_MouseUp($desktopMouseUp)
}

# ============================================================
# 044 - KEYBOARD
# ============================================================

foreach ($form in $script:forms) {

    $form.Add_KeyDown({

        param($sender,$e)

        # --------------------------------------------------------
        # ESC
        # --------------------------------------------------------

        if (
            $e.KeyCode -eq
            [System.Windows.Forms.Keys]::Escape
        ) {

            foreach ($closeForm in $script:forms) {

                if (
                    $null -ne $closeForm -and
                    -not $closeForm.IsDisposed
                ) {
                    $closeForm.Close()
                }
            }

            $script:dragPanel = $null
            $script:dragOffset = $null
            $script:selectedPath = $null
            $script:isDragging = $false

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            return
        }

        # --------------------------------------------------------
        # F5
        # --------------------------------------------------------

        if (
            $e.KeyCode -eq
            [System.Windows.Forms.Keys]::F5
        ) {

            Refresh-Desktop

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            return
        }

        # --------------------------------------------------------
        # F2
        # --------------------------------------------------------

        if (
            $e.KeyCode -eq
            [System.Windows.Forms.Keys]::F2
        ) {

            # FIX:
            # use selectedPath, NOT dragPanel.
            $path = [string]$script:selectedPath

            if (
                -not [string]::IsNullOrWhiteSpace($path) -and
                (Test-Path -LiteralPath $path)
            ) {
                Rename-DesktopItem $path
            }

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            return
        }

        # --------------------------------------------------------
        # PAGE UP
        # --------------------------------------------------------

        if (
            $e.KeyCode -eq
            [System.Windows.Forms.Keys]::PageUp
        ) {

            Change-IconScale 8

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            return
        }

        # --------------------------------------------------------
        # PAGE DOWN
        # --------------------------------------------------------

        if (
            $e.KeyCode -eq
            [System.Windows.Forms.Keys]::PageDown
        ) {

            Change-IconScale -8

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            return
        }
    })
}

# ============================================================
# 045 - INITIAL LOAD
# ============================================================

Load-BackgroundImage

foreach ($form in $script:forms) {
    Apply-Background $form
}

Build-DesktopIcons

# ============================================================
# 046 - SHOW
# ============================================================

foreach ($form in $script:forms) {

    try {
        $form.Show()
    }
    catch {
    }
}

# ============================================================
# 047 - RUN
# ============================================================

try {

    [System.Windows.Forms.Application]::Run(
        $script:primaryForm
    )
}
catch {
}

# ============================================================
# 048 - CLEANUP
# ============================================================

try {
    Save-AllPositions
}
catch {
}

try {
    Save-DesktopSettings
}
catch {
}

try {
    Dispose-DesktopControls
}
catch {
}

if ($script:backgroundImage) {

    try {
        $script:backgroundImage.Dispose()
    }
    catch {
    }

    $script:backgroundImage = $null
}

foreach ($form in $script:forms) {

    if (
        $null -ne $form -and
        -not $form.IsDisposed
    ) {

        try {
            $form.Dispose()
        }
        catch {
        }
    }
}

if ($script:contextMenu) {

    try {
        $script:contextMenu.Dispose()
    }
    catch {
    }
}

if ($script:itemContextMenu) {

    try {
        $script:itemContextMenu.Dispose()
    }
    catch {
    }
}

# ============================================================
# 049 - END
# ============================================================

exit 0