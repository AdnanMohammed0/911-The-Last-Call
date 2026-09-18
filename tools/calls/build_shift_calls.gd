## Builds the ten Shift 1 calls in data/calls/shift1/ from compact branching scripts.
##   godot --headless --path . -s res://tools/calls/build_shift_calls.gd
## Node format:   [id, speaker, line, choices]            choices = Array of [text, next, options]
##                [id, speaker, line, "next_id", delay]    auto-advance (no choices)
##                [id, speaker, line]                      terminal node (call ends)
##                any of the above + a trailing {"events": [&"dispatch_units"]} dictionary
## Events: &"dispatch_units" sends the team (what they find follows the call's truth),
##         &"dispatch_arrest" sends the team to arrest a prank caller.
## Choice options: {"class": &"profiler", "needs": [&"evidence"], "reveals": [&"evidence"], "patience": -20.0}
## Authority: TOOLS
extends SceneTree

# Authoring data is loosely typed nested arrays; the validator below checks the result.
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration")

const OUT_DIR: String = "res://data/calls/shift1"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var calls: Array[CallData] = [
		_highway_crash(), _cut_line(), _meat_truck(), _lost_child(), _drowned_voice(),
		_domestic(), _gas_station(), _church_bells(), _overdose(), _last_call(),
		_deputy_down(), _home_invasion(), _school_threat(), _barn_fire(), _diner_hostage(),
	]
	var failures: int = 0
	for call: CallData in calls:
		var result: Dictionary = CallValidator.validate(call)
		var errors: PackedStringArray = result["errors"]
		var err: Error = ResourceSaver.save(call, "%s/%s.tres" % [OUT_DIR, call.id])
		print("%s %s nodes=%d errors=%s" % ["SAVE" if err == OK else "FAIL", call.id, call.dialogue.nodes.size(), errors])
		if err != OK or not errors.is_empty():
			failures += 1
	quit(failures)


# --- Builders ---------------------------------------------------------------------------------

func _call(meta: Dictionary, script: Array) -> CallData:
	var call: CallData = CallData.new()
	call.id = meta["id"]
	call.title = meta["title"]
	call.truth = meta["truth"]
	call.earliest_minute = meta["minute"]
	call.caller_name = meta.get("caller", "Unknown Caller")
	call.phone_number = meta.get("phone", "911-555-0100")
	call.caller_location_name = meta.get("location", "")
	call.true_location = meta.get("true_location", Vector2.ZERO)
	call.patience_seconds = meta.get("patience", 180.0)
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"start"
	var nodes: Array[DialogueNode] = []
	for entry: Array in script:
		nodes.append(_node(entry))
	graph.nodes = nodes
	call.dialogue = graph
	var profile: StressProfile = StressProfile.new()
	var tremor: Curve = Curve.new()
	var calm: float = meta.get("tremor_start", 0.3)
	var panic: float = meta.get("tremor_end", 0.6)
	tremor.add_point(Vector2(0.0, calm))
	tremor.add_point(Vector2(1.0, panic))
	profile.tremor_curve = tremor
	var loops: Array[Vector2] = []
	for loop: Vector2 in meta.get("loops", []):
		loops.append(loop)
	profile.loop_segments = loops
	var tags: Array[StringName] = []
	for tag: StringName in meta.get("tags", []):
		tags.append(tag)
	profile.background_tags = tags
	profile.baseline_heart_rate = meta.get("bpm", 90)
	profile.emf_frequency = meta.get("emf", 0.0)
	call.stress_profile = profile
	var records: Array[RecordEntry] = []
	for record_data: Array in meta.get("records", []):
		var record: RecordEntry = RecordEntry.new()
		record.id = record_data[0]
		record.title = record_data[1]
		record.content = record_data[2]
		records.append(record)
	call.records = records
	return call


func _node(raw: Array) -> DialogueNode:
	var entry: Array = raw.duplicate()
	var node: DialogueNode = DialogueNode.new()
	if not entry.is_empty() and entry[entry.size() - 1] is Dictionary:
		var options: Dictionary = entry.pop_back()
		var events: Array[StringName] = []
		for event_name: StringName in options.get("events", []):
			events.append(event_name)
		node.on_enter_events = events
	node.id = entry[0]
	node.speaker = entry[1]
	node.line = entry[2]
	if entry.size() >= 4:
		if entry[3] is String or entry[3] is StringName:
			node.auto_next = StringName(entry[3])
			node.auto_delay = entry[4] if entry.size() >= 5 else 4.0
		else:
			var choices: Array[DialogueChoice] = []
			for choice_data: Array in entry[3]:
				choices.append(_choice(choice_data))
			node.choices = choices
	return node


func _choice(data: Array) -> DialogueChoice:
	var choice: DialogueChoice = DialogueChoice.new()
	choice.text = data[0]
	choice.next = data[1]
	var options: Dictionary = data[2] if data.size() >= 3 else {}
	choice.required_class = options.get("class", &"")
	choice.patience_delta = options.get("patience", 0.0)
	var needs: Array[StringName] = []
	for key: StringName in options.get("needs", []):
		needs.append(key)
	choice.required_evidence = needs
	var reveals: Array[StringName] = []
	for key: StringName in options.get("reveals", []):
		reveals.append(key)
	choice.reveals = reveals
	return choice


# --- 1. Highway crash (GENUINE) ------------------------------------------------------------------

func _highway_crash() -> CallData:
	return _call({
		"id": &"call_highway_crash", "title": "Route 9 Crash", "truth": CallData.Truth.GENUINE, "minute": 2,
		"caller": "Daniel Reyes", "phone": "911-555-0187", "location": "Route 9, near mile marker 14",
		"true_location": Vector2(620, 140), "patience": 200.0, "bpm": 128, "tremor_start": 0.55, "tremor_end": 0.8,
		"tags": [&"engine_hiss", &"rain"],
		"records": [[&"rec_route9", "Route 9 — mile 12-16", "Three fatal crashes this year. Deer crossing zone, no lighting after mile 11."]],
	}, [
		["start", "caller", "Oh God— my car went off the road, I'm in a ditch, there's glass everywhere—", [
			["Stay with me. Where exactly are you?", "where", {"patience": 10.0}],
			["Are you hurt?", "injuries"],
			["Is anyone else in the vehicle?", "passenger"],
		]],
		["where", "caller", "Route 9, heading north... I passed a green sign, fourteen maybe? It's so dark out here.", [
			["Mile marker fourteen. Can you see any lights or buildings?", "lights", {"reveals": [&"mile_14"]}],
			["Are you hurt?", "injuries"],
			["[Tech] Keep your phone on — I'm pinging your location.", "trace", {"class": &"tech", "reveals": [&"gps_ping"]}],
		]],
		["trace", "dispatcher", "(The ping resolves: 300 m north of mile 14, in the tree line — not on the road.)", "where_off_road", 3.5],
		["where_off_road", "caller", "The tree line? No, no, I was on the road... how did I get this far in?", [
			["Did something hit your car?", "hit"],
			["Are you hurt?", "injuries"],
		]],
		["lights", "caller", "Nothing. Just trees. Wait... there's a light moving between them. Like a flashlight.", [
			["Don't call out to it. Stay in the car.", "stay_quiet", {"reveals": [&"moving_light"]}],
			["It might be another driver. Flash your headlights.", "headlights", {"patience": -15.0}],
		]],
		["headlights", "caller", "Okay... it stopped. It's... it's coming towards me. Why is it so fast?", [
			["Lock your doors and get low. Now.", "stay_quiet", {"reveals": [&"moving_light"]}],
		]],
		["stay_quiet", "caller", "(whispering) Okay. Okay. My leg is stuck under the dash. I can't run anyway.", [
			["Is it bleeding?", "injuries"],
			["Units are on the way, I'll stay on the line.", "end_units"],
		]],
		["injuries", "caller", "My leg... it's pinned, there's a lot of blood on my jeans. It's warm.", [
			["[Medic] Is the blood pulsing or flowing steadily?", "medic_bleed", {"class": &"medic"}],
			["Press something against it, hard.", "pressure", {"patience": 10.0}],
			["Is anyone else in the vehicle?", "passenger"],
		]],
		["medic_bleed", "caller", "It's... pulsing. It comes in pushes.", [
			["[Medic] Arterial. Take your belt off and tie it above the wound, tight as you can.", "tourniquet", {"class": &"medic", "reveals": [&"arterial_bleed"], "patience": 25.0}],
		]],
		["tourniquet", "caller", "(straining) It's... it's tight. It's slowing down. I feel dizzy.", [
			["Good. Keep talking to me. Is anyone else with you?", "passenger"],
			["Help is coming, stay awake.", "end_units"],
		]],
		["pressure", "caller", "I'm using my jacket. It's soaking through.", [
			["Keep pressing. Is anyone else in the vehicle?", "passenger"],
		]],
		["passenger", "caller", "My wife, Ana— she was right here. The passenger door is open. She's not here.", [
			["Did she get out to find help?", "wife_help"],
			["Can you see her outside?", "wife_look", {"patience": -10.0}],
			["[Profiler] Daniel, what was the last thing she said?", "wife_last", {"class": &"profiler"}],
		]],
		["wife_help", "caller", "She wouldn't leave me. She wouldn't. Not without saying something.", [
			["Can you see her outside?", "wife_look"],
			["Units are on the way. Stay in the car.", "end_units"],
		]],
		["wife_last", "caller", "She said... 'Somebody's standing in the road.' Then we swerved.", [
			["Someone was in the road? Describe them.", "hit", {"reveals": [&"figure_in_road"]}],
		]],
		["hit", "caller", "Tall. Wet. Like they'd come out of the river. We didn't hit them — they just... weren't there after.", [
			["Stay in the car, doors locked. Units are coming.", "end_units", {"reveals": [&"figure_in_road"]}],
		]],
		["wife_look", "caller", "(a door creaks) Ana? ...Ana, is that you? Why are you standing like that—", "end_line_dead", 3.0],
		["end_line_dead", "dispatcher", "(Something scrapes across the car roof. The line goes dead.)"],
		["end_units", "caller", "Please hurry. The rain's getting in. I can hear the river.", {"events": [&"dispatch_units"]}],
	])


