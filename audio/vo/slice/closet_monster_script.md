# VO Script: Closet Monster (Scratching Behind the Wall)
## Call ID: call_closet_monster
## Truth: STAGED_HOSTAGE (appears as PRANK/AMBUSH)
## Duration: ~3-4 minutes
## Stress Profile: High tremor, erratic pitch, laugh loop at 3.2s intervals, muffled adult breathing in background

---

### NODE: start (Caller)
**Audio:** vo/slice/closet_monster_01_start.wav
**Text:** "911... 911, please... there's something in my house. In my closet."

### NODE: dispatcher_ask_location (Dispatcher)
**Audio:** (Dispatcher speaks - not recorded)
**Text:** "Ma'am, what's your address? Stay on the line with me."

### NODE: caller_location (Caller)
**Audio:** vo/slice/closet_monster_02_location.wav
**Text:** "742... 742 Maple Street. The old Henderson place. Please hurry, I can hear it *breathing*."

### NODE: dispatcher_reassure (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Officers are on the way. Can you tell me what you're hearing exactly?"

### NODE: caller_describe (Caller)
**Audio:** vo/slice/closet_monster_03_describe.wav
**Text:** "Scratching... like claws on wood. And breathing. Heavy, wet breathing. It's... it's *big*. Bigger than a person. My cat... Mr. Whiskers... he went in there and didn't come out."

### CHOICE: Ask about the cat (Profiler only)
**Text:** "You said your cat went in the closet?"
**Next:** caller_cat_details

### CHOICE: Ask about sounds
**Text:** "Can you hear anything else? Voices? Movement?"
**Next:** caller_more_sounds

### CHOICE: Tell her to hide
**Text:** "Get somewhere safe. Under a bed, in a bathroom. Lock the door."
**Next:** caller_hides

### NODE: caller_cat_details (Caller)
**Audio:** vo/slice/closet_monster_04_cat.wav
**Text:** "Mr. Whiskers... he's old. Fifteen years. He doesn't run from anything. But when that door opened... he didn't even hiss. Just *froze*. Like he knew."

### NODE: caller_more_sounds (Caller)
**Audio:** vo/slice/closet_monster_05_sounds.wav
**Text:** "There's... a smell. Copper. Blood. And something else. Rotten. Like old meat left in the sun. And the scratching stopped. Now it's just... silence. That's worse."

### NODE: caller_hides (Caller)
**Audio:** vo/slice/closet_monster_06_hiding.wav
**Text:** "Okay... okay. Bathroom. Down the hall. The lock works on this one. *whispering* I'm in. Locked. But the vent... the vent connects to the hallway. I can hear footsteps. Heavy. Slow."

### NODE: dispatcher_ask_details (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Stay quiet. Officers are two minutes out. Can you see the hallway from there?"

### NODE: caller_vent (Caller)
**Audio:** vo/slice/closet_monster_07_vent.wav
**Text:** "The vent cover... it's loose. Someone pried it off. From *inside* the wall. *pause* There's a face. In the vent. Watching me. It's not... it's not human. The eyes are too far apart. The mouth... too wide."

### NODE: caller_laugh_loop (Caller) — LOOP SEGMENT (3.2s)
**Audio:** vo/slice/closet_monster_08_laugh_loop.wav
**Text:** "*low, wet chuckle* Heh... heh... heh..."
**Loop:** 0.0s - 3.2s (repeats)

### NODE: background_breathing (Background isolate)
**Audio:** vo/slice/closet_monster_09_background_breathing.wav
**Text:** "*adult male breathing, muffled, pained*"
**Background tag:** adult_breathing

### NODE: caller_knock (Caller)
**Audio:** vo/slice/closet_monster_10_knock.wav
**Text:** "*loud banging on bathroom door* OPEN UP. POLICE. MA'AM, OPEN THE DOOR."

### NODE: dispatcher_verify (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "That's them! That's the officers. Open the door, ma'am!"

### NODE: caller_relief (Caller)
**Audio:** vo/slice/closet_monster_11_relief.wav
**Text:** "Officers... oh god. Officers! *sobbing* In the closet... in the vent... there's someone in the walls..."

### NODE: end_call (Auto)
**Audio:** vo/slice/closet_monster_12_end.wav
**Text:** "*line clicks, static*"

---

### VO Recording Notes:
- **Actor:** Female, late teens, genuine terror
- **Key tells for VSA:**
  - Tremor: High, erratic (genuine fear)
  - Pitch variance: High spikes at "breathing", "vent", "face"
  - Loop: Laugh segment repeats every 3.2s exactly
  - Background: Adult male breathing (muffled) throughout
  - Heart rate: Elevated, variable
- **Dead Frequency:** None (genuine call)
- **Recording quality:** Phone line compression, slight static