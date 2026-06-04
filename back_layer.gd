extends Parallax2D


@export var scroll_speed : float = 30.0
@export var direction : Vector2 = Vector2.LEFT

@onready var texture_rect : TextureRect = $TextureRect

func _ready() -> void:
	# Auto-set repeat size based on TextureRect
	if texture_rect:
		repeat_size = texture_rect.size

func _process(delta: float) -> void:
	scroll_offset += direction * scroll_speed * delta