# --- 2. Cut line (AMBUSH) ------------------------------------------------------------------------

func _cut_line() -> CallData:
	return _call({
		"id": &"call_willow_court", "title": "Willow Court Whisper", "truth": CallData.Truth.AMBUSH, "minute": 7,
		"caller": "Unknown Caller", "phone": "911-555-0133", "location": "22 Willow Court",
		"true_location": Vector2(300, 410), "patience": 150.0, "bpm": 64, "tremor_start": 0.1, "tremor_end": 0.12,
		"loops": [Vector2(2.0, 5.5)], "tags": [&"steady_breathing", &"engine_idle"],
		"records": [
			[&"rec_willow_22", "22 Willow Court", "Bank-owned since March. Utilities disconnected. No registered occupants."],
			[&"rec_decoy_calls", "Decoy call pattern", "Two deputies wounded in 2019 after a fake break-in call to a vacant address."],
		],
	}, [
		["start", "caller", "(whispering) There's someone in my house. They're downstairs. Please.", [
			["What's your address?", "address"],
			["Where are you hiding?", "hiding"],
			["[Profiler] Keep whispering. Tell me what you hear.", "listen", {"class": &"profiler"}],
		]],
		["address", "caller", "22 Willow Court. Please send everyone, all of them.", [
			["[Tech] Checking the address on the county database.", "tech_address", {"class": &"tech", "reveals": [&"vacant_address"]}],
			["How many people are in the house?", "how_many"],
			["Where are you hiding?", "hiding"],
		]],
		["tech_address", "dispatcher", "(County records: 22 Willow Court is bank-owned. Power cut off since March.)", "tech_after", 3.5],
		["tech_after", "caller", "(still whispering) Why aren't you saying anything? Are they coming?", [
			["Ma'am, the power at that address was cut months ago. How is your phone charging?", "confront_power", {"needs": [&"vacant_address"], "patience": -30.0}],
			["Where are you hiding?", "hiding"],
		]],
		["confront_power", "caller", "(pause) ...I have a battery. Just send the units. Send all of them.", [
			["[Profiler] Your breathing hasn't changed once. You're not scared.", "profiler_calm", {"class": &"profiler", "reveals": [&"calm_breathing"]}],
			["Units are on the way.", "end_dispatch"],
		]],
		["profiler_calm", "caller", "(a man's voice in the background, close to the phone) 'She's made us. Hang up.'", "end_click", 3.0],
		["hiding", "caller", "In the upstairs closet. I can hear them on the stairs.", [
			["Describe the house. What's across the hall?", "house"],
			["How many people are in the house?", "how_many"],
		]],
		["house", "caller", "Uh... the bathroom. And the kids' room. The stairs creak... the fourth step.", [
			["You have kids? Where are they?", "kids", {"patience": 10.0}],
			["[Profiler] Listen for me — is anything running in the background?", "listen", {"class": &"profiler"}],
		]],
		["kids", "caller", "They're... at their grandmother's. Just send someone.", [
			["Which grandmother? I can check on them too.", "grandmother", {"reveals": [&"evasive_answer"]}],
			["Units are on the way.", "end_dispatch"],
		]],
		["grandmother", "caller", "It doesn't matter! Stop asking questions and send the police!", "end_dispatch", 3.0],
		["how_many", "caller", "Three. Maybe four. They have guns, I saw rifles.", [
			["You saw rifles from inside a closet?", "rifles", {"reveals": [&"inconsistent_story"], "patience": -15.0}],
			["Stay hidden. Units are coming.", "end_dispatch"],
		]],
		["rifles", "caller", "I— before. I saw them through the window before I hid.", [
			["[Profiler] That sentence sounds rehearsed.", "listen", {"class": &"profiler"}],
			["Units are on the way.", "end_dispatch"],
		]],
		["listen", "dispatcher", "(Behind her: an idling engine, and the same whispered sentence repeating a second time.)", "listen_after", 4.0],
		["listen_after", "caller", "There's someone in my house. They're downstairs. Please.", [
			["That's the exact same recording. Who am I really talking to?", "confront_loop", {"reveals": [&"looped_audio"], "patience": -40.0}],
			["Units are on the way.", "end_dispatch"],
		]],
		["confront_loop", "unknown", "(A man laughs softly.) 'Just send the cars, dispatcher. We're waiting.'", "end_click", 3.0],
		["end_click", "dispatcher", "(Click. The line is cut.)"],
		["end_dispatch", "caller", "(whispering) Thank you. Tell them to come to the front door.", {"events": [&"dispatch_units"]}],
	])


# --- 3. Meat truck (GENUINE) ----------------------------------------------------------------------

