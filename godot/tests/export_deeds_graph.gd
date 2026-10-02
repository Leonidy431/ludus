## Writes the walk of the 26 acts for the web build (tests/deeds_graph.gd):
##   godot --headless --path godot -s res://tests/export_deeds_graph.gd
## It prints the path, the acts and the node count, and exits 1 when an
## act's walk passes its bound (a loop in the act).
extends SceneTree

const Graph := preload("res://tests/deeds_graph.gd")


func _initialize() -> void:
	var g: Dictionary = Graph.build()
	var total := 0
	var bad := 0
	for id in g.acts:
		total += g.acts[id].nodes.size()
		if g.acts[id].overflow:
			bad += 1
			printerr("overflow: ", id)
	var f := FileAccess.open(Graph.out_path(), FileAccess.WRITE)
	f.store_string(Graph.to_text(g))
	f.close()
	print("place deeds graph: %s, %d acts, %d nodes" % [Graph.out_path(),
		g.acts.size(), total])
	quit(1 if bad > 0 else 0)
