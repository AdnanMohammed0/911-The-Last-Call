# Full Mix Pass — 911: The Last Call (P4-13)

## Overview
This document describes the complete audio mix strategy, bus routing, level balancing, and integration points for all audio systems. Target platform: PC (Steam), stereo headphones and speakers, with future console consideration.

---

## 1. Bus Architecture (14 buses)

| Index | Bus | Purpose | Default Vol | Key FX Chain |
|-------|-----|---------|-------------|--------------|
| 0 | **Master** | Final output limiter | 0 dB | Limiter (ceiling -1 dB, lookahead 2 ms) |
| 1 | **Music** | Dynamic music, stingers, drones | -6 dB | Compressor (2:1, -12 dB), EQ (gentle high shelf -2 dB @ 8 kHz) |
| 2 | **Ambience** | Layered environmental beds | -12 dB | Reverb (room 0.8, damp 0.3, wet -15 dB), EQ (HP 40 Hz) |
| 3 | **Foley** | Footsteps, interactions, equipment | -3 dB | Compressor (3:1, -18 dB), EQ (dip -3 dB @ 2 kHz for voice clarity) |
| 4 | **SFX** | Gunshots, explosions, impacts | 0 dB | Compressor (4:1, -10 dB, fast attack), EQ (LP 16 kHz) |
| 5 | **Phone** | Caller audio, VSA spectrum source | 0 dB | SpectrumAnalyzer (1024 FFT), EQ (HP 300 Hz, LP 3400 Hz), Distortion (drive 0.15) |
| 6 | **VoiceProximity** | Proximity voice chat (3D) | 0 dB | EQ (HP 200 Hz, LP 6 kHz), Reverb (room 0.4, damp 0.5, wet -10 dB) |
| 7 | **VoiceRadio** | Radio voice chat (2D, processed) | +3 dB | BandPass (300-3000 Hz), Distortion (drive 0.3), Compressor (6:1, -6 dB) |
| 8 | **Record** | Microphone capture (muted) | 0 dB (muted) | AudioEffectCapture (16 kHz mono) |
| 9 | **Panic** | Sanity-driven horror bus | 0 dB | LowPassFilter (cutoff via SanitySystem), Reverb (room 0.6, wet -8 dB), Distortion (drive 0.2) |
| 10 | **UI** | Menu sounds, HUD beeps | -6 dB | EQ (LP 12 kHz) |
| 11 | **RadioChatter** | NPC radio, dispatch chatter | -10 dB | BandPass (300-3000 Hz), Distortion (drive 0.25), Reverb (room 0.3, wet -12 dB) |
| 12 | **VHS** | Global VHS post-process (optional) | 0 dB | EQ (tilt), Distortion (drive 0.1), PitchShift (-0.02 semitones) |

### Send Structure
All buses → Master (post-fader). No bus-to-bus sends except:
- Phone → Panic (pre-fader, -20 dB) for sanity bleed-through
- VoiceRadio → Panic (pre-fader, -24 dB) for radio hallucinations
- Ambience → VHS (pre-fader, -30 dB) for global VHS texture

---

## 2. Loudness Targets (EBU R128 / ITU-R BS.1770)

| Content | Target LUFS | True Peak | Notes |
|---------|-------------|-----------|-------|
| **Master Mix** | -14 LUFS (integrated) | -1 dBTP | Steam/PC standard |
| **Music/Stingers** | -18 LUFS (short-term) | -2 dBTP | Ducked under dialogue |
| **Ambience** | -24 LUFS (momentary) | -3 dBTP | Continuous bed |
| **Foley/SFX** | -16 LUFS (short-term) | -1 dBTP | Transient-heavy |
| **Voice (Proximity)** | -16 LUFS | -1 dBTP | Matches game dialogue |
| **Voice (Radio)** | -14 LUFS | -1 dBTP | Compressed for intelligibility |
| **Phone/Caller** | -16 LUFS | -1 dBTP | Telephone bandwidth |
| **UI** | -20 LUFS | -3 dBTP | Non-diegetic, unobtrusive |