func _meat_truck() -> CallData:
	return _call({
		"id": &"call_harbor_truck", "title": "Refrigerated Truck", "truth": CallData.Truth.GENUINE, "minute": 12,
		"caller": "Walt Hendricks", "phone": "911-555-0161", "location": "Harbor warehouse district, Pier 4",
		"true_location": Vector2(820, 520), "patience": 220.0, "bpm": 104, "tremor_start": 0.45, "tremor_end": 0.7,
		"tags": [&"reefer_compressor", &"harbor_wind", &"knocking"],
		"records": [[&"rec_pier4", "Pier 4 cold storage", "Leased to 'Blackvale Meats LLC' — company dissolved 2021. Two noise complaints this month."]],
	}, [
		["start", "caller", "Yeah, I'm a trucker, I'm parked at the harbor... there's a refrigerated box truck here and somebody's banging inside it.", [
			["Banging from inside? Are you sure?", "banging"],
			["Where exactly are you?", "where"],
			["Is anyone guarding the truck?", "guards"],
		]],
		["banging", "caller", "Listen— (metal knocking, three, then three again) Hear that? That's people.", [
			["[Profiler] That's a pattern. Knock three times back on the door.", "knock_back", {"class": &"profiler", "patience": 10.0}],
			["Don't go near it. Is anyone guarding it?", "guards"],
			["Can you read the plate or the company name?", "plate"],
		]],
		["knock_back", "caller", "(knock, knock, knock) ...Three back. And a voice. A kid's voice. Oh no. Oh no no.", [
			["Can you open the back?", "open_truck", {"reveals": [&"people_inside"], "patience": -10.0}],
			["Don't open it. Are there armed men nearby?", "guards", {"reveals": [&"people_inside"]}],
		]],
		["open_truck", "caller", "There's a padlock. I've got bolt cutters in my rig, I could—", [
			["Do it, carefully.", "cut_lock", {"patience": -20.0}],
			["Wait. Check if anyone's watching you first.", "guards"],
		]],
		["cut_lock", "caller", "(a car door slams somewhere) Somebody's coming out of the warehouse. They've got guns.", [
			["Get back in your truck and drive away. Now.", "end_flee"],
			["Hide and tell me how many.", "count_guards", {"patience": 10.0}],
		]],
		["guards", "caller", "Two cars by the warehouse door. Guys smoking out front. One's got a rifle under his coat.", [
			["How many men total?", "count_guards"],
			["Stay out of sight. What's written on the truck?", "plate"],
		]],
		["count_guards", "caller", "Four outside... there's light upstairs in the office too. Maybe more in there.", [
			["[Tech] What's the warehouse number? I'll pull the lease.", "tech_lease", {"class": &"tech", "reveals": [&"dissolved_company"]}],
			["Good work. Get somewhere safe, units are rolling.", "end_units", {"reveals": [&"armed_suspects"]}],
		]],
		["tech_lease", "dispatcher", "(Lease record: Blackvale Meats LLC, dissolved in 2021. Nobody should be storing anything here.)", "end_units", 4.0],
		["plate", "caller", "'Blackvale Meats'. Plate starts K-7... I can't see the rest, it's covered in mud.", [
			["Covered on purpose. How many men are there?", "count_guards", {"reveals": [&"hidden_plate"]}],
		]],
		["where", "caller", "Pier 4, by the old cold storage. There's containers everywhere.", [
			["Is anyone guarding the truck?", "guards"],
			["Banging from inside? Are you sure?", "banging"],
		]],
		["end_flee", "caller", "(engine starts) I'm out, I'm out. Please, get those people out of that box.", {"events": [&"dispatch_units"]}],
		["end_units", "caller", "Please hurry. It's freezing in there. They won't last all night.", {"events": [&"dispatch_units"]}],
	])


# --- 4. Lost child at the mall (PRANK) ------------------------------------------------------------

func _lost_child() -> CallData:
	return _call({
		"id": &"call_lost_child", "title": "Lost at the Mall", "truth": CallData.Truth.PRANK, "minute": 17,
		"caller": "Brianna", "phone": "911-555-0112", "location": "Blackvale Mall, food court",
		"true_location": Vector2(500, 260), "patience": 120.0, "bpm": 96, "tremor_start": 0.2, "tremor_end": 0.25,
		"loops": [Vector2(1.0, 3.2)], "tags": [&"teen_laughter", &"bedroom_music"],
		"records": [
			[&"rec_mall_hours", "Blackvale Mall", "Closes at 21:00. Security guard on site until 06:00."],
			[&"rec_number_0112", "911-555-0112", "Four prank calls in 30 days. Registered to the Keller family, 8 Aspen Drive."],
		],
	}, [
		["start", "caller", "Hi, um, I'm like, lost? At the mall? And my mom's gone and there's a scary man. (muffled giggle)", [
			["Stay where you are. Units are on the way.", "units_mall"],
			["What time is it where you are?", "time"],
			["Describe the man.", "man"],
			["What's your full name and address?", "name"],
		]],
		["time", "caller", "It's like... two in the afternoon?", [
			["It's the middle of the night. The mall closed hours ago.", "caught_time", {"reveals": [&"wrong_time"], "patience": -20.0}],
			["Describe the man.", "man"],
		]],
		["caught_time", "caller", "(background: 'Bri, she knows, hang up!') N-no, I mean, I got locked in!", [
			["[Tech] Your number is registered to 8 Aspen Drive.", "tech_number", {"class": &"tech", "reveals": [&"home_address"]}],
			["Locked in? Then describe the store you're in front of.", "store"],
		]],
		["store", "caller", "Um... the... pizza one. Pizza Planet.", [
			["There's no Pizza Planet in Blackvale Mall.", "end_confess", {"patience": -30.0}],
		]],
		["man", "caller", "He's got, like, a big hat and he's super tall and he's got... (laughter) sorry, sorry—", [
			["[Profiler] Who's laughing next to you, Brianna?", "profiler_friends", {"class": &"profiler", "reveals": [&"friends_present"]}],
			["What time is it where you are?", "time"],
		]],
		["profiler_friends", "caller", "Nobody! It's the TV! (music in the background suddenly stops)", [
			["Mall food courts don't have TVs you can turn off. You're at home.", "end_confess", {"needs": [&"friends_present"]}],
			["What's your full name and address?", "name"],
		]],
		["name", "caller", "Brianna... Smith. I live at... the mall.", [
			["[Tech] Checking this number's history.", "tech_number", {"class": &"tech", "reveals": [&"home_address"]}],
			["Brianna, calling 911 as a joke is a crime.", "end_confess", {"patience": -10.0}],
		]],
		["tech_number", "dispatcher", "(Four prank calls from this number this month. Registered to the Keller family.)", "tech_after", 3.0],
		["tech_after", "caller", "(whispering off the phone) 'How does she know my house?'", [
			["Brianna Keller. A deputy can visit your parents tonight.", "end_confess", {"needs": [&"home_address"]}],
		]],
		["units_mall", "caller", "(whispers 'they're actually sending cops!') ...Okay, thanks! (click)", {"events": [&"dispatch_units"]}],
		["end_confess", "caller", "(crying) Okay, okay, I'm sorry, it was a dare! Please don't tell my mom!", [
			["A deputy is coming to Aspen Drive. You're under arrest for a false report.", "arrest_sent"],
			["This is your only warning. I'm logging this as a prank call.", "warned", {"patience": 10.0}],
		]],
		["arrest_sent", "dispatcher", "(Deputies dispatched to 8 Aspen Drive. The line clicks — she hung up.)", {"events": [&"dispatch_arrest"]}],
		["warned", "caller", "Thank you, thank you, it won't happen again. (click)"],
	])


# --- 5. The drowned voice (PARANORMAL) ------------------------------------------------------------

