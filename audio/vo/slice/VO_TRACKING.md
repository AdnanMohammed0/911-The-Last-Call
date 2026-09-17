# VO Tracking: 3 Slice Calls (P2-16)
## Status: SCRIPTS COMPLETE — AUDIO RECORDING PENDING

---

## Call 1: Closet Monster (call_closet_monster)
**Truth:** STAGED_HOSTAGE | **Duration:** ~3-4 min | **Actor:** Female, late teens

| File | Node | Duration | Status | Notes |
|------|------|----------|--------|-------|
| closet_monster_master.wav | Full mix | ~3:30 | ⏳ Pending | Master mix with phone compression |
| closet_monster_01_start.wav | start | ~5s | ⏳ Pending | "911... there's something in my house" |
| closet_monster_02_location.wav | caller_location | ~4s | ⏳ Pending | "742 Maple Street..." |
| closet_monster_03_describe.wav | caller_describe | ~8s | ⏳ Pending | Scratching, breathing, cat |
| closet_monster_04_cat.wav | caller_cat_details | ~6s | ⏳ Pending | Mr. Whiskers details |
| closet_monster_05_sounds.wav | caller_more_sounds | ~7s | ⏳ Pending | Copper smell, silence |
| closet_monster_06_hiding.wav | caller_hides | ~6s | ⏳ Pending | Bathroom, vent, footsteps |
| closet_monster_07_vent.wav | caller_vent | ~8s | ⏳ Pending | Face in vent |
| closet_monster_08_laugh_loop.wav | caller_laugh_loop | 3.2s | ⏳ Pending | **LOOP** — exact 3.2s repeat |
| closet_monster_09_background_breathing.wav | background_breathing | ~3:30 | ⏳ Pending | Adult male, muffled, continuous |
| closet_monster_10_knock.wav | caller_knock | ~3s | ⏳ Pending | Police knock |
| closet_monster_11_relief.wav | caller_relief | ~5s | ⏳ Pending | Sobbing relief |
| closet_monster_12_end.wav | end_call | ~2s | ⏳ Pending | Click, static |

**VSA Tells:** High tremor, erratic pitch, laugh loop 3.2s, adult breathing background, HR ~110

---

## Call 2: Cut Line (call_cut_line)
**Truth:** PARANORMAL (Drowned Woman) | **Duration:** ~3-4 min | **Actor:** Female, 30s (processed)

| File | Node | Duration | Status | Notes |
|------|------|----------|--------|-------|
| cut_line_master.wav | Full mix | ~3:30 | ⏳ Pending | Master with underwater filtering |
| cut_line_01_start.wav | start | ~4s | ⏳ Pending | Static-heavy "Nine one one?" |
| cut_line_02_location.wav | caller_location | ~5s | ⏳ Pending | "Lake house... basement" |
| cut_line_03_situation.wav | caller_situation | ~6s | ⏳ Pending | Water rising, locked door |
| cut_line_04_no_window.wav | caller_no_window | ~5s | ⏳ Pending | No windows, waist-deep |
| cut_line_05_history.wav | caller_history | ~6s | ⏳ Pending | Singing under water |
| cut_line_06_singing.wav | caller_singing_details | ~7s | ⏳ Pending | Lullaby snippet |
| cut_line_07_door.wav | caller_door_locked | ~6s | ⏳ Pending | Hot handle, freezing water |
| cut_line_08_conserve.wav | caller_conserve | ~5s | ⏳ Pending | Iron/salt taste |
| cut_line_09_emf_hum.wav | caller_emf_hum | ~3:30 | ⏳ Pending | **60Hz + sub-bass, continuous** |
| cut_line_10_drips.wav | caller_water_drips | 6.0s | ⏳ Pending | **LOOP** — 1.5s interval drips |
| cut_line_11_screams.wav | caller_screams | ~4s | ⏳ Pending | "She's here in the water" |
| cut_line_12_fade.wav | caller_fades | ~5s | ⏳ Pending | Distorting, slowing |
| cut_line_13_end.wav | end_call | ~3s | ⏳ Pending | **Dead Frequency tone** |

