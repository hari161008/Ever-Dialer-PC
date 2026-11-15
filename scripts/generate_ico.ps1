Add-Type -AssemblyName System.Drawing

$sourcePng = 'C:\Android\PC Apps\Ever Dialer For PC\assets\icons\app_icon_512.png'
$destIco   = 'C:\Android\PC Apps\Ever Dialer For PC\windows\runner\resources\app_icon.ico'

$img = [System.Drawing.Image]::FromFile($sourcePng)

# Standard Windows icon sizes
$dibSizes = @(16, 24, 32, 48, 64)
$pngSizes = @(256)
$allSizes = $dibSizes + $pngSizes

$frameDataList = @()
$isPngList = @()

# 1. Generate DIB frames for 16, 24, 32, 48, 64
foreach ($sz in $dibSizes) {
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $sz, $sz)
    $g.Dispose()

    # Lock bits to get BGRA pixels
    $rect = New-Object System.Drawing.Rectangle(0, 0, $sz, $sz)
    $bmpData = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = [Math]::Abs($bmpData.Stride)
    $pixelBytes = New-Object byte[] ($stride * $sz)
    [System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $pixelBytes, 0, $pixelBytes.Length)
    $bmp.UnlockBits($bmpData)
    $bmp.Dispose()

    # AND mask stride (1 bit per pixel, padded to 32 bits = 4 bytes)
    $andStride = [int]([Math]::Ceiling($sz / 32.0) * 4)
    $andMask = New-Object byte[] ($andStride * $sz)

    # Build DIB stream: BITMAPINFOHEADER (40 bytes) + bottom-up BGRA pixels + AND mask
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    $bw.Write([uint32]40)              # biSize
    $bw.Write([int32]$sz)              # biWidth
    $bw.Write([int32]($sz * 2))        # biHeight (doubled for XOR + AND mask)
    $bw.Write([uint16]1)               # biPlanes
    $bw.Write([uint16]32)              # biBitCount
    $bw.Write([uint32]0)               # biCompression (BI_RGB)
    $bw.Write([uint32]($pixelBytes.Length + $andMask.Length)) # biSizeImage
    $bw.Write([int32]0)                # biXPelsPerMeter
    $bw.Write([int32]0)                # biYPelsPerMeter
    $bw.Write([uint32]0)               # biClrUsed
    $bw.Write([uint32]0)               # biClrImportant

    # Write scanlines in bottom-up order (from row sz-1 down to row 0)
    for ($y = $sz - 1; $y -ge 0; $y--) {
        $rowOffset = $y * $stride
        $bw.Write($pixelBytes, $rowOffset, $sz * 4)
    }

    # Write AND mask (all zeroes for 32-bit ARGB)
    $bw.Write($andMask)

    $frameDataList += ,($ms.ToArray())
    $isPngList += $false
    $bw.Close()
    $ms.Dispose()
}

# 2. Generate PNG frame for 256x256 (standard Vista/Win7/Win8/Win10/Win11 256x256 PNG frame)
foreach ($sz in $pngSizes) {
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $sz, $sz)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $frameDataList += ,($ms.ToArray())
    $isPngList += $true
    $ms.Dispose()
}

$img.Dispose()

# 3. Write final .ICO file
$fs = [System.IO.File]::Create($destIco)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICONDIR header (6 bytes)
$bw.Write([uint16]0)                # idReserved (must be 0)
$bw.Write([uint16]1)                # idType (1 for ICO)
$bw.Write([uint16]$allSizes.Count)  # idCount

# Calculate data offset
$dataOffset = 6 + (16 * $allSizes.Count)

# Write ICONDIRENTRY for each frame (16 bytes each)
for ($i = 0; $i -lt $allSizes.Count; $i++) {
    $sz = $allSizes[$i]
    $data = $frameDataList[$i]
    $bWidth = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }
    $bHeight = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }

    $bw.Write($bWidth)
    $bw.Write($bHeight)
    $bw.Write([byte]0)              # bColorCount
    $bw.Write([byte]0)              # bReserved
    $bw.Write([uint16]1)            # wPlanes
    $bw.Write([uint16]32)           # wBitCount
    $bw.Write([uint32]$data.Length) # dwBytesInRes
    $bw.Write([uint32]$dataOffset)  # dwImageOffset

    $dataOffset += $data.Length
}

# Write frame payload data
for ($i = 0; $i -lt $allSizes.Count; $i++) {
    $bw.Write($frameDataList[$i])
}

$bw.Close()
$fs.Close()

Write-Host "Successfully generated fully-compliant Windows .ICO at $destIco (Size: $((Get-Item $destIco).Length) bytes)"