func _drowned_voice() -> CallData:
	return _call({
		"id": &"call_drowned_voice", "title": "Reservoir Payphone", "truth": CallData.Truth.PARANORMAL, "minute": 22,
		"caller": "Margaret Hale", "phone": "911-555-0199", "location": "Blackvale Reservoir, south road payphone",
		"true_location": Vector2(180, 90), "patience": 160.0, "bpm": 40, "tremor_start": 0.05, "tremor_end": 0.9,
		"emf": 50.0, "tags": [&"water_drip", &"emf_hum"],
		"records": [
			[&"rec_hale_1987", "Margaret Hale, 1987", "Drowned in Blackvale Reservoir, 14 Nov 1987. Body recovered 3 days later. Case closed: accident."],
			[&"rec_payphone", "Reservoir payphone", "Line disconnected by the phone company in 1994. Booth removed in 2003."],
		],
	}, [
		["start", "caller", "(water dripping) Hello? Please... the water is so cold. I can't find the shore.", [
			["Ma'am, are you in the water right now?", "in_water"],
			["What's your name?", "name"],
			["Where are you calling from?", "where"],
			["Stay by the phone, I'm sending a patrol car to the reservoir.", "patrol_sent"],
		]],
		["patrol_sent", "caller", "Thank you... tell them to walk out onto the ice. I'll be waiting. (water rushing, click)", {"events": [&"dispatch_units"]}],
		["in_water", "caller", "I was. I think I still am. It's so dark under the ice.", [
			["There's no ice this time of year.", "no_ice", {"patience": -10.0}],
			["Stay calm. What's your name?", "name"],
		]],
		["no_ice", "caller", "There was ice. November. The car went through the ice.", [
			["What year is it, ma'am?", "year", {"reveals": [&"november_ice"]}],
		]],
		["year", "caller", "(long silence) ...Nineteen eighty-seven. Isn't it?", [
			["[Tech] Run the caller name against the archive.", "tech_record", {"class": &"tech", "reveals": [&"hale_record"]}],
			["Who was with you in the car?", "car"],
		]],
		["name", "caller", "Margaret. Margaret Hale. My husband is waiting at home.", [
			["[Tech] Search the archive for Margaret Hale.", "tech_record", {"class": &"tech", "reveals": [&"hale_record"]}],
			["Where are you calling from?", "where"],
		]],
		["where", "caller", "The payphone. On the south road by the reservoir. I walked up out of the water.", [
			["[Tech] That payphone was disconnected in 1994.", "tech_phone", {"class": &"tech", "reveals": [&"dead_line"]}],
			["[Profiler] Margaret, I can hear a hum on the line. What's making it?", "profiler_hum", {"class": &"profiler", "reveals": [&"dead_frequency"]}],
		]],
		["tech_record", "dispatcher", "(Archive: Margaret Hale drowned in Blackvale Reservoir, November 14, 1987.)", "record_after", 4.0],
		["record_after", "caller", "Why did you go quiet? Are they coming for me?", [
			["Margaret... you died in 1987.", "told", {"needs": [&"hale_record"], "patience": -40.0}],
			["Who was with you in the car?", "car"],
		]],
		["tech_phone", "dispatcher", "(The call is live on a line that hasn't existed for thirty years.)", "where", 3.0],
		["profiler_hum", "caller", "The hum? That's the water. It sings when it wants someone.", [
			["Who does it want, Margaret?", "wants"],
		]],
		["wants", "caller", "Whoever answers. It wanted me. Now it knows your voice.", "end_static", 4.0],
		["car", "caller", "My husband was driving. He got out. He stood on the ice and watched.", [
			["He watched? He didn't help you?", "husband", {"reveals": [&"husband_watched"]}],
		]],
		["husband", "caller", "He said the water asked for someone. Better me than him.", "end_static", 4.0],
		["told", "caller", "(The dripping stops.) ...Then why is it still so cold? Send someone to bring me home.", "end_static", 4.0],
		["end_static", "dispatcher", "(The line fills with the sound of water rushing in. Then static.)"],
	])


# --- 6. Domestic disturbance (GENUINE) --------------------------------------------------------------

func _domestic() -> CallData:
	return _call({
		"id": &"call_domestic", "title": "Thin Walls", "truth": CallData.Truth.GENUINE, "minute": 27,
		"caller": "Rosa Delgado", "phone": "911-555-0145", "location": "Maple Heights Apartments, unit 3B",
		"true_location": Vector2(410, 330), "patience": 190.0, "bpm": 118, "tremor_start": 0.5, "tremor_end": 0.75,
		"tags": [&"shouting_through_wall", &"child_crying"],
		"records": [[&"rec_3c", "Maple Heights 3C", "Two prior welfare checks. Resident Kyle Brandt, restraining order violation 2023."]],
	}, [
		["start", "caller", "My neighbor, next door, he's screaming at her again and something just smashed. There's a baby in there.", [
			["What's the apartment number?", "unit"],
			["Can you still hear the woman?", "woman"],
			["Is there a weapon involved?", "weapon"],
		]],
		["unit", "caller", "I'm 3B, they're 3C. Kyle and Jess. He's been bad before.", [
			["[Tech] Pulling records for 3C.", "tech_record", {"class": &"tech", "reveals": [&"restraining_order"]}],
			["Can you still hear the woman?", "woman"],
		]],
		["tech_record", "dispatcher", "(Kyle Brandt, 3C: restraining order violation last year. Known firearm owner.)", "weapon", 3.5],
		["woman", "caller", "She's crying... she said 'put it down, Kyle'. Now it's quiet. It's too quiet.", [
			["Can you knock on the wall and ask if she's okay?", "knock", {"patience": -10.0}],
			["Is there a weapon involved?", "weapon"],
			["Stay inside your apartment, lock your door.", "stay"],
		]],
		["knock", "caller", "(knocking) Jess? Jess, you okay? ...Oh God, he's at my door. He's banging on MY door.", [
			["Don't open it. Get away from the door, into a back room.", "back_room", {"patience": 10.0}],
			["[Profiler] Put me on speaker. Let me talk to him through the door.", "negotiate", {"class": &"profiler"}],
		]],
		["negotiate", "unknown", "(through the door) 'Who you talking to? You called the cops on me?!'", [
			["[Profiler] Kyle, this is 911. Nobody's in trouble yet. Is Jess hurt?", "kyle_calm", {"class": &"profiler", "patience": 20.0}],
			["[Profiler] Kyle, deputies are already outside. Put the weapon down.", "kyle_angry", {"class": &"profiler", "patience": -30.0}],
		]],
		["kyle_calm", "unknown", "'...She fell. She fell, okay? I didn't— she needs a doctor. The baby won't stop.'", [
			["Kyle, leave the door open and wait in the hall with your hands empty.", "end_surrender", {"reveals": [&"victim_injured"]}],
		]],
		["kyle_angry", "unknown", "'You think I'm going back? Nobody's taking my kid!' (footsteps running away)", "end_barricade", 3.0],
		["weapon", "caller", "He's got a gun. I've seen it on his belt in the laundry room.", [
			["Stay inside, lock your door, stay low.", "stay", {"reveals": [&"armed_suspect"]}],
			["Can you still hear the woman?", "woman"],
		]],
		["back_room", "caller", "(whispering) I'm in the bathroom. He stopped banging. I hear the baby through the vent.", [
			["[Medic] Can you hear the woman breathing or moving?", "medic_listen", {"class": &"medic"}],
			["Units are almost there. Stay put.", "end_units"],
		]],
		["medic_listen", "caller", "There's... a groan. Like she's on the floor. She's alive, I think.", [
			["She'll need an ambulance. I'm sending one with the deputies.", "end_units", {"reveals": [&"victim_injured"]}],
		]],
		["stay", "caller", "Okay. Door's locked. Please hurry, the baby's still crying.", "end_units", 3.0],
		["end_surrender", "caller", "(through the wall) He's... he's sitting in the hall. He's actually doing it.", {"events": [&"dispatch_units"]}],
		["end_barricade", "caller", "He locked himself back in with them. Please. Please hurry.", {"events": [&"dispatch_units"]}],
		["end_units", "caller", "I see lights outside. Thank you. Thank you.", {"events": [&"dispatch_units"]}],
	])


# --- 7. Gas station robbery (DIVERSION) -------------------------------------------------------------

