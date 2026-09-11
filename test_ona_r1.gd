
extends SceneTree

func _init():
	var main_scene = load('res://R1.tscn')
	var r1 = main_scene.instantiate()
	root.add_child(r1)
	print('R1 instantiated!')
	var ona = r1.find_child('Ona', true, false)
	print('Ona: ', ona)
	var anim_tree = ona.get_node_or_null('AnimationTree')
	print('AnimationTree: ', anim_tree, ' active: ', anim_tree.active if anim_tree else false)
	var anim_player = ona.get_node_or_null('AnimationPlayer')
	print('AnimationPlayer: ', anim_player, ' playing: ', anim_player.current_animation if anim_player else 'none')
	var playback = ona._playback if '_playback' in ona else null
	print('Playback: ', playback)
	if playback:
		print('Current node: ', playback.get_current_node())
	
	print('Testing play_animation bashful...')
	ona.play_animation('bashful')
	for i in range(10):
		await process_frame
	print('Current node after bashful: ', playback.get_current_node() if playback else 'none')
	
	print('Testing play_animation walk...')
	ona.play_animation('walk')
	for i in range(10):
		await process_frame
	print('Current node after walk: ', playback.get_current_node() if playback else 'none')
	print('AnimationPlayer current: ', anim_player.current_animation if anim_player else 'none')
	
	quit()
