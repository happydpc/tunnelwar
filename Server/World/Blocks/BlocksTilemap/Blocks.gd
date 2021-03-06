extends TileMap

class_name Blocks

#####MECHANICS  
var length = 100
var gold_percent = 0.25

#MAKE SURE this lines up with tilesheet
enum block {DIRT, GOLD, BEDROCK, RESET, EMPTY}
const block_num = 5

signal on_gold_block_break(player_id) 

# Called when the node enters the scene tree for the first time.
func _ready():
	gamestate.blocks_node = self 
	create_walls(2, Vector2(-1,-1), Vector2(100,100))
	generate_world() 
	
master func initialize_rpc_sender() -> void:
	for i in range(block_num):
		for cell in get_used_cells_by_id(i): 
			rpc("set_block", cell, i)
	
	#rpc_id(get_tree().get_rpc_sender_id(), "load_world", block_array) #doesn't work on webgl
	rset_id(get_tree().get_rpc_sender_id(), "initialized", true) 

func generate_world() -> void:
	generate_dirt(length)
	generate_gold(int(length * length * gold_percent))
	gamestate.set_game_phase(gamestate.game_phases.IN_PROGRESS)
	yield(get_tree().create_timer(1), "timeout")
	$ResetBlockHandler.spawn_reset_block()
	
#remove dirt and gold
func clear_inside() -> void:
	for dirt_cell in get_used_cells_by_id(block.DIRT):
		set_block(dirt_cell, block.EMPTY)
	for cell in get_used_cells_by_id(block.GOLD):
		set_block(cell, block.EMPTY)
		
func reset():
	gamestate.set_game_phase(gamestate.game_phases.INTERIM)
	clear_inside()
	yield(get_tree().create_timer(5), "timeout")
	generate_world()

func break_block(cell : Vector2, player_index = -1):
	match get_cellv(cell):
		block.DIRT:
			set_block(cell, block.EMPTY)
		block.GOLD:
			set_block(cell, block.EMPTY)
			emit_signal("on_gold_block_break", player_index)  
		block.RESET:
			$ResetBlockHandler.handle_hit(cell, player_index)
	
func spawn_golds_at(origin_cell : Vector2, gold_count : int): 
	var gold_to_spawn = gold_count
	var spawn_queue = [origin_cell]
	while gold_to_spawn > 0 and spawn_queue.size() > 0: 
		var spawn_cell = spawn_queue.pop_front()

		if not get_cellv(spawn_cell) == block.EMPTY:
			continue 

		#create gold
		set_block(spawn_cell, block.GOLD)
		gold_to_spawn -= 1 

		#add additional empty spots 
		for dir in HelperFunctions.directions:
			if get_cellv(spawn_cell + dir) == block.EMPTY:
				spawn_queue.append(spawn_cell + dir)

		yield(get_tree(), "idle_frame") 

func set_block(cell : Vector2, index : int) -> void: 
	set_cellv(cell, index) 
	rpc("set_block", cell, index)

func create_walls(block_index : int, top_left : Vector2, bottom_right : Vector2): 
	for i in range(bottom_right.x - top_left.x + 1):
		set_block(top_left + Vector2(i,0), block_index)
		set_block( bottom_right + Vector2(-i,0), block_index)
	for i in range(bottom_right.y - top_left.y + 1):
		set_block(top_left + Vector2(0,i), block_index)
		set_block(bottom_right + Vector2(0,-i), block_index)

#UNVIERSAL HELPERS 
#returns -1 if no blocks exist 
func get_random_block(block_type = -1) -> Vector2:
	if block_type == -1:
		return get_used_cells()[randi() % get_used_cells().size()]
	else:
		return get_used_cells_by_id(block_type)[randi() % get_used_cells_by_id(block_type).size()]

func get_pos(cell_coord : Vector2):
	return map_to_world(cell_coord) * scale.x 

func get_overlapping_block_type(world_pos : Vector2) -> int:
	return get_cellv(get_overlapping_cell(world_pos))

func get_overlapping_cell(world_pos : Vector2) -> Vector2:
	return Vector2(stepify(world_pos.x - 100, 200), stepify(world_pos.y - 100, 200)) / 200

#helper
func generate_dirt(square_length : int) -> void: 
	for r in range(square_length):
		for c in range(square_length):
			var coords = Vector2(r,c)
			set_block(coords, block.DIRT)

func generate_gold(num: int):
	for _i in range(num):
		var coords = Vector2(randi() % length, randi() % length)
		set_block(coords, block.GOLD)
