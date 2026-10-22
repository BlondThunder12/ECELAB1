# Boss pipes and TNT

Bosses reuse the existing pipe tiles with their red and green channels swapped.
They start with touching caps (gap zero). Collecting their TNT opens them on the
first explosion frame. The unscaled 64x16 caps finish at Y=0..15 and Y=432..447,
leaving a 416-pixel opening above the ground at Y=448. Closed and opened bosses
use the existing pipe collision mask, damage cooldown, ghost protection and
Godmode behavior. The explosion is visual only.

`boss_control.sv` counts the stream of generated pipes, with at least five
normal pipes before each random boss. It plans the next generation while the
old physical pipe is still on the left of the screen. This lets the mandatory
TNT enter from offscreen halfway between that future boss and its predecessor,
instead of appearing suddenly when the boss recycles. TNT is centered vertically
on the preceding normal pipe's opening, shares the actual pipe scrolling step,
and carries its owner's index through collection. Ordinary pickups leave its
gap and one slot available.

The four original 32x32 explosion frames play for 22 VGA frames (about 0.3
seconds at the current approximately 72 Hz refresh rate). Pause freezes the
animation, boss state and pickups; restart clears them. A recycled pipe gets
fresh boss/open/animation state. `MIN_NORMAL_PIPES` and `EXPLOSION_FRAMES` in
`boss_control.sv` control the spacing and animation duration.

`pipeDR` remains the collision mask. `pipeVisualDR` additionally includes the
explosion and feeds only the display mux. The schematic symbols and connections
in `Pipe_Object`, `Items_Control` and `Top_Flappy_Bird_Game` include the new
controls. The normal pipe's 128-pixel gap is unchanged.

Regenerate the explosion ROM/palette after changing `images/explosion.png`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File images/Generate-ExplosionAssets.ps1
```

Run the regression from the repository's `Final_Project` directory:

```powershell
& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -do 'do ProjectFiles/FlappyBird/tests/run_boss_tnt.do'
```

The regression uses Quartus's Verilog export of the real `Pipe_Object.bdf` and
the Intel ROM simulation library. It checks native cap geometry, the closed
wall, boss separation, mandatory offscreen TNT births and midpoint placement,
owner-specific first-burst opening, harmless explosion pixels, all four frames,
normal/ghost damage, scrolling at all 11 speed levels with/without turbo, pause
and restart. It also writes closed/open pixel renders to `work/boss-modelsim`.

The full Quartus build passes. Existing missing-pin and audio-clock constraint
warnings remain; test the gameplay on the board before treating it as verified
on hardware.
