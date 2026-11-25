extends Node
## Voice chat: ONE common channel for everybody in the room (both teams).
## Sending:   microphone -> 16 kHz mono -> 40 ms frames -> ADPCM -> server
## Receiving: server -> ADPCM -> one audio stream per speaker -> speakers
## The microphone is only opened the first time the player uses the talk button.

signal speaking_changed(seat: int, speaking: bool)
signal notice(text: String)

const RATE: int = 16000
const FRAME: int = 640                 # samples per packet = 40 ms
const MAX_BUFFER_SEC: float = 0.45     # if a speaker's audio is further behind than this, skip ahead
const VAD_LEVEL: float = 0.015         # open-mic: how loud counts as talking

var enabled: bool = true               # voice on/off (hear others and talk)
var open_mic: bool = false             # false = hold the button to talk
var mic_muted: bool = false            # open-mic mode: the button toggles this
var talking: bool = false              # hold-to-talk button is held right now
var my_seat: int = -1
var mic_ready: bool = false
var sent_packets: int = 0
var received_packets: int = 0

var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _enc: Adpcm = Adpcm.new()
var _raw: PackedFloat32Array = PackedFloat32Array()
var _pos: float = 0.0
var _mono: PackedFloat32Array = PackedFloat32Array()
var _hang: float = 0.0
var _self_speaking: bool = false
var _voices: Dictionary = {}           # seat -> {"player", "pb", "cap", "until", "on"}


func _ready() -> void:
	if Net.is_server:
		set_process(false)
		return
	Settings.load_settings()
	enabled = Settings.voice_on
	open_mic = Settings.open_mic
	Net.voice_received.connect(_on_voice)
	get_tree().on_request_permissions_result.connect(_on_permission)


# ------------------------------------------------------------------ settings and buttons

func set_enabled(on: bool, persist: bool = true) -> void:
	enabled = on
	if persist:
		Settings.voice_on = on
		Settings.save_settings()
	Net.send("c_listen", [on])
	if not on:
		talking = false
		_clear_voices()


func set_open_mic(on: bool) -> void:
	open_mic = on
	Settings.open_mic = on
	Settings.save_settings()
	talking = false
	_set_self_speaking(false)


## Tell the server whether this phone wants to hear the others (call when entering a room).
func sync_listen() -> void:
	Net.send("c_listen", [enabled])


## The talk button went down.
func press() -> void:
	if not enabled:
		notice.emit("Voice chat is switched off")
		return
	if not mic_ready and not start_mic():
		return
	if open_mic:
		mic_muted = not mic_muted
		notice.emit("Microphone muted" if mic_muted else "Microphone is live")
	else:
		talking = true


func release() -> void:
	talking = false


## Leaving the room: stop everything, forget the other players' streams.
func reset_room() -> void:
	talking = false
	_set_self_speaking(false)
	_clear_voices()
	my_seat = -1


# ------------------------------------------------------------------ microphone

func start_mic() -> bool:
	if mic_ready:
		return true
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permissions()
		notice.emit("Allow the microphone, then try again")
		return false
	_open_mic_stream()
	return mic_ready


func _on_permission(permission: String, granted: bool) -> void:
	if permission == "android.permission.RECORD_AUDIO" and granted:
		_open_mic_stream()
		notice.emit("Microphone allowed. Hold the button to talk")


func _open_mic_stream() -> void:
	if mic_ready:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "VoiceMic")
	AudioServer.set_bus_mute(idx, true)          # so you never hear yourself
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, _capture)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "VoiceMic"
	add_child(_mic)
	_mic.play()
	mic_ready = true


func _process(_delta: float) -> void:
	if mic_ready:
		_pump_mic()
	_pump_voices()


