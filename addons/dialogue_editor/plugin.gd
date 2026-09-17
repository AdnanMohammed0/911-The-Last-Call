@tool
extends EditorPlugin

## EditorPlugin entry point for DialogueGraphEditor (P2-03).
## Enables visual inspection and editing of DialogueGraph resources in Godot's bottom panel.

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")

const DIALOGUE_GRAPH_VIEW_SCENE := preload("res://addons/dialogue_editor/dialogue_graph_view.tscn")

var _editor_view: DialogueGraphView
var _bottom_panel_button: Button


func _enter_tree() -> void:
	_editor_view = DIALOGUE_GRAPH_VIEW_SCENE.instantiate() as DialogueGraphView
	_bottom_panel_button = add_control_to_bottom_panel(_editor_view, "Dialogue Graph")


func _exit_tree() -> void:
	if _editor_view != null:
		remove_control_from_bottom_panel(_editor_view)
		_editor_view.queue_free()
		_editor_view = null


func _handles(object: Object) -> bool:
	return object is DialogueGraph


func _edit(object: Object) -> void:
	if object is DialogueGraph and _editor_view != null:
		var graph: DialogueGraph = object as DialogueGraph
		_editor_view.load_graph(graph, graph.resource_path)
		make_bottom_panel_item_visible(_editor_view)


func _make_visible(visible: bool) -> void:
	if _editor_view != null:
		_editor_view.visible = visible


func _get_plugin_name() -> String:
	return "Dialogue Graph"