### Metering
- **Integrated**: Full session (target -14 LUFS)
- **Short-term (3s)**: Gameplay moments (music/stingers)
- **Momentary (400ms)**: Transients (gunshots, scares)
- **True Peak**: Never exceed -1 dBTP on Master

---

## 3. Dynamic Mix Systems

### 3.1 Sanity-Driven Panic Bus (GAMEPLAY_MECHANICS §3.2)
```
cutoff_hz = lerp(20000.0, 800.0, 1.0 - sanity / 100.0)
reverb_wet_db = lerp(-20.0, -6.0, 1.0 - sanity / 100.0)
distortion_drive = lerp(0.0, 0.3, 1.0 - sanity / 100.0)
```
**Bands:**
- Steady (70-100%): cutoff 20 kHz, no FX
- Uneasy (40-69%): cutoff 8-12 kHz, subtle reverb
- Panicked (15-39%): cutoff 2-5 kHz, audible reverb + distortion
- Broken (0-14%): cutoff 800 Hz, heavy reverb + distortion + radio bleed

### 3.2 Tension Director Music System (ARCHITECTURE §9.3)
- **tension 0.0-0.3**: Ambient drone only (station/field/horror)
- **tension 0.3-0.6**: Tension Low stingers (cooldown 60s)
- **tension 0.6-0.8**: Tension Medium stingers (cooldown 45s)
- **tension 0.8-1.0**: Tension High stingers (cooldown 30s), Ambient Drone Horror
- **Scare triggers**: Immediate, priority interrupt, cooldown 20-40s
- **Resolution**: Plays on state change, ducks tension for 5-10s

### 3.3 Distance Attenuation (Foley/SFX/Voice)
| Source | Model | Min Dist | Max Dist | Rolloff |
|--------|-------|----------|----------|---------|
| Footsteps | Inverse | 0.5 m | per-surface | 1.0 |
| Foley (equip/weapon) | Inverse | 0.3 m | 3-8 m | 1.2 |
| Gunshots | Inverse | 2.0 m | 60 m | 0.8 |
| Explosions | Inverse | 5.0 m | 50 m | 0.6 |
| Voice Proximity | Inverse | 0.5 m | 20 m | 1.0 |
| Voice Radio | None (2D) | N/A | N/A | N/A |
| Ambience | None (2D) | N/A | N/A | N/A |

### 3.4 Class-Based Foley Modifiers (GAMEPLAY_MECHANICS §2.1)
| Class | Footstep Mult | Foley Mult | Breathing |
|-------|---------------|------------|-----------|
| Tech Operator | 0.8× | 0.9× | Quiet |
| Profiler | 1.0× | 1.0× | Normal |
| Breacher | 1.6× | 1.2× | Heavy (shield) |
| Medic | 0.9× | 1.0× | Normal |

---

## 4. Content Specifications

### 4.1 Ambience Tracks (12 locations × layered)
Each track: 4-7 layers (looping bed + oneshots)
- **Station (3)**: Ops Room, Garage, Armory — analog warmth, HVAC, radio chatter
- **Field Normal (4)**: Suburban, Suburban Tense, Warehouse, Highway — crickets, wind, distant city
- **Field Horror (3)**: Quarry, Quarry Ritual, Flooded House — water, EMF, chanting, reality thinning
- **Special (2)**: Station Siege, Aftermath Quiet — emergency lights, generator dying / coffee, paperwork

**Layer specs**: 48 kHz / 24-bit WAV, seamless loops (power-of-2 samples), oneshots with 3+ variations.

### 4.2 Foley Definitions (76 sounds)
Categories:
- **Footsteps (21)**: 7 surfaces × 3 movement types (walk/sprint/crouch), 4 variations each
- **Doors (7)**: open, close, peek, kick, locked, breach charge, ram
- **Equipment (10)**: radio, flashlight, bodycam, armor, belt, medkit, handcuffs
- **Weapons (13)**: pistol/shotgun/rifle draw/holster/reload/dry, shield deploy/impact, tear gas, drone
- **Interactions (10)**: button, keycard, keypad, pickup/drop, cuff, revive, shovel, salt, EMF, tone
- **Environment (8)**: glass/wood/metal break, body fall, explosion, RPG, generator, power fluctuation