func _gas_station() -> CallData:
	return _call({
		"id": &"call_gas_station", "title": "Pump 6", "truth": CallData.Truth.DIVERSION, "minute": 32,
		"caller": "Unknown Caller", "phone": "911-555-0170", "location": "Quick Stop gas station, Highway 40 (north county)",
		"true_location": Vector2(700, 60), "patience": 140.0, "bpm": 76, "tremor_start": 0.2, "tremor_end": 0.2,
		"tags": [&"bank_alarm", &"traffic_downtown"],
		"records": [
			[&"rec_payphone_0170", "911-555-0170", "Payphone outside First Blackvale Savings, Main Street (south county)."],
			[&"rec_quickstop", "Quick Stop Highway 40", "Closed for renovation since August."],
		],
	}, [
		["start", "caller", "Armed robbery at the Quick Stop on Highway 40! Three guys with shotguns, they're shooting! Send everyone!", [
			["Are you inside the store?", "inside"],
			["How many people are hurt?", "hurt"],
			["[Tech] Tracing this call.", "trace", {"class": &"tech", "reveals": [&"payphone_downtown"]}],
		]],
		["inside", "caller", "I'm across the street, at... at the pumps. Pump 6. They're still in there!", [
			["Describe the getaway car.", "car"],
			["[Profiler] You're very calm for someone watching a shooting.", "profiler", {"class": &"profiler", "reveals": [&"too_calm"]}],
		]],
		["hurt", "caller", "The cashier, the cashier's down! Send all the units in the county!", [
			["All the units? Why all of them?", "all_units", {"patience": -10.0}],
			["Are you inside the store?", "inside"],
		]],
		["all_units", "caller", "Because they're— they've got a lot of guns! Just send them north, now!", [
			["[Profiler] Listen to what's behind him.", "listen", {"class": &"profiler", "reveals": [&"alarm_background"]}],
			["Units are heading north.", "end_diverted"],
		]],
		["trace", "dispatcher", "(Trace: payphone on Main Street, outside First Blackvale Savings — twenty miles south.)", "trace_after", 4.0],
		["trace_after", "caller", "Hello? Are they coming? Send them north!", [
			["You're calling from Main Street, not Highway 40.", "caught", {"needs": [&"payphone_downtown"], "patience": -30.0}],
		]],
		["listen", "dispatcher", "(Under his voice: a bell alarm ringing, and city traffic. No highway, no gunfire.)", "listen_after", 3.5],
		["listen_after", "caller", "Why are you waiting? People are dying!", [
			["That's a bank alarm behind you.", "caught", {"needs": [&"alarm_background"], "patience": -30.0}],
		]],
		["profiler", "caller", "Calm? I'm— I'm in shock, lady. Send the cops north.", [
			["Describe the getaway car.", "car"],
		]],
		["car", "caller", "Uh... a van. White. Or grey.", [
			["[Tech] That Quick Stop has been closed since August.", "closed", {"class": &"tech", "reveals": [&"store_closed"]}],
			["Units are heading north.", "end_diverted"],
		]],
		["closed", "caller", "(pause) ...Then I guess they're robbing an empty store. (laughs) Too late anyway.", "end_click", 3.0],
		["caught", "caller", "(a car horn, someone shouts 'let's go!') Enjoy the drive north, dispatch.", "end_click", 3.0],
		["end_click", "dispatcher", "(Click. Seconds later the Main Street bank alarm hits the silent-alarm board.)", [
			["All units to First Blackvale Savings, now!", "bank_units"],
			["Log the hoax and stay on the board.", "logged"],
		]],
		["bank_units", "dispatcher", "(Tactical units rerouted south to the bank.)", {"events": [&"dispatch_units"]}],
		["logged", "dispatcher", "(Hoax logged. The bank alarm keeps ringing.)"],
		["end_diverted", "caller", "Good. Good. (click)", {"events": [&"dispatch_units"]}],
	])


# --- 8. Church bells (AMBUSH, cult) -----------------------------------------------------------------

func _church_bells() -> CallData:
	return _call({
		"id": &"call_church_bells", "title": "St. Agnes Bells", "truth": CallData.Truth.AMBUSH, "minute": 37,
		"caller": "Father Lucas", "phone": "911-555-0108", "location": "St. Agnes Church, Old Mill Road",
		"true_location": Vector2(260, 180), "patience": 170.0, "bpm": 62, "tremor_start": 0.6, "tremor_end": 0.62,
		"loops": [Vector2(6.0, 12.0)], "tags": [&"chanting", &"many_breathing"],
		"records": [
			[&"rec_st_agnes", "St. Agnes Church", "Deconsecrated 2016. Father Lucas Moreno retired to Arizona in 2017."],
			[&"rec_mill_cult", "Old Mill Road sightings", "Hunters report robed groups gathering at night. Two missing hikers, 2024."],
		],
	}, [
		["start", "caller", "This is Father Lucas at St. Agnes. Men in robes broke into the church, they're holding the congregation. Please send every officer you have.", [
			["How many hostages?", "hostages"],
			["How are you calling without them noticing?", "how_calling"],
			["[Tech] Checking St. Agnes on the county register.", "tech_church", {"class": &"tech", "reveals": [&"deconsecrated"]}],
		]],
		["hostages", "caller", "Forty. Maybe fifty. Women, children. They're going to hurt them at midnight.", [
			["A midnight service? On a Tuesday?", "service", {"patience": -10.0}],
			["[Profiler] Father, your voice sounds perfectly steady.", "profiler_steady", {"class": &"profiler", "reveals": [&"steady_voice"]}],
		]],
		["how_calling", "caller", "I'm in the bell tower. They don't know I'm up here.", [
			["Ring the bell so the units can find you.", "bell", {"patience": 10.0}],
			["How many hostages?", "hostages"],
		]],
		["bell", "dispatcher", "(The bell rings once. Behind it, a crowd starts chanting in unison — right next to the phone.)", "bell_after", 4.0],
		["bell_after", "caller", "They're... praying. It's just the congregation praying. Send everyone.", [
			["That chanting is right beside you, not below you.", "confront", {"reveals": [&"chanting_close"], "patience": -30.0}],
			["Units are on the way.", "end_units"],
		]],
		["service", "caller", "It's a vigil. For the missing hikers. Please, there's no time.", [
			["[Tech] What were the hikers' names?", "hikers", {"class": &"tech"}],
			["Units are on the way.", "end_units"],
		]],
		["hikers", "caller", "(pause) ...God knows their names, my child.", [
			["You don't know who you're holding a vigil for.", "confront", {"reveals": [&"no_names"], "patience": -20.0}],
		]],
		["tech_church", "dispatcher", "(St. Agnes was deconsecrated in 2016. Father Lucas Moreno retired to Arizona in 2017.)", "tech_after", 4.0],
		["tech_after", "caller", "Why are you silent? They are sharpening the knives.", [
			["Father Lucas retired to Arizona. Who is this?", "confront", {"needs": [&"deconsecrated"], "patience": -40.0}],
			["How many hostages?", "hostages"],
		]],
		["profiler_steady", "caller", "The Lord gives me calm.", [
			["The Lord doesn't usually breathe through fifteen people behind you.", "confront", {"reveals": [&"many_breathing"]}],
		]],
		["confront", "unknown", "(The chanting stops all at once.) 'Then come anyway. We have made room for all of you.'", "end_click", 4.0],
		["end_click", "dispatcher", "(The line goes dead. The church bell starts ringing on its own, far away.)", [
			["Send the tactical team in anyway — carefully.", "tactical"],
			["Log it as an ambush and warn every unit away from Old Mill Road.", "warned"],
		]],
		["tactical", "dispatcher", "(Tactical team dispatched to St. Agnes with an ambush warning.)", {"events": [&"dispatch_units"]}],
		["warned", "dispatcher", "(All units warned. Old Mill Road is closed off until morning.)"],
		["end_units", "caller", "Bless you. Tell them to come in through the front doors. All of them.", {"events": [&"dispatch_units"]}],
	])


# --- 9. Overdose (GENUINE, medical) -----------------------------------------------------------------

