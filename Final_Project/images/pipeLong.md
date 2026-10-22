`pipeLong.png` is the original 50 x 8 pipe-body tile. `pipeLong.bmp` is the
bitmap copy, and `pipeLong_RGB332.png` previews the VGA color quantization.
The FPGA stores all 400 pixels in `ProjectFiles/FlappyBird/RTL/pipeLong.mif`.
The byte format is RRRGGGBB, matching the existing bird bitmap.

Regenerate after editing the source image, from the Final_Project directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File images/Generate-PipeLongAssets.ps1
```

`pipeLongBitMap.sv` repeats the tile every 8 rows using the local pipe offset.
It has one clock of latency, matching the existing cap rectangles. The bitmap
is instantiated inside `pipe_square_object`, and `Pipe_Object.bdf` selects
each part's RGB output instead of overriding all parts with a constant color.
Pipe dimensions, gap, motion, and collision rectangles are unchanged.

The caps now use `pipeEdge.png`, a separate **64 x 16** sprite. One cap ROM
per `Pipe_Object` serves both ends, reversing the row address for the top cap.
See `pipeEdge.md` for asset generation and memory details.
