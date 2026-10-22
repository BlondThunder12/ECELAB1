$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$imagePath = Join-Path $PSScriptRoot 'explosion.png'
$mifPath = Join-Path $projectRoot 'ProjectFiles/FlappyBird/RTL/explosion.mif'
$rtlPath = Join-Path $projectRoot 'ProjectFiles/FlappyBird/RTL/VGA/explosion_draw.sv'
$bitmap = [Drawing.Bitmap]::FromFile($imagePath)
try {
    if ($bitmap.Width -ne 128 -or $bitmap.Height -ne 32) {
        throw 'Expected four 32x32 explosion frames in a 128x32 PNG.'
    }
    $colors = [Collections.Generic.SortedSet[int]]::new()
    for ($y=0; $y -lt 32; $y++) {
        for ($x=0; $x -lt 128; $x++) {
            $pixel = $bitmap.GetPixel($x,$y)
            if ($pixel.A -ne 0 -and $pixel.A -ne 255) { throw 'Explosion alpha must be binary.' }
            if ($pixel.A) {
                [void]$colors.Add((($pixel.R -shr 5) -shl 5) -bor (($pixel.G -shr 5) -shl 2) -bor ($pixel.B -shr 6))
            }
        }
    }
    if ($colors.Count -gt 15) { throw 'Too many colors for a four-bit indexed ROM.' }
    $indices = @{}
    $palette = [Collections.Generic.List[string]]::new()
    $index = 1 # Index zero is transparent, including when opaque black is used.
    foreach ($color in $colors) {
        $indices[$color] = $index
        $palette.Add(("        4'd{0}: pixelRGB = 8'h{1:X2};" -f $index,$color))
        $index++
    }
    $mif = [Collections.Generic.List[string]]::new()
    $mif.Add('-- explosion.png: four frame-major 32x32 tiles; index 0 is transparent.')
    $mif.Add('DEPTH = 4096;')
    $mif.Add('WIDTH = 4;')
    $mif.Add('ADDRESS_RADIX = HEX;')
    $mif.Add('DATA_RADIX = HEX;')
    $mif.Add('CONTENT BEGIN')
    for ($frame=0; $frame -lt 4; $frame++) {
        for ($y=0; $y -lt 32; $y++) {
            for ($x=0; $x -lt 32; $x++) {
                $pixel = $bitmap.GetPixel($frame*32+$x,$y)
                $value = 0
                if ($pixel.A) {
                    $color = (($pixel.R -shr 5) -shl 5) -bor (($pixel.G -shr 5) -shl 2) -bor ($pixel.B -shr 6)
                    $value = $indices[$color]
                }
                $mif.Add(('{0:X3}: {1:X};' -f ($frame*1024+$y*32+$x),$value))
            }
        }
    }
    $mif.Add('END;')
    [IO.File]::WriteAllLines($mifPath,$mif,[Text.Encoding]::ASCII)
    $rtl = [IO.File]::ReadAllText($rtlPath)
    $replacement = "// BEGIN GENERATED PALETTE`nalways_comb begin`n    case (colorIndex)`n" +
                   ($palette -join "`n") + "`n        default: pixelRGB = 8'h00;`n    endcase`nend`n// END GENERATED PALETTE"
    $rtl = [regex]::Replace($rtl,'(?s)// BEGIN GENERATED PALETTE.*?// END GENERATED PALETTE',$replacement)
    [IO.File]::WriteAllText($rtlPath,$rtl,[Text.Encoding]::ASCII)
    Write-Output "Generated explosion.mif (4096 x 4 bits) and $($colors.Count) opaque RGB332 colors."
} finally { $bitmap.Dispose() }
