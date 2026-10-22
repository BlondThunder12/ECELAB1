`newPipeEdge.png` is the current **64 x 16 bottom-cap image**. `pipeEdge.bmp`
is its bitmap copy, and `pipeEdge_RGB332.png` previews VGA color conversion.
`ProjectFiles/FlappyBird/RTL/pipeEdge.mif` contains its 1024 RRRGGGBB pixels.
All pixels, including the dark border, are opaque.

Regenerate from Final_Project after editing the PNG:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File images/Generate-PipeEdgeAssets.ps1 -Source images/newPipeEdge.png
```

`pipeEdgeBitMap.sv` selects which cap contains the current pixel before
reading a **single ROM**. Bottom pixels use the source row directly; top
pixels use `15 - localY`. With 4-bit Y, inversion implements that flip.
The 10-bit address is `{sourceY, localX}`, equivalent to `sourceY * 64 + localX`
without a multiplier. Colors and both cap requests retain one clock of latency.

`Pipe_Object.bdf` uses this shared module in place of its two cap rectangles.
Each of the three pipe pairs has one 1024 x 8 cap ROM: 3 KiB of logical cap
data instead of 6 KiB for separate upper/lower ROMs. No flipped MIF is stored.
Actual physical RAM allocation also depends on FPGA memory block packing.

The color selector is still needed because bodies and caps have different RGB
sources. Both cap RGB inputs now share one net, allowing Quartus to merge
their selection branches. The mux contains no image storage or clock stage.

The current converted image has only four distinct pixel rows. A later
compression could store those rows in 256 bytes plus a row map. The full
64 x 16 ROM keeps addressing simple and supports editing any pixel directly.
