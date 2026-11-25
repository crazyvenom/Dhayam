class_name DevTools
extends RefCounted
## Helpers for automatic testing. They do nothing unless special environment variables are set.
##   DHAYAM_SHOT=file.png  DHAYAM_SECONDS=n   take a screenshot after n seconds and quit
##   DHAYAM_STOP_AT=n                          print a fingerprint of the game after n actions and quit
##   DHAYAM_AUTO=host|guest  DHAYAM_CODEFILE   let a test copy of the game host or join a room by itself


static func maybe_shot(n: Node) -> void:
	if not OS.has_environment("DHAYAM_SHOT") or OS.has_environment("DHAYAM_AUTOPLAY"):
		return
	var secs: float = float(OS.get_environment("DHAYAM_SECONDS")) if OS.has_environment("DHAYAM_SECONDS") else 0.6
	await n.get_tree().create_timer(secs, true, false, true).timeout
	if not is_instance_valid(n) or not n.is_inside_tree():
		return                      # that screen was already replaced by the next one
	n.get_viewport().get_texture().get_image().save_png(OS.get_environment("DHAYAM_SHOT"))
	n.get_tree().quit()


static func state_hash(gs: GameState) -> String:
	return (str(gs.pos) + "|" + str(gs.active) + "|" + str(gs.unlocked) + "|" + str(gs.rot)).md5_text()


static func check_stop(n: Node, gs: GameState, count: int) -> void:
	if OS.has_environment("DHAYAM_STOP_AT") and count >= int(OS.get_environment("DHAYAM_STOP_AT")):
		print("RESULT actions=", count, " hash=", state_hash(gs), " winner=", gs.winner)
		n.get_tree().quit()
