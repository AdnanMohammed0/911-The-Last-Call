# VO Script: Cut Line (Call From a Cut Line)
## Call ID: call_cut_line
## Truth: PARANORMAL (The Drowned Woman)
## Duration: ~3-4 minutes
## Stress Profile: EMF hum (50/60Hz), sub-bass, water sounds, flat tremor despite distress, looped water drips

---

### NODE: start (Caller)
**Audio:** vo/slice/cut_line_01_start.wav
**Text:** "*static-heavy* Nine... one... one? Can... can you hear me?"

### NODE: dispatcher_respond (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "This is 911. Ma'am, I can hear you. What's your emergency?"

### NODE: caller_location (Caller)
**Audio:** vo/slice/cut_line_02_location.wav
**Text:** "The... the lake house. 14 Blackwater Drive. Basement. I'm in the basement."

### NODE: dispatcher_ask_situation (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Ma'am, what's happening? Why are you in the basement?"

### NODE: caller_situation (Caller)
**Audio:** vo/slice/cut_line_03_situation.wav
**Text:** "The water... it came up so fast. The door... it's locked from the outside. I can't get out. It's so cold."

### NODE: dispatcher_reassure (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Stay calm. Officers are en route. Is there a window? Another way out?"

### NODE: caller_no_window (Caller)
**Audio:** vo/slice/cut_line_04_no_window.wav
**Text:** "No windows. Just... stone walls. And the water. It's up to my waist now. *shivering* I can't feel my legs."

### NODE: caller_history (Caller)
**Audio:** vo/slice/cut_line_05_history.wav
**Text:** "They said this house was empty. Abandoned. But I heard... singing. A woman. Singing lullabies. Under the water."

### CHOICE: Ask about the singing (Profiler)
**Text:** "Singing? What did it sound like?"
**Next:** caller_singing_details

### CHOICE: Ask about the door
**Text:** "Who locked the door? Was someone else there?"
**Next:** caller_door_locked

### CHOICE: Tell her to conserve energy
**Text:** "Save your strength. Keep talking to me. Help is coming."
**Next:** caller_conserve

### NODE: caller_singing_details (Caller)
**Audio:** vo/slice/cut_line_06_singing.wav
**Text:** "Soft. Sad. *humming a few notes* 'Hush now, little one, the water keeps you warm.' Over and over. The same verse. Every time. Exactly the same."

### NODE: caller_door_locked (Caller)
**Audio:** vo/slice/cut_line_07_door.wav
**Text:** "I don't know. I came down to check the sump pump. The door slammed. Lock clicked. *pause* The handle... it's hot. Burning hot. But the water is freezing."

### NODE: caller_conserve (Caller)
**Audio:** vo/slice/cut_line_08_conserve.wav
**Text:** "Yes... yes, ma'am. I'll... I'll stay on the line. *coughing* The water tastes like... iron. And salt. Like tears."

### NODE: caller_emf_hum (Background) — EMF INTERFERENCE
**Audio:** vo/slice/cut_line_09_emf_hum.wav
**Text:** "*50Hz electrical hum, rising in pitch*"
**Background tag:** emf_hum, sub_bass

### NODE: caller_water_drips (Background) — LOOP SEGMENT
**Audio:** vo/slice/cut_line_10_drips.wav
**Text:** "*drip... drip... drip... exactly 1.5s intervals*"
**Loop:** 0.0s - 6.0s (4 drips per cycle)

### NODE: caller_screams (Caller)
**Audio:** vo/slice/cut_line_11_screams.wav
**Text:** "SHE'S HERE. IN THE WATER. *gurgling* HER HANDS... COLD... SO COLD..."

### NODE: dispatcher_panic (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Ma'am! Ma'am, stay with me! Officers are breaking in!"

### NODE: caller_fades (Caller)
**Audio:** vo/slice/cut_line_12_fade.wav
**Text:** "*voice distorting, slowing down* Don't... let her... take... the others... *static*"

### NODE: end_call (Auto)
**Audio:** vo/slice/cut_line_13_end.wav
**Text:** "*DEAD FREQUENCY TONE — 60Hz rising to scream, then silence*"

---

### VO Recording Notes:
- **Actor:** Female, 30s, distorted/processed voice (underwater effect)
- **Key tells for VSA:**
  - Tremor: Abnormally LOW (flat) despite screaming — paranormal signature
  - EMF: Strong 50/60Hz hum + sub-bass throughout (Dead Frequency marker)
  - Loop: Water drips at exact 1.5s intervals
  - Background: EMF hum, sub-bass resonance
  - Heart rate: Impossibly steady at ~60 BPM (drowned state)
- **Dead Frequency:** YES — strong EMF interference, impossible location
- **Recording quality:** Heavy phone line degradation, compression artifacts, "underwater" filtering