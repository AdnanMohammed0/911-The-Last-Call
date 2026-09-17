## Builds the ten Shift 1 calls in data/calls/shift1/ from compact branching scripts.
##   godot --headless --path . -s res://tools/calls/build_shift_calls.gd
## Node format:   [id, speaker, line, choices]            choices = Array of [text, next, options]
##                [id, speaker, line, "next_id", delay]    auto-advance (no choices)
##                [id, speaker, line]                      terminal node (call ends)
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


func _node(entry: Array) -> DialogueNode:
	var node: DialogueNode = DialogueNode.new()
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
		"id": &"call_highway_crash", "title": "Route 9 Crash", "truth": CallData.Truth.GENUINE, "minute": 3,
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
		["end_units", "caller", "Please hurry. The rain's getting in. I can hear the river."],
	])


# --- 2. Cut line (AMBUSH) ------------------------------------------------------------------------

func _cut_line() -> CallData:
	return _call({
		"id": &"call_cut_line", "title": "The Cut Line", "truth": CallData.Truth.AMBUSH, "minute": 30,
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
		["end_dispatch", "caller", "(whispering) Thank you. Tell them to come to the front door."],
	])


# --- 3. Meat truck (GENUINE) ----------------------------------------------------------------------

func _meat_truck() -> CallData:
	return _call({
		"id": &"call_meat_truck", "title": "The Meat Truck", "truth": CallData.Truth.GENUINE, "minute": 55,
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
		["end_flee", "caller", "(engine starts) I'm out, I'm out. Please, get those people out of that box."],
		["end_units", "caller", "Please hurry. It's freezing in there. They won't last all night."],
	])


# --- 4. Lost child at the mall (PRANK) ------------------------------------------------------------

func _lost_child() -> CallData:
	return _call({
		"id": &"call_lost_child", "title": "Lost at the Mall", "truth": CallData.Truth.PRANK, "minute": 80,
		"caller": "Brianna", "phone": "911-555-0112", "location": "Blackvale Mall, food court",
		"true_location": Vector2(500, 260), "patience": 120.0, "bpm": 96, "tremor_start": 0.2, "tremor_end": 0.25,
		"loops": [Vector2(1.0, 3.2)], "tags": [&"teen_laughter", &"bedroom_music"],
		"records": [
			[&"rec_mall_hours", "Blackvale Mall", "Closes at 21:00. Security guard on site until 06:00."],
			[&"rec_number_0112", "911-555-0112", "Four prank calls in 30 days. Registered to the Keller family, 8 Aspen Drive."],
		],
	}, [
		["start", "caller", "Hi, um, I'm like, lost? At the mall? And my mom's gone and there's a scary man. (muffled giggle)", [
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
		["end_confess", "caller", "(crying) Okay, okay, I'm sorry, it was a dare! Please don't tell my mom! (click)"],
	])


# --- 5. The drowned voice (PARANORMAL) ------------------------------------------------------------

func _drowned_voice() -> CallData:
	return _call({
		"id": &"call_drowned_voice", "title": "Reservoir Payphone", "truth": CallData.Truth.PARANORMAL, "minute": 105,
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
		]],
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
		"id": &"call_domestic", "title": "Thin Walls", "truth": CallData.Truth.GENUINE, "minute": 130,
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
		["end_surrender", "caller", "(through the wall) He's... he's sitting in the hall. He's actually doing it."],
		["end_barricade", "caller", "He locked himself back in with them. Please. Please hurry."],
		["end_units", "caller", "I see lights outside. Thank you. Thank you."],
	])


# --- 7. Gas station robbery (DIVERSION) -------------------------------------------------------------

func _gas_station() -> CallData:
	return _call({
		"id": &"call_gas_station", "title": "Pump 6", "truth": CallData.Truth.DIVERSION, "minute": 160,
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
		["end_click", "dispatcher", "(Click. Seconds later the Main Street bank alarm hits the silent-alarm board.)"],
		["end_diverted", "caller", "Good. Good. (click)"],
	])


# --- 8. Church bells (AMBUSH, cult) -----------------------------------------------------------------

func _church_bells() -> CallData:
	return _call({
		"id": &"call_church_bells", "title": "St. Agnes Bells", "truth": CallData.Truth.AMBUSH, "minute": 190,
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
		["end_click", "dispatcher", "(The line goes dead. The church bell starts ringing on its own, far away.)"],
		["end_units", "caller", "Bless you. Tell them to come in through the front doors. All of them."],
	])


# --- 9. Overdose (GENUINE, medical) -----------------------------------------------------------------

func _overdose() -> CallData:
	return _call({
		"id": &"call_overdose", "title": "Blue Lips", "truth": CallData.Truth.GENUINE, "minute": 220,
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
		["end_saved", "caller", "Thank you... thank you. I hear the ambulance. Thank you."],
		["end_units", "caller", "Please hurry. He's so cold."],
	])


# --- 10. The last call (PARANORMAL) -----------------------------------------------------------------

func _last_call() -> CallData:
	return _call({
		"id": &"call_last_call", "title": "The Last Call", "truth": CallData.Truth.PARANORMAL, "minute": 290,
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