**VSA Tells:** FLAT tremor (paranormal), 60Hz EMF hum, sub-bass, 1.5s drip loop, HR ~60

---

## Call 3: Meat Truck (call_meat_truck)
**Truth:** AMBUSH | **Duration:** ~2-3 min | **Actor:** Male, 40s (trucker, calm)

| File | Node | Duration | Status | Notes |
|------|------|----------|--------|-------|
| meat_truck_master.wav | Full mix | ~2:30 | ⏳ Pending | Master with CB/road noise |
| meat_truck_01_start.wav | start | ~4s | ⏳ Pending | "They're everywhere! Guns!" |
| meat_truck_02_location.wav | caller_location | ~6s | ⏳ Pending | Old Hwy 9, mile 47 |
| meat_truck_03_describe.wav | caller_describe | ~7s | ⏳ Pending | 6-7 men, tactical, RPG |
| meat_truck_04_pulse.wav | caller_pulse | ~6s | ⏳ Pending | "Why am I not more scared?" |
| meat_truck_05_challenged.wav | caller_challenged | ~5s | ⏳ Pending | Flat affect response |
| meat_truck_06_rpg.wav | caller_rpg_confirm | ~6s | ⏳ Pending | RPG-7, Sons of the Dusk |
| meat_truck_07_run.wav | caller_run_option | ~5s | ⏳ Pending | Door jammed, accepted fate |
| meat_truck_08_ambush.wav | caller_ambush_start | ~6s | ⏳ Pending | Tactical advice to officers |
| meat_truck_09_pulse.wav | caller_steady_pulse | ~2:30 | ⏳ Pending | **72 BPM metronome, continuous** |
| meat_truck_10_gunfire.wav | caller_gunfire | ~8s | ⏳ Pending | Contact, decoy cruiser |
| meat_truck_11_final.wav | caller_final | ~4s | ⏳ Pending | Respectful "Good play" |
| meat_truck_12_end.wav | end_call | ~2s | ⏳ Pending | Gunshot, carrier tone |

**VSA Tells:** FLAT tremor (ambush), steady 72 BPM pulse, no fear micro-tremors

---

## Recording Requirements

### Technical Specs
- **Format:** WAV, 48kHz, 24-bit (master) → OGG Vorbis 128kbps (game)
- **Phone compression:** Apply IR convolution (telephone line impulse response)
- **Cut Line:** Additional underwater filtering (low-pass ~2kHz, resonance)
- **Meat Truck:** CB radio character + road/engine bed

### VSA Calibration
Each master file must be analyzed to generate:
1. Tremor curve (0-1 over normalized time)
2. Pitch variance curve (0-1 over normalized time)
3. Loop segment timestamps (validated against script)
4. Background tag timestamps
5. Baseline heart rate (BPM)

### Recording Schedule (Recommended)
| Session | Calls | Est. Time |
|---------|-------|-----------|
| 1 | Closet Monster | 2 hours |
| 2 | Cut Line | 2 hours |
| 3 | Meat Truck | 1.5 hours |
| **Total** | | **~5.5 hours** |

### Actors Needed
1. **Female, late teens** — genuine terror, emotional range
2. **Female, 30s** — voice processing experience helpful
3. **Male, 40s** — trucker vibe, combat vet calm

### Post-Production
- [ ] Noise reduction & normalization
- [ ] Phone line IR convolution
- [ ] Loop segment extraction & validation
- [ ] VSA curve generation (automated via tools/analyze_vo.gd)
- [ ] OGG encoding for game
- [ ] QA: VSA tells match script specifications

---

## Dependencies
- **P2-01/P2-02:** CallData/DialogueGraph resources (DONE)
- **P2-06:** Patience timer integration (DONE)
- **P2-08:** VSA system (needs CallData.stress_profile)
- **Audio pipeline:** Phone bus, OGG streaming (exists)

---

## Next Steps
1. Cast actors / schedule sessions
2. Record all 39 segments
3. Process audio per specs
4. Run VSA analysis tool
5. Update StressProfile .tres with generated curves
6. Integrate into CallData resources
7. Test in DispatchTerminal with VSA UI