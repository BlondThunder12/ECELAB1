# Flappy Bird TODO

Work through one milestone at a time. Finish the screens before adding gameplay
features. The timer is optional, and pickup speeds still need a decision.

## Already implemented

- [x] Start screen with logo, instructions, and synchronized bird/logo bobbing.
- [x] Rulebook image, toggled with `0` from the start or paused state.
- [x] Start with `8`; pause/resume with `/`.
- [x] Updated pipe-edge image and MIF.

## 1. Finish the screens — next

- [x] Draw and implement the pause overlay with “Paused,” the resume key, and `0` for the rulebook. The 128 x 64 image is drawn opaque at 2x size, centered at (192, 176).
- [x] Group start, rulebook, and pause rendering into one `screens_draw` module/symbol in the top BDF. It receives `game_state` from `game_manager` and outputs one drawing request/RGB pair to `objects_mux`.
- [x] Draw and implement `images/gameOverScreen.png`: opaque 128 x 96 panel displayed at 4x at (64, 48), giving 512 x 384 screen pixels, with arcade dotted lines and PRESS ENTER TO RESTART. At 999, RTL replaces its header with YOU HAVE BEAT / THE GAME using a small constant font; no second panel PNG is needed.
- [x] Latch the final score when a run ends and update the best score before the next run resets the current score. Keep the best score between runs until board reset or power-off. Only increment the current score during PLAYING.
- [x] Keep the existing end-screen flow: Enter returns to START_SCREEN, then 8 starts the next run. Add only the score-999 victory condition to the game manager's ending conditions.
- [x] Choose end-screen behavior: centered panel; best score lasts until reset/power-off; Enter returns to the start menu; reaching 999 ends the run with a congratulations panel; exclude any run that used Godmode from best scores; highlight the BEST number on a new record, without extra banner artwork.
- [x] Make the current score saturate at 999. Track Godmode use for the whole run; toggling Godmode off before dying must not make that run eligible for a best score. Save the final score for every run, including Godmode runs.
- [x] In `game_manager`, end PLAYING when the score reaches 999, including in Godmode. Reuse GAME_OVER as the end-of-run state; the end-screen renderer selects victory artwork when the captured final score is 999. Freeze gameplay and keep Enter returning to the start menu for either outcome.
- [x] Regenerate custom `numbers.mif` from `images/numbers.png`, preserving original glyph pixels in centered 16 x 32 cells; use the same asset in the HUD and end screen. Both display 32 x 64 digit cells; the HUD uses bright magenta (E3) digits for visibility during day and night.
- [x] Add the game-over renderer inside `screens_draw` and update the project/screen-block inputs as needed; the shared screen connection to `objects_mux` is already in place.
- [ ] Check the complete flow on the board: start → play → pause → rules → resume → game over → restart. Opening/closing rules while paused must keep the game paused.

## 2. Make scrolling consistent

- [x] Make the ground scroll at the same speed as the pipes, including difficulty levels, turbo, and fractional movement, using the existing `scrollStep` and `scrollUpdate` signals.
- [x] Use the frame-driven pipe update for movement; freeze scrolling during pause/game over and reset it for a new run.
- [ ] Verify matched ground/pipe motion on the board at each difficulty and in turbo, including pause/resume and restart.

## 3. Build the shared pickup system — hearts first, coins and ghost next

- [x] Use `Items_Control.bdf` (renamed from the former heart-display block) for shared pickup control, movement, collection, the existing random generator, and one bitmap ROM. `pickup_control` stores three independent item slots; hearts and coins are enabled.
- [x] Convert `images/icons.png` into `pickups.mif`: four 32 x 32 cells ordered coin, heart, TNT, ghost. Index zero is transparent; opaque white is preserved. Hearts and coins are used now; TNT/ghost behavior remains to be added.
- [x] Latch each item's type and select its ROM tile. Emit one collection pulse plus its type; life/score/boss effects remain separate from drawing. Coin scoring is connected; forced TNT and ghost effects still need implementation.
- [x] Spawn at X=672 only when a suitable horizontal gap has room for the whole item and clearance from the pipe caps. Choose roughly half the gaps, with at most one item per gap; latch Y near the preceding pipe's opening. Pipe recycling never repositions an existing pickup.
- [x] Collect each pickup once, remove it immediately, and emit one collection pulse. Freeze pickups during pause and clear them for a new run.
- [x] Enable coin pickups using the existing sprite/MIF and shared heart/coin spawn path. Rewards for difficulty levels **0..10** are **2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15** points, using the level at collection time. Add a simultaneous pipe point, saturate at **999** and preserve the existing victory/high-score flow. Keep the reward table in `scoreModule.sv` for easy edits.
- [ ] Verify coin appearance, collection and level-based rewards on the board, including pause/resume and the 999-point victory.
- [x] Update the pickup asset generator and shared ROM for the updated `images/icons.png`: four 32 x 32 cells ordered coin, heart, TNT, ghost. Preserve the existing tile indices and extend `pickups.mif`/ROM depth from 3072 to 4096 entries.
- [ ] Add the ghost pickup: grant **3 seconds of invulnerability**. Keep this pickup effect separate from the Godmode switch and its `godmode_active` / `run_used_godmode` score flags. Collecting a ghost must leave the run eligible for high scores; using the Godmode switch still disqualifies it.
- [x] Match the actual pipe movement step, including fractional movement, difficulty and turbo. Independent item speeds remain a possible later feature; TNT timing still needs implementation.
- [ ] Verify on the board that pickups enter smoothly from the right. If another Signal Tap capture is needed, trigger on `itemSpawn[0]` rising and confirm `itemXPositions[10..0]` is 672. Preserve `Incorrect_item_spawning.stp` for the bug report.

