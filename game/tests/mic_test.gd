extends Node
## Holds the talk button for 3 seconds on this computer and reports whether the microphone produced voice.
## Run with a real window (not --headless):  Godot --path game res://tests/mic_test.tscn


func _ready() -> void:
	Voice.my_seat = 0
	print("input devices: ", AudioServer.get_input_device_list(), " mix rate: ", AudioServer.get_mix_rate())
	Voice.press()
	print("mic ready: ", Voice.mic_ready, " talking: ", Voice.talking)
	await get_tree().create_timer(3.0).timeout
	Voice.release()
	print("RESULT packets produced in 3 s: ", Voice.sent_packets, " (expected about 75 if a microphone is working)")
	get_tree().quit()
