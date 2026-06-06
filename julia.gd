extends Sprite2D



func _ready():
	# Gentle idle bob — self is Julia, no variable needed
	var bob = create_tween().set_loops()
	bob.tween_property(self, "position:y", position.y - 3, 0.8)\
	   .set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", position.y, 0.8)\
	   .set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	pass