**Specs**: 48 kHz / 24-bit WAV, -3 to +4 dB peak, 3-4 variations, pitch randomization ±5%.

### 4.3 Music Stingers (19 stingers)
Categories:
- **Tension (3)**: Low/Med/High — intensity ramp, layerable
- **Scare (3)**: Subtle/Major/Anomaly — priority interrupt, non-layerable
- **Resolution (3)**: Minor/Major/Failure — ducks tension, emotional weight
- **Ambient Drones (4)**: Station/Field/Horror/Siege — persistent beds, loopable
- **Transitions (3)**: Deploy/Extract/Aftermath — one-shots, bridge phases
- **Endings (3)**: Whistleblowers/Siege/LostInStatic — full themes, ending-only

**Specs**: 48 kHz / 24-bit WAV, -12 to 0 dB, 2-3 alternates for variety, tailored fade curves.

### 4.4 Existing VO/Caller Audio (P2-16)
- 3 slice calls: Closet Monster (12 segments), Cut Line (13), Meat Truck (12)
- Phone bus processing: HP 300 / LP 3400 Hz, subtle distortion, spectrum analyzer tap
- StressProfile curves drive VSA UI (deterministic, authored)

---

## 5. Integration Points

### 5.1 Code Hooks
```gdscript
# Footsteps (Player.gd)
NoiseSystem.emit_footstep(pos, sprinting, crouching, class_multiplier)
AudioServer.play_foley(&"footstep_concrete_walk", pos, class_mod)

# Doors (Door.gd)
NoiseSystem.emit_door_noise(pos, action)
AudioServer.play_foley(&"door_kick", pos)

# Weapons (WeaponHolder.gd)
AudioServer.play_foley(&"weapon_shotgun_rack", pos)
AudioServer.play_sfx(&"gunshot_shotgun", pos)

# Sanity (SanitySystem.gd)
AudioServer.set_bus_effect_param(9, "LowPassFilter", "cutoff_hz", cutoff)
AudioServer.set_bus_effect_param(9, "Distortion", "drive", drive)

# Tension Director (TensionDirector.gd)
MusicManager.request_stinger(&"tension_medium")
MusicManager.set_ambient_drone(&"ambient_drone_field")

# Voice (VoiceManager.gd)
# Automatic bus routing: proximity → VoiceProximity, radio → VoiceRadio
```

### 5.2 EventBus Signals (for audio reactions)
- `noise_event` → Foley/SFX playback + AI hearing
- `hallucination` → Scare stinger + Panic bus pulse
- `sanity_damaged` → Panic bus parameter update
- `phase_changed` → Ambient drone crossfade
- `ending_resolved` → Ending theme playback

---

## 6. Mix Validation Checklist

### 6.1 Technical
- [ ] All audio 48 kHz / 24-bit WAV (import settings: Compress=Vorbis, Quality=0.8, Loop=as needed)
- [ ] No clipping on Master bus at max gameplay intensity (4 players, combat, scare)
- [ ] True peak ≤ -1 dBTP on all bussed content
- [ ] Integrated loudness -14 LUFS ±1 on full playthrough
- [ ] Mono compatibility check (sum to mono, no phase cancellation)
- [ ] Headphone & speaker translation verified

### 6.2 Gameplay
- [ ] Caller audio intelligible on Phone bus at all sanity levels
- [ ] Voice chat (proximity + radio) clear over music/ambience/SFX
- [ ] VSA spectrum analyzer receives clean Phone bus signal
- [ ] Footstep class modifiers audible (Breacher louder, Tech quieter)
- [ ] Sanity Panic bus audible progression across 4 bands
- [ ] Tension music ramps correctly with Tension Director
- [ ] Scare stingers interrupt cleanly, don't stack
- [ ] Resolution stingers duck tension appropriately
- [ ] Ambient drones crossfade smoothly on phase/location change
- [ ] Ending themes play full, uninterrupted