func _overdose() -> CallData:
	return _call({
		"id": &"call_overdose", "title": "Blue Lips", "truth": CallData.Truth.GENUINE, "minute": 42,
		"caller": "Tyler", "phone": "911-555-0154", "location": "Pinecrest Motel, room 12",
		"true_location": Vector2(560, 380), "patience": 170.0, "bpm": 140, "tremor_start": 0.7, "tremor_end": 0.9,
		"tags": [&"motel_tv", &"gurgling_breath"],
		"records": [[&"rec_pinecrest", "Pinecrest Motel", "Six overdose calls this year, three fatal. Suspected fentanyl-laced supply."]],
	}, [
		["start", "caller", "My friend's not waking up, man, his lips are blue, I think he took something bad, please!", [
			["Is he breathing?", "breathing"],
			["What did he take?", "took"],
			["Where are you?", "where"],
		]],
		["where", "caller", "Pinecrest Motel, room twelve. Please, I don't want to get arrested, I just—", [
			["Nobody's arresting you for calling. Is he breathing?", "breathing", {"patience": 20.0}],
			["What did he take?", "took"],
		]],
		["took", "caller", "Pills. They were supposed to be Percs. They looked weird. Blue.", [
			["[Tech] Pinecrest has had fentanyl overdoses all year.", "tech", {"class": &"tech", "reveals": [&"fentanyl_risk"]}],
			["Is he breathing?", "breathing"],
		]],
		["tech", "dispatcher", "(Six overdose calls from Pinecrest this year. Counterfeit pills with fentanyl.)", "breathing", 3.0],
		["breathing", "caller", "He's making this snoring sound... like gurgling. Then nothing for a while.", [
			["[Medic] That's agonal breathing. Do you have Narcan? A nasal spray?", "narcan", {"class": &"medic", "reveals": [&"agonal_breathing"]}],
			["Roll him onto his side.", "recovery", {"patience": 10.0}],
			["Shake him and shout his name.", "shake"],
		]],
		["shake", "caller", "JAMES! James, wake up! ...Nothing. His eyes are rolled back.", [
			["[Medic] Do you have Narcan? A nasal spray?", "narcan", {"class": &"medic"}],
			["Roll him onto his side.", "recovery"],
		]],
		["recovery", "caller", "Okay, he's on his side, there's foam coming out of his mouth.", [
			["[Medic] Clear his mouth with your finger. Check for Narcan.", "narcan", {"class": &"medic", "patience": 10.0}],
			["Help is coming. Keep him on his side.", "end_units"],
		]],
		["narcan", "caller", "There's... yeah, there's a box in his bag, they gave it to him at the clinic.", [
			["[Medic] Tilt his head back, spray it all in one nostril.", "sprayed", {"class": &"medic", "patience": 30.0}],
		]],
		["sprayed", "caller", "I did it. I did it. ...Nothing's happening. Oh God, it's not working.", [
			["[Medic] It takes two to three minutes. Start chest compressions — hard, fast, center of his chest.", "cpr", {"class": &"medic"}],
			["Wait. Watch his chest.", "wait_narcan", {"patience": -20.0}],
		]],
		["cpr", "caller", "(counting, crying) one, two, three, four... he coughed! He's breathing! He's breathing!", [
			["[Medic] Stop compressions. Roll him on his side and don't let him use again tonight.", "end_saved", {"class": &"medic", "reveals": [&"patient_revived"]}],
		]],
		["wait_narcan", "caller", "He's... he's so grey. He's not moving at all.", [
			["Start pushing hard on the center of his chest, now.", "cpr"],
		]],
		["end_saved", "caller", "Thank you... thank you. I hear the ambulance. Thank you. (a door kicks open behind him) Wait— who are you guys?!", {"events": [&"dispatch_units"]}],
		["end_units", "caller", "Please hurry. He's so cold. (a door kicks open) Hey— that's not the ambulance—", {"events": [&"dispatch_units"]}],
	])


# --- 10. The last call (PARANORMAL) -----------------------------------------------------------------

func _last_call() -> CallData:
	return _call({
		"id": &"call_last_call", "title": "The Last Call", "truth": CallData.Truth.PARANORMAL, "minute": 80,
		"caller": "Blackvale County 911", "phone": "911-555-0004", "location": "Station 4 — Operations Room",
		"true_location": Vector2(400, 300), "patience": 200.0, "bpm": 44, "tremor_start": 0.9, "tremor_end": 0.1,
		"emf": 60.0, "loops": [Vector2(0.0, 4.0)], "tags": [&"dispatch_room_ambience", &"emf_hum", &"own_voice"],
		"records": [
			[&"rec_station4_1996", "Station 4 night shift, 1996", "Entire night crew missing after a final logged call at 05:00. Recording tape blank."],
		],
	}, [
		["start", "unknown", "(Your own voice, from the other end of the line.) 'Blackvale County 911, what is your emergency?'", [
			["Who is this?", "who"],
			["[Tech] Caller ID shows... this station.", "tech_id", {"class": &"tech", "reveals": [&"internal_line"]}],
			["Hang on. Everyone, be quiet for a second.", "quiet"],
		]],
		["who", "unknown", "'This is dispatch. You called us. You always call us at five o'clock.'", [
			["What's your emergency, then?", "emergency"],
			["[Profiler] It's repeating what I say before I say it.", "profiler_echo", {"class": &"profiler", "reveals": [&"echo_ahead"]}],
		]],
		["tech_id", "dispatcher", "(The call is coming from line 4 — the phone on the desk right next to you. The handset is in its cradle.)", "tech_after", 4.0],
		["tech_after", "unknown", "'Look at the phone on desk four. Go on. It's ringing for you.'", [
			["Don't touch it. Stay on this line.", "who"],
			["Check the other phone.", "other_phone", {"patience": -30.0}],
		]],
		["other_phone", "dispatcher", "(Desk four's phone is silent. But on your line you now hear the room you are standing in — your own breathing.)", "emergency", 4.0],
		["quiet", "dispatcher", "(The room goes silent. On the line, you hear the station's own clock ticking a second ahead of the one on the wall.)", "who", 4.0],
		["emergency", "unknown", "'The emergency is at Station 4. The night crew. They don't make it to six.'", [
			["What happens at six?", "six"],
			["[Tech] Search the archive for Station 4 incidents.", "archive", {"class": &"tech", "reveals": [&"crew_1996"]}],
			["Is this a threat?", "threat"],
		]],
		["profiler_echo", "unknown", "'...It's repeating what I say before I say it.' 'Yes. We've had this conversation many times.'", "emergency", 4.0],
		["archive", "dispatcher", "(1996: the Station 4 night crew vanished after a final call logged at 05:00. The tape was blank.)", "archive_after", 4.0],
		["archive_after", "unknown", "'The tape wasn't blank. It was this call. It's always this call.'", [
			["How do we stop it?", "stop", {"needs": [&"crew_1996"]}],
			["What happens at six?", "six"],
		]],
		["threat", "unknown", "'A warning. Warnings sound like threats when they come too late.'", [
			["What happens at six?", "six"],
		]],
		["six", "unknown", "'The last call ends. The line opens both ways. Something comes through the phone.'", [
			["How do we stop it?", "stop"],
		]],
		["stop", "unknown", "'Don't hang up first. Whoever hangs up first... stays on the line forever.'", "end_hold", 5.0],
		["end_hold", "dispatcher", "(Silence. Then, very softly, the sound of someone on the line waiting for you to hang up.)"],
	])


# --- 11. Deputy down (AMBUSH) -------------------------------------------------------------------------

