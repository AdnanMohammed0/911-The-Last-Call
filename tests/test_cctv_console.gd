extends GutTest

const DirectorScript := preload("res://autoload/call_director.gd")

var _saved_roster: Dictionary[int, Dictionary]
var _saved_economy: Dictionary
var _saved_persist: bool


func before_each() -> void:
	_saved_roster = NetManager.roster.duplicate(true)
	_saved_economy = Economy._state().duplicate(true)
	_saved_persist = Economy.persist
	Economy.persist = false
	Economy.inventory[&"cctv"] = 1
	NetManager.roster[1] = {"name": "Tech", "class_id": &"tech"}


func after_each() -> void:
	NetManager.roster = _saved_roster
	Economy._apply_state(_saved_economy)
	Economy.persist = _saved_persist


func test_cctv_feeds_share_station_world_and_freeze_when_closed() -> void:
	var desktop: StationOS = StationOS.new()
	add_child_autofree(desktop)
	desktop.open_app(&"cctv")
	var window: PanelContainer = desktop._windows[&"cctv"]
	var feeds: Array[Node] = window.find_children("*", "SubViewport", true, false)
	assert_eq(feeds.size(), 6)
	for node: Node in feeds:
		var feed: SubViewport = node as SubViewport
		assert_eq(feed.world_3d, get_tree().root.world_3d)
		assert_eq(feed.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	desktop.close_app(&"cctv")
	for node: Node in feeds:
		assert_eq((node as SubViewport).render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_host_taps_three_cameras_once_and_reveals_evidence() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	var call: CallData = CallData.new()
	call.id = &"test_call"
	director.active_call = call
	director.active_call_id = call.id
	director.current_state = director.CallState.CONNECTED
	director.request_cctv_hijack([0, 1, 2])
	assert_eq(director.cctv_hijacked_cameras, [0, 1, 2])
	assert_true(director.dialogue_runner.revealed_evidence.has(&"evidence_cctv_test_call"))
	director.request_cctv_hijack([3, 4, 5])
	assert_eq(director.cctv_hijacked_cameras, [0, 1, 2])
