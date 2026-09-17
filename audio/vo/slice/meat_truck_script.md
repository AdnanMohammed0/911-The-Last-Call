# VO Script: The Meat Truck
## Call ID: call_meat_truck
## Truth: AMBUSH (Cult ambush)
## Duration: ~2-3 minutes
## Stress Profile: Flat tremor, steady pitch, stable heart rate (72 BPM) despite "screaming" — classic ambush tell

---

### NODE: start (Caller)
**Audio:** vo/slice/meat_truck_01_start.wav
**Text:** "911! 911! They're everywhere! Guns! They've got guns!"

### NODE: dispatcher_ask_location (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Sir, where are you? What's your location?"

### NODE: caller_location (Caller)
**Audio:** vo/slice/meat_truck_02_location.wav
**Text:** "Old Highway 9. Mile marker 47. The... the abandoned stretch. My truck broke down. Refrigerator unit died. Meat's spoiling."

### NODE: dispatcher_ask_details (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "How many armed individuals? Can you describe them?"

### NODE: caller_describe (Caller)
**Audio:** vo/slice/meat_truck_03_describe.wav
**Text:** "Six... maybe seven. Tactical gear. Black. No insignia. Rifles. One has an RPG. *pause* They're circling the truck. Just watching."

### NODE: dispatcher_reassure (Dispatcher)
**Audio:** (Dispatcher speaks)
**Text:** "Stay in the cab. Lock the doors. Keep the engine off. Units are responding Code 3."

### NODE: caller_pulse (Caller)
**Audio:** vo/slice/meat_truck_04_pulse.wav
**Text:** "They know I'm calling. One... one just looked right at me. Through the windshield. Smiled. *nervous laugh* Why am I not more scared?"

### CHOICE: Challenge the calm (Profiler - Lie Detector)
**Text:** "You sound remarkably calm for someone surrounded by gunmen."
**Next:** caller_challenged

### CHOICE: Ask about the RPG
**Text:** "You said RPG? Are you certain?"
**Next:** caller_rpg_confirm

### CHOICE: Tell him to run
**Text:** "Can you get out the passenger side? Run for the treeline?"
**Next:** caller_run_option

### NODE: caller_challenged (Caller)
**Audio:** vo/slice/meat_truck_05_challenged.wav
**Text:** "*flat, no tremor* Calm? I'm not calm. I'm a professional. I haul meat. Dead things don't scream. *long pause* Neither do I."

### NODE: caller_rpg_confirm (Caller)
**Audio:** vo/slice/meat_truck_06_rpg.wav
**Text:** "Yes. RPG-7. Wooden crate behind the second vehicle. Marked with a symbol. Red circle. Black sun. *pause* Sons of the Dusk. You've heard of them."

### NODE: caller_run_option (Caller)
**Audio:** vo/slice/meat_truck_07_run.wav
**Text:** "Passenger door's jammed. Driver's side only. They'd cut me down before I cleared the cab. *matter of fact* I've accepted it. Just... tell my wife. Route 9, mile 47. Meat truck."

### NODE: caller_ambush_start (Caller)
**Audio:** vo/slice/meat_truck_08_ambush.wav
**Text:** "They're moving. Forming up. *sound of rifle bolts cycling* This is it. *steady* Tell the officers... approach from the north. Dirt road. They won't expect it."

### NODE: caller_steady_pulse (Background)
**Audio:** vo/slice/meat_truck_09_pulse.wav
**Text:** "*heartbeat: steady 72 BPM, metronome-perfect*"
**Background tag:** steady_pulse

### NODE: caller_gunfire (Caller)
**Audio:** vo/slice/meat_truck_10_gunfire.wav
**Text:* *loud gunfire, RPG whoosh* CONTACT! NORTH SIDE! THEY HAVE A DECOY! *more gunfire* THE CRUISER... IT'S EMPTY! *laughs* CLEVER. CLEVER BASTARDS."

### NODE: caller_final (Caller)
**Audio:** vo/slice/meat_truck_11_final.wav
**Text:* *calm, almost respectful* Good play. Good play. *gunshot, static*"

### NODE: end_call (Auto)
**Audio:** vo/slice/meat_truck_12_end.wav
**Text:* *line goes dead, carrier tone*"

---

### VO Recording Notes:
- **Actor:** Male, 40s, trucker voice, unnervingly calm
- **Key tells for VSA:**
  - Tremor: FLAT/near-zero throughout (acting/ambush tell)
  - Pitch variance: Minimal even during "gunfire"
  - Heart rate: Impossibly steady 72 BPM (metronome)
  - No fear micro-tremors in "screaming" segments
  - Background: Steady pulse, no panic breathing
- **Ambush signature:** Abnormally stable vitals despite reported life-threatening situation
- **Recording quality:** CB radio / phone hybrid, road noise, engine hum in background