func _pump_mic() -> void:
	var active: bool = enabled and ((open_mic and not mic_muted) or talking or _hang > 0.0 or _self_speaking)
	if not active:
		_capture.clear_buffer()
		_raw.clear()
		_mono.clear()
		_pos = 0.0
		return
	var n: int = _capture.get_frames_available()
	if n > 0:
		var frames: PackedVector2Array = _capture.get_buffer(n)
		var base: int = _raw.size()
		_raw.resize(base + n)
		for i in n:
			var f: Vector2 = frames[i]
			_raw[base + i] = (f.x + f.y) * 0.5
	# Shrink from the device's sample rate to 16 kHz by averaging
	var ratio: float = AudioServer.get_mix_rate() / float(RATE)
	while _pos + ratio <= float(_raw.size()):
		var a: int = int(_pos)
		var b: int = maxi(a + 1, int(_pos + ratio))
		var total: float = 0.0
		for j in range(a, b):
			total += _raw[j]
		_mono.append(total / float(b - a))
		_pos += ratio
	var consumed: int = int(_pos)
	if consumed > 0:
		_raw = _raw.slice(consumed)
		_pos -= float(consumed)
	while _mono.size() >= FRAME:
		var chunk: PackedFloat32Array = _mono.slice(0, FRAME)
		_mono = _mono.slice(FRAME)
		_handle_chunk(chunk)


func _handle_chunk(chunk: PackedFloat32Array) -> void:
	var sum_sq: float = 0.0
	for s in chunk:
		sum_sq += s * s
	var rms: float = sqrt(sum_sq / float(FRAME))
	var send: bool = false
	if open_mic:
		if not mic_muted:
			if rms > VAD_LEVEL:
				_hang = 0.6
			else:
				_hang -= float(FRAME) / float(RATE)
			send = _hang > 0.0
	else:
		send = talking
	_set_self_speaking(send)
	if send:
		send_pcm(chunk)


## Compress and send one 40 ms frame (also used by tests to send a made-up signal).
func send_pcm(chunk: PackedFloat32Array) -> void:
	if not enabled:
		return
	Net.send("c_voice", [_enc.encode_frame(chunk)])
	sent_packets += 1


func _set_self_speaking(v: bool) -> void:
	if v != _self_speaking:
		_self_speaking = v
		speaking_changed.emit(my_seat, v)


# ------------------------------------------------------------------ playing other people

func _voice_for(seat: int) -> Dictionary:
	if _voices.has(seat):
		return _voices[seat]
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.8
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = gen
	add_child(p)
	p.play()
	var pb: AudioStreamGeneratorPlayback = p.get_stream_playback() as AudioStreamGeneratorPlayback
	var v: Dictionary = {"player": p, "pb": pb, "cap": pb.get_frames_available(), "until": 0.0, "on": false}
	_voices[seat] = v
	return v


func _on_voice(seat: int, data: PackedByteArray) -> void:
	if not enabled:
		return
	received_packets += 1
	var samples: PackedFloat32Array = Adpcm.decode(data)
	if samples.is_empty():
		return
	var v: Dictionary = _voice_for(seat)
	var pb: AudioStreamGeneratorPlayback = v["pb"]
	var buffered: int = int(v["cap"]) - pb.get_frames_available()
	if buffered > int(MAX_BUFFER_SEC * RATE):
		return                                   # far behind: skip this packet to keep the delay short
	var frames: PackedVector2Array = PackedVector2Array()
	if buffered <= 0:                            # a new burst: add a little silence as a safety cushion
		frames.resize(480)
	var base: int = frames.size()
	frames.resize(base + samples.size())
	for i in samples.size():
		var s: float = samples[i]
		frames[base + i] = Vector2(s, s)
	pb.push_buffer(frames)
	v["until"] = Time.get_ticks_msec() / 1000.0 + 0.35
	if not v["on"]:
		v["on"] = true
		speaking_changed.emit(seat, true)


func _pump_voices() -> void:
	if _voices.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	for seat in _voices:
		var v: Dictionary = _voices[seat]
		if v["on"] and now > float(v["until"]):
			v["on"] = false
			speaking_changed.emit(seat, false)


## For tests: how many audio frames from this speaker are waiting to be played.
func buffered_frames(seat: int) -> int:
	if not _voices.has(seat):
		return 0
	var v: Dictionary = _voices[seat]
	return int(v["cap"]) - (v["pb"] as AudioStreamGeneratorPlayback).get_frames_available()


func _clear_voices() -> void:
	for seat in _voices:
		var v: Dictionary = _voices[seat]
		(v["player"] as AudioStreamPlayer).queue_free()
		if v["on"]:
			speaking_changed.emit(seat, false)
	_voices.clear()
