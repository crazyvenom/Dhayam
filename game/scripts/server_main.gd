extends Node
## The scene the server starts on (no graphics). The Net autoload does all the work.


func _ready() -> void:
	if not Net.is_server:
		push_warning("server scene started without --server")
	print("server scene ready")