## 4. Add lives and heart pickups

- [x] Start each run with **3 lives**, shown as three 32 x 32 hearts at the top left. Use `Items_Control.bdf` and `HartsMatrixBitMap` with the new heart icon.
- [x] Normal pipe/ceiling/ground collisions remove **1 life**, followed by **1 second of invulnerability** at 31.5 MHz. Collision masks remain active while the rendered bird blinks.
- [x] Give surviving hits a short recoil and inward border bounce, retaining flap control. Freeze recovery and the cooldown while paused.
- [x] Spawn a pickup in roughly half the spaces between pipes, randomly choosing a heart or coin. Latch a random position near the preceding opening, follow pipe speed/turbo and collect once. Hearts restore **1 life**, capped at **3**; full-health hearts disappear without adding a fourth life.
- [x] At zero lives, show the game-over panel immediately while the bird falls to the ground behind it. Preserve Godmode and Enter returning to the menu.
- [ ] Verify the new hearts, damage recovery, pause and final fall on the board after a full compile/program.

## 5. Add boss pipes and TNT

TNT replaces the previously planned key. Suggested behavior: collecting it
automatically triggers a cosmetic explosion on its associated boss and reveals
the fixed opening. No manual detonation button is needed for the first version.

- [ ] Randomly select boss pipes, with **at least 5 normal pipes between bosses**. Track this across pipe recycling, not just physical pipe instances.
- [ ] Start a boss pipe closed (**gap = 0**), using the pipe itself rather than a separate door. Make collision detection match the closed shape.
- [ ] Spawn its TNT at a random, reachable position between the preceding pipe and that boss. Associate the TNT with the correct boss and allow enough time to collect it and open the pipe at maximum speed.
- [x] Prepare explosion artwork: `images/explosion.png`, four 32 x 32 frames in a 128 x 32 transparent PNG, ordered small burst, large burst, smoke, fading smoke. Generated artwork is exported with 10 opaque colors and binary alpha, ready for MIF conversion.
- [ ] On TNT collection, play the explosion and reveal a fixed opening with a gap of roughly **240 pixels**. Choose the opening center, duration, and when the gap becomes passable. Keep drawing and collision geometry synchronized, freeze the animation while paused, and keep the explosion itself non-damaging.
- [ ] Make hitting a closed boss end the run immediately, regardless of remaining lives. Clear the boss/TNT state when that pipe is recycled and when starting a new run.

## 6. Optional: countdown timer and clock pickups

Proposed behavior: start at 2:00, cap remaining time at 2:00, add 10 seconds per
clock pickup, and end the run at 0:00. Confirm this behavior before implementation.

- [ ] Build an accurate one-second tick from the actual clock frequency; do not assume the frame rate from old comments.
- [ ] Count down only while playing. Freeze during pause and reset to **120 seconds** for a new run.
- [ ] Display **MM:SS** on four board seven-segment digits, reusing the existing display logic where practical.
- [ ] Add a clock pickup using the shared pickup system: **+10 seconds**, capped at **120**. Define the result when collection and a countdown tick happen together.

## 7. Final integration

- [ ] Update the rulebook and on-screen instructions for the completed features.
- [ ] Check reset/restart, pause/resume, repeated collisions/collections, scoring, and TNT/explosion timing at every difficulty level and in turbo mode. Use focused simulations for the new gameplay logic, then test on the board.
- [ ] Run a full Quartus compile, check timing and memory usage, program the board, and save a working archive/checkpoint.
