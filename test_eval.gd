extends SceneTree

func _init():
	var gm = load("res://autoload/GameManager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	var nlp = load("res://autoload/NLPManager.gd").new()
	nlp.name = "NLPManager"
	root.add_child(nlp)

	var rd_scene = load("res://scenes/ui/ReflectionDialog.tscn")
	var rd = rd_scene.instantiate()
	root.add_child(rd)
	
	var test_colors = ["biru", "warna biru", "biru kosmik", "bunga biru", "briu", "bilu", "merah", "kuning"]
	for txt in test_colors:
		rd._process_flower_color_eval(txt)
		var res = await rd.color_evaluation_submitted
		print("Color: '", txt, "' -> res: ", res)

	gm.collected_flower_count = 10
	var test_counts = ["10", "sepuluh", "10 bunga", "ada 10", "sepuluh bunga", "5"]
	for txt in test_counts:
		rd._process_flower_count_eval(txt)
		var res = await rd.count_evaluation_submitted
		print("Count: '", txt, "' -> res: ", res)
		
	quit()