func _deputy_down() -> CallData:
	return _call({
		"id": &"call_deputy_down", "title": "Deputy Down", "truth": CallData.Truth.AMBUSH, "minute": 47,
		"caller": "Deputy (radio patch)", "phone": "RADIO 7", "location": "Harbor access road, gate B",
		"true_location": Vector2(800, 470), "patience": 150.0, "bpm": 70, "tremor_start": 0.2, "tremor_end": 0.22,
		"loops": [Vector2(1.0, 4.0)], "tags": [&"radio_hiss", &"idle_trucks"],
		"records": [
			[&"rec_badge_4471", "Badge 4471", "No active deputy with badge 4471. Number retired in 2012 (Deputy K. Voss, killed on duty)."],
			[&"rec_gate_b", "Harbor gate B", "Unlit access road; two stolen box trucks recovered there last month."],
		],
	}, [
		["start", "caller", "(radio static) Dispatch, 4471, shots fired, I'm hit, harbor gate B, send everything you have!", [
			["4471, how bad is it?", "wound"],
			["4471, who's with you?", "partner"],
			["[Tech] Verify badge 4471.", "badge", {"class": &"tech", "reveals": [&"retired_badge"]}],
		]],
		["wound", "caller", "Leg, I'm bleeding bad, I'm behind my cruiser. There's four of them. Send everyone.", [
			["[Medic] Can you apply a tourniquet?", "medic", {"class": &"medic"}],
			["Units are on the way, hold on.", "end_units"],
			["[Profiler] Your voice is too steady for a leg wound, 4471.", "profiler", {"class": &"profiler", "reveals": [&"steady_voice"]}],
		]],
		["medic", "caller", "A what? Just— just send the units to gate B, all of them.", [
			["You're a deputy and you don't know what a tourniquet is?", "caught", {"reveals": [&"no_training"], "patience": -20.0}],
			["Units are on the way.", "end_units"],
		]],
		["partner", "caller", "My partner's down. Deputy... Miller. Send the ambulance and every car.", [
			["[Tech] There's no Deputy Miller on tonight's roster.", "caught", {"class": &"tech", "reveals": [&"fake_partner"]}],
			["Units are on the way.", "end_units"],
		]],
		["badge", "dispatcher", "(Badge 4471 was retired in 2012 after Deputy Voss was killed at the harbor.)", "badge_after", 4.0],
		["badge_after", "caller", "Dispatch? Dispatch, do you copy? Why aren't cars rolling?", [
			["Badge 4471 belonged to a dead deputy. Who is this?", "caught", {"needs": [&"retired_badge"], "patience": -30.0}],
			["Units are on the way.", "end_units"],
		]],
		["profiler", "caller", "(pause) ...Adrenaline. Stop wasting time.", [
			["Units are on the way.", "end_units"],
			["Say your call sign again.", "caught", {"patience": -10.0}],
		]],
		["caught", "unknown", "(another voice, close) 'Kill the radio.' (The static cuts out.)", [
			["Send tactical anyway, with an ambush warning.", "tactical"],
			["Log it as an ambush. Nobody goes to gate B.", "logged"],
		]],
		["tactical", "dispatcher", "(Tactical team rolling to gate B, weapons ready.)", {"events": [&"dispatch_units"]}],
		["logged", "dispatcher", "(Ambush logged. Harbor gate B closed to all units.)"],
		["end_units", "caller", "Copy. Tell them to come in fast, lights off. We'll be waiting.", {"events": [&"dispatch_units"]}],
	])


# --- 12. Home invasion (GENUINE) ----------------------------------------------------------------------

func _home_invasion() -> CallData:
	return _call({
		"id": &"call_home_invasion", "title": "Glass in the Kitchen", "truth": CallData.Truth.GENUINE, "minute": 52,
		"caller": "Harold Finch", "phone": "911-555-0122", "location": "22 Aspen Drive",
		"true_location": Vector2(320, 300), "patience": 170.0, "bpm": 132, "tremor_start": 0.6, "tremor_end": 0.85,
		"tags": [&"glass_breaking", &"male_voices_downstairs"],
		"records": [[&"rec_aspen_burglaries", "Aspen Drive burglaries", "Three armed home invasions this month. Suspects target elderly residents."]],
	}, [
		["start", "caller", "(elderly man, whispering) Someone broke the kitchen window. There are men in my house.", [
			["Where are you right now?", "where"],
			["How many men?", "how_many"],
			["Do you have a weapon in the house?", "weapon"],
		]],
		["where", "caller", "Upstairs bedroom. I locked the door. My wife is asleep next to me, she can't hear well.", [
			["Keep the door locked and stay away from it.", "stay", {"patience": 10.0}],
			["How many men?", "how_many"],
		]],
		["how_many", "caller", "Three voices. One said 'find the safe'. They have... I heard a gun being racked.", [
			["[Profiler] Can you hear what else they're saying?", "listen", {"class": &"profiler", "reveals": [&"armed_intruders"]}],
			["Units are on the way. Stay quiet.", "end_units", {"reveals": [&"armed_intruders"]}],
		]],
		["listen", "caller", "'The old man's upstairs. Check the garage first.' Oh God, they know we're here.", [
			["[Tech] Is there another way out of the bedroom?", "exit", {"class": &"tech"}],
			["Units are on the way. Stay quiet.", "end_units"],
		]],
		["exit", "caller", "The window... over the garage roof. I can't climb that. Not at my age.", [
			["Then barricade the door with the dresser.", "barricade", {"patience": 10.0}],
		]],
		["barricade", "caller", "(scraping) It's done. They're on the stairs.", "end_units", 3.0],
		["weapon", "caller", "My old service revolver. In the nightstand.", [
			["Only use it if they come through that door.", "stay"],
			["Leave it. Hide and wait for us.", "stay", {"patience": 10.0}],
			["[Profiler] Harold, is your wife awake now?", "wife", {"class": &"profiler"}],
		]],
		["wife", "caller", "She's awake. She's scared. She keeps asking why the dog isn't barking.", [
			["Where is the dog, Harold?", "dog", {"reveals": [&"silent_dog"]}],
			["Keep her calm and stay low. Units are on the way.", "end_units"],
		]],
		["dog", "caller", "...He was in the yard. He always barks. Oh God, why isn't he barking?", [
			["Stay in the bedroom. Don't go looking.", "stay", {"patience": -10.0}],
			["Units are on the way.", "end_units"],
		]],
		["stay", "caller", "Okay. Okay. Please hurry.", [
			["How many men?", "how_many"],
			["Units are on the way.", "end_units"],
		]],
		["end_units", "caller", "(a heavy thump on the bedroom door) Please— please hurry.", {"events": [&"dispatch_units"]}],
	])


# --- 13. School threat (PRANK) ------------------------------------------------------------------------