### 6.3 Content Coverage
- [ ] All 7 surfaces have footstep sets (concrete, wood, dirt, metal, water, carpet, gravel)
- [ ] All door actions have foley (open, close, peek, kick, locked, breach, ram)
- [ ] All weapon types have draw/holster/reload/dry (pistol, shotgun, rifle)
- [ ] All class abilities have foley (shield, drone, tear gas, handcuffs, medkit, shovel, salt, EMF, tone)
- [ ] All environment interactions covered (glass, wood, metal, body, explosion, RPG, generator, power)
- [ ] All locations have ambience tracks with transition paths defined
- [ ] All tension/scare/resolution triggers mapped to game events

---

## 7. Asset Naming Convention
```
audio/
├── ambience/
│   ├── station_ops_room_base.wav
│   ├── station_crt_hum.wav
│   └── field_suburban_crickets.wav
├── foley/
│   ├── footsteps/
│   │   ├── concrete_walk_01.wav
│   │   └── concrete_walk_02.wav
│   ├── doors/
│   │   ├── door_open_01.wav
│   │   └── door_kick_01.wav
│   ├── equipment/
│   ├── weapons/
│   ├── interactions/
│   └── environment/
├── music/
│   ├── stingers/
│   │   ├── tension_low_01.wav
│   │   └── scare_major_01.wav
│   ├── ambient/
│   │   ├── station_drone_01.wav
│   │   └── horror_drone_01.wav
│   ├── transitions/
│   │   └── dispatch_to_field_01.wav
│   └── endings/
│       ├── whistleblowers_01.wav
│       └── siege_01.wav
├── vo/
│   └── slice/
│       ├── closet_monster_01_start.wav
│       └── cut_line_01_start.wav
└── buses/
    └── audio_buses.cfg
```

---

## 8. Implementation Priority

| Phase | Tasks | Dependencies |
|-------|-------|--------------|
| **1. Bus Setup** | Add 14 buses to project.godot, configure FX chains | — |
| **2. Ambience System** | AmbienceManager autoload, crossfade logic, location triggers | Bus 2 (Ambience) |
| **3. Foley System** | FoleyManager, surface detection, class modifiers, variation picker | Bus 3 (Foley), NoiseSystem |
| **4. Music System** | MusicManager, Tension Director integration, stinger queue, drone crossfade | Bus 1 (Music), TensionDirector |
| **5. Panic Bus** | SanitySystem → Panic bus parameter automation | Bus 9 (Panic), SanitySystem |
| **6. Phone/Voice** | Verify Phone bus VSA tap, VoiceProximity/Radio routing, squelch | Bus 5,6,7,8,11 |
| **7. Content Import** | Import all WAVs, set loop points, create .tres resources | All buses |
| **8. Mix Pass** | Playtest, level balance, loudness verification, fix issues | All content |
| **8. QA** | 2/3/4 player mix test, headphone/speaker, Steam Deck | Complete mix |

---

## 9. Accessibility (P4-14 coordination)
- **Subtitle support**: All caller VO, radio chatter, key foley cues
- **Volume sliders per bus**: Master, Music, Ambience, Foley, SFX, Voice, UI
- **Mono mix option**: Sum all buses to mono for single-ear/hearing impaired
- **Reduced dynamic range**: Compressor on Master (4:1, -8 dB) toggle
- **Visual audio cues**: VSA already provides visual stress analysis; add subtitle markers for scare stingers

---

## 10. References
- GAMEPLAY_MECHANICS §3.2 (Sanity bands), §4 (Global Meters), §5.3 (VSA/Phone), §7 (Noise), §10 (Missions)
- ARCHITECTURE §6 (Voice), §9.3 (Tension Director), §10 (Coding Standards)
- PROJECT_ROADMAP P4-13, P4-14, P4-11 (VHS post-process)