func _school_threat() -> CallData:
	return _call({
		"id": &"call_school_threat", "title": "Bomb at Blackvale High", "truth": CallData.Truth.PRANK, "minute": 57,
		"caller": "Unknown Caller", "phone": "911-555-0191", "location": "Blackvale High School",
		"true_location": Vector2(330, 290), "patience": 130.0, "bpm": 92, "tremor_start": 0.25, "tremor_end": 0.3,
		"loops": [Vector2(0.5, 2.5)], "tags": [&"video_game_audio", &"voice_changer"],
		"records": [
			[&"rec_number_0191", "911-555-0191", "Prepaid phone bought at Aspen Drive gas station. Used for two fake threats against Blackvale High."],
			[&"rec_exam", "Blackvale High", "Final exams scheduled 08:00 today."],
		],
	}, [
		["start", "caller", "(voice changer) There's a bomb in Blackvale High. It goes off at eight. This is not a joke.", [
			["Where is the device?", "where"],
			["Why are you doing this?", "why"],
			["[Profiler] Listen past the voice changer.", "listen", {"class": &"profiler", "reveals": [&"game_audio"]}],
		]],
		["where", "caller", "In the... the gym. No, the math wing. It's hidden. You'll never find it.", [
			["Which one? Gym or math wing?", "caught_story", {"reveals": [&"changing_story"], "patience": -10.0}],
			["Evacuating the school. Units are on the way.", "units_school"],
		]],
		["why", "caller", "Because... the system is broken. And stuff.", [
			["[Tech] Checking this number.", "tech", {"class": &"tech", "reveals": [&"prepaid_phone"]}],
			["Is there an exam at eight?", "exam", {"reveals": [&"exam_day"]}],
		]],
		["listen", "dispatcher", "(Under the voice changer: a video game menu jingle and a microwave beeping.)", "listen_after", 3.5],
		["listen_after", "caller", "Did you hear me? A bomb!", [
			["Pause your game, kid.", "end_confess", {"needs": [&"game_audio"], "patience": -20.0}],
			["Is there an exam at eight?", "exam"],
		]],
		["exam", "caller", "(the voice changer glitches — a teenage boy) N-no! Maybe! What does that matter?", "end_confess", 3.0],
		["tech", "dispatcher", "(Prepaid phone sold at the Aspen Drive gas station. Two previous fake threats against the high school.)", "caught_story", 4.0],
		["caught_story", "caller", "Uh... it moves. It's a moving bomb.", [
			["You're calling from a prepaid phone bought on Aspen Drive.", "end_confess", {"needs": [&"prepaid_phone"]}],
			["Evacuating the school. Units are on the way.", "units_school"],
		]],
		["units_school", "caller", "(laughing off-mic) 'They're evacuating!' ...Good. (click)", {"events": [&"dispatch_units"]}],
		["end_confess", "caller", "(voice changer off) Okay, okay! I just didn't want to take the exam! Don't call the cops!", [
			["I AM the cops. A deputy is coming to arrest you.", "arrest_sent"],
			["Log it as a prank and let the school know.", "logged"],
		]],
		["arrest_sent", "dispatcher", "(Deputies dispatched to the caller's address on Aspen Drive.)", {"events": [&"dispatch_arrest"]}],
		["logged", "dispatcher", "(Prank logged. School resource officer notified.)"],
	])


# --- 14. Barn fire (AMBUSH, cult) ----------------------------------------------------------------------

func _barn_fire() -> CallData:
	return _call({
		"id": &"call_barn_fire", "title": "Fire at Kessler Farm", "truth": CallData.Truth.AMBUSH, "minute": 62,
		"caller": "Ruth Kessler", "phone": "911-555-0138", "location": "Kessler Farm, County Road 12",
		"true_location": Vector2(120, 470), "patience": 160.0, "bpm": 66, "tremor_start": 0.4, "tremor_end": 0.42,
		"tags": [&"no_fire_sound", &"chanting_far"],
		"records": [
			[&"rec_kessler", "Kessler Farm", "Foreclosed 2019. Ruth Kessler (82) moved to Pine Hill care home. Property reported used for 'night gatherings'."],
		],
	}, [
		["start", "caller", "The barn's on fire, the whole barn! My husband is inside! Send the fire trucks and the police!", [
			["Is anyone hurt?", "hurt"],
			["Can you see the flames from where you are?", "flames"],
			["[Tech] Pulling the farm records.", "tech", {"class": &"tech", "reveals": [&"foreclosed_farm"]}],
		]],
		["hurt", "caller", "Walter's in there. He went in for the horses. Please, all of you, come now.", [
			["[Medic] Is he calling out? Can you hear him?", "medic", {"class": &"medic"}],
			["Units are on the way.", "end_units"],
		]],
		["medic", "caller", "No... it's quiet. It's very quiet.", [
			["A burning barn is loud. What do you hear?", "quiet", {"reveals": [&"no_fire_sound"], "patience": -10.0}],
		]],
		["flames", "caller", "Yes, huge flames, it's so hot out here.", [
			["[Profiler] There's no crackle, no wind, no horses. Just breathing.", "quiet", {"class": &"profiler", "reveals": [&"no_fire_sound"]}],
			["Units are on the way.", "end_units"],
		]],
		["tech", "dispatcher", "(Kessler Farm was foreclosed in 2019. Ruth Kessler lives in the Pine Hill care home.)", "tech_after", 4.0],
		["tech_after", "caller", "Why are you so slow? Walter is burning!", [
			["Ruth Kessler is in a care home. Who is this?", "quiet", {"needs": [&"foreclosed_farm"], "patience": -30.0}],
			["Units are on the way.", "end_units"],
		]],
		["quiet", "unknown", "(far away, many voices begin to chant) 'Bring the fire trucks. Bring the police. Bring all of them.'", [
			["Send tactical, fire service holds back.", "tactical"],
			["Log it as an ambush. Nobody goes near the farm.", "logged"],
		]],
		["tactical", "dispatcher", "(Tactical team dispatched to Kessler Farm with an ambush warning.)", {"events": [&"dispatch_units"]}],
		["logged", "dispatcher", "(Ambush logged. County Road 12 closed.)"],
		["end_units", "caller", "Good. Come to the barn. Walter will be so glad.", {"events": [&"dispatch_units"]}],
	])


# --- 15. Diner hostage (GENUINE) ------------------------------------------------------------------------

func _diner_hostage() -> CallData:
	return _call({
		"id": &"call_diner_hostage", "title": "Night Owl Diner", "truth": CallData.Truth.GENUINE, "minute": 67,
		"caller": "Maya (waitress)", "phone": "911-555-0177", "location": "Night Owl Diner, Harbor Road",
		"true_location": Vector2(760, 430), "patience": 180.0, "bpm": 136, "tremor_start": 0.7, "tremor_end": 0.9,
		"tags": [&"fryer_hiss", &"man_shouting"],
		"records": [[&"rec_night_owl", "Night Owl Diner", "Owner Gus Parra reported extortion threats from a harbor crew last week."]],
	}, [
		["start", "caller", "(whispering from a storage room) Men with guns came in, they've got Gus and two customers on the floor.", [
			["How many gunmen?", "count"],
			["Are you safe where you are?", "safe"],
			["What do they want?", "want"],
		]],
		["count", "caller", "Three inside. One by the door with a shotgun. There's a car running outside.", [
			["[Tech] Can you see the plate of the car?", "plate", {"class": &"tech", "reveals": [&"getaway_car"]}],
			["Stay hidden. Units are on the way.", "end_units", {"reveals": [&"armed_suspects"]}],
		]],
		["safe", "caller", "I'm in the storage room behind the kitchen. The door doesn't lock.", [
			["Wedge something under the door.", "wedge", {"patience": 10.0}],
			["Is there a back exit?", "back_exit"],
		]],
		["wedge", "caller", "(scraping) A mop bucket. It's something.", [
			["How many gunmen?", "count"],
			["Units are on the way.", "end_units"],
		]],
		["back_exit", "caller", "There's the alley door, but it's right past the kitchen. They'd see me.", [
			["Stay put. Units are on the way.", "end_units"],
			["[Profiler] When they shout next, move. They won't hear the door.", "escape", {"class": &"profiler"}],
		]],
		["escape", "caller", "(a gunshot inside, shouting) ...I'm out! I'm in the alley! Oh God, Gus is still in there.", "end_units", 3.0],
		["want", "caller", "They keep yelling at Gus about money he owes. They said if cops come, everybody dies.", [
			["[Profiler] Then units come in quiet. Tell me the layout.", "count", {"class": &"profiler"}],
			["Units are on the way.", "end_units"],
		]],
		["plate", "caller", "Black sedan... 7-K-L... I can't see the rest.", [
			["[Tech] That plate is on our stolen list from the harbor.", "stolen", {"class": &"tech", "reveals": [&"stolen_car"]}],
			["Good. Stay hidden, units are coming.", "end_units"],
		]],
		["stolen", "caller", "Stolen? So they're the harbor crew Gus was scared of.", [
			["Does Gus have a panic button behind the counter?", "panic"],
			["Units are on the way — quiet approach.", "end_units"],
		]],
		["panic", "caller", "Yes! Under the register. He never got to it— wait, the lights just went out in the dining room.", [
			["Stay in the storage room and don't move.", "end_units", {"patience": 10.0}],
		]],
		["end_units", "caller", "Please be careful. They're going to hurt Gus.", {"events": [&"dispatch_units"]}],
	])
