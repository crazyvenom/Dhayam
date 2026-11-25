extends SceneTree
## Generates every Dhayam sound effect as a .wav file (no outside assets, no licensing).
## Run:  Godot --headless --path game --script res://tools/synth_sounds.gd
## Writes in-game sounds to game/audio and audition copies to mockups/sounds.

const RATE: int = 44100
const C5 := 523.25
const D5 := 587.33
const E5 := 659.25
const G5 := 783.99
const A5 := 880.0
const C6 := 1046.5
const D6 := 1174.66
const E6 := 1318.5
const G6 := 1568.0
const A6 := 1760.0
const B6 := 1975.5
const C7 := 2093.0
const E7 := 2637.0
const G7 := 3136.0

var game_dir: String
var mock_dir: String


func _init() -> void:
	game_dir = ProjectSettings.globalize_path("res://audio")
	mock_dir = ProjectSettings.globalize_path("res://").path_join("../mockups/sounds").simplify_path()
	DirAccess.make_dir_recursive_absolute(game_dir)
	DirAccess.make_dir_recursive_absolute(mock_dir)

	# ---- in-game sounds ----
	game("dice_roll", s_dice_roll())
	game("step", s_step())
	game("coin_out", s_coin_out())
	game("capture", s_capture())
	game("safe", s_safe())
	game("finish", s_finish())
	game("roll_normal", s_roll_normal())
	game("roll_1", s_roll_1())
	game("roll_5", s_roll_5())
	game("roll_6", s_roll_6())
	game("roll_12", s_roll_12())
	game("fail", s_fail())
	game("win", s_win())
	game("tick", s_tick())

	# ---- background music (loops seamlessly) ----
	var music: PackedFloat32Array = music_loop()
	save(music, game_dir.path_join("bgm.wav"), 0.85)
	save(music, mock_dir.path_join("bgm.wav"), 0.85)

	# ---- intro sting options (timeline: tiles fly 0.1-2.0s, S at 1.7s, name 2.1s, TECH 2.4s) ----
	save(intro_a(), mock_dir.path_join("intro_a.wav"))
	save(intro_b(), mock_dir.path_join("intro_b.wav"))
	save(intro_c(), mock_dir.path_join("intro_c.wav"))
	save(intro_d(), mock_dir.path_join("intro_d.wav"))
	save(intro_e(), mock_dir.path_join("intro_e.wav"))
	print("done")
	quit()


# ------------------------------------------------------------------ building blocks

func buf(sec: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## A pitched tone. f1 >= 0 glides from f0 to f1. Envelope: quick attack, exponential decay.
func tone(b: PackedFloat32Array, start: float, dur: float, f0: float, vol: float, wave: String = "sine",
		f1: float = -1.0, attack: float = 0.004, decay_k: float = 6.0, release: float = 0.008) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(dur * RATE)
	var phase: float = 0.0
	for i in n:
		var idx: int = s0 + i
		if idx >= b.size():
			break
		var t: float = float(i) / RATE
		var u: float = float(i) / float(n)
		var f: float = f0 if f1 < 0.0 else lerpf(f0, f1, u)
		phase += TAU * f / RATE
		var w: float = 0.0
		match wave:
			"tri":
				w = asin(sin(phase)) * 2.0 / PI
			"square":
				w = 1.0 if sin(phase) > 0.0 else -1.0
			"saw":
				w = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			_:
				w = sin(phase)
		var env: float = minf(t / attack, 1.0) * exp(-decay_k * u) * minf(float(n - i) / (release * RATE), 1.0)
		b[idx] += w * env * vol


## Noise burst. lp0..lp1 = brightness (1 = hiss, small = dark rumble), glides over the burst.
func noise(b: PackedFloat32Array, start: float, dur: float, vol: float, lp0: float = 1.0,
		decay_k: float = 6.0, hp: bool = false, lp1: float = -1.0, rise: bool = false) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(dur * RATE)
	var y: float = 0.0
	for i in n:
		var idx: int = s0 + i
		if idx >= b.size():
			break
		var u: float = float(i) / float(n)
		var lp: float = lp0 if lp1 < 0.0 else lerpf(lp0, lp1, u)
		var x: float = randf() * 2.0 - 1.0
		y += (x - y) * lp
		var out: float = (x - y) if hp else y
		var env: float = (u if rise else 1.0) * exp(-decay_k * u) if not rise else pow(u, 1.5)
		if not rise:
			env = minf(float(i) / 80.0, 1.0) * exp(-decay_k * u)
		b[idx] += out * env * vol


func bell(b: PackedFloat32Array, start: float, f: float, vol: float, dur: float = 0.7, k: float = 5.0) -> void:
	tone(b, start, dur, f, vol, "sine", -1.0, 0.002, k)
	tone(b, start, dur * 0.6, f * 2.76, vol * 0.25, "sine", -1.0, 0.002, k * 1.6)
	tone(b, start, dur * 0.4, f * 5.4, vol * 0.10, "sine", -1.0, 0.002, k * 2.5)


func knock(b: PackedFloat32Array, start: float, vol: float, pitch: float = 1.0) -> void:
	tone(b, start, 0.06, 380.0 * pitch, vol, "sine", 160.0 * pitch, 0.001, 7.0)
	noise(b, start, 0.012, vol * 0.5, 0.5, 5.0, true)


func echo(b: PackedFloat32Array, delay: float, fb: float) -> void:
	var d: int = int(delay * RATE)
	for i in range(d, b.size()):
		b[i] += b[i - d] * fb


func save(b: PackedFloat32Array, path: String, target_peak: float = 0.85) -> void:
	var peak: float = 0.0001
	var sum_sq: float = 0.0
	for v in b:
		peak = maxf(peak, absf(v))
		sum_sq += v * v
	var g: float = target_peak / peak
	var n: int = b.size()
	var fade: int = int(0.004 * RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = b[i] * g
		if i > n - fade:
			v *= float(n - i) / float(fade)
		bytes.encode_s16(i * 2, clampi(int(v * 32767.0), -32768, 32767))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(path)
	print("%s  %.2fs  rms %.3f" % [path.get_file(), float(n) / RATE, sqrt(sum_sq / n) * g])


func game(sound_name: String, b: PackedFloat32Array) -> void:
	save(b, game_dir.path_join(sound_name + ".wav"))
	save(b, mock_dir.path_join("game_" + sound_name + ".wav"))


# ------------------------------------------------------------------ in-game sounds

## Two wooden sticks rattling in the hand, then settling.
func s_dice_roll() -> PackedFloat32Array:
	seed(11)
	var b: PackedFloat32Array = buf(1.0)
	noise(b, 0.0, 0.7, 0.10, 0.22, 2.5)
	for k in 18:
		var x: float = float(k) / 18.0
		var t: float = 0.02 + 0.8 * pow(x, 1.7) + randf() * 0.012
		knock(b, t, 0.9 - 0.45 * x, randf_range(0.8, 1.35))
	return b


## One footstep of a coin on a square: a short wooden tok.
func s_step() -> PackedFloat32Array:
	seed(12)
	var b: PackedFloat32Array = buf(0.09)
	tone(b, 0.0, 0.07, 620.0, 1.0, "sine", 340.0, 0.001, 8.0)
	noise(b, 0.0, 0.008, 0.35, 0.6, 5.0, true)
	return b


## A coin popping out of the base.
func s_coin_out() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.3)
	tone(b, 0.0, 0.14, 300.0, 0.9, "sine", 950.0, 0.003, 4.0)
	bell(b, 0.1, C7, 0.35, 0.18, 7.0)
	return b


## A capture: whoosh, thud and a falling tone.
func s_capture() -> PackedFloat32Array:
	seed(13)
	var b: PackedFloat32Array = buf(0.8)
	noise(b, 0.0, 0.55, 0.65, 0.9, 3.5, false, 0.05)
	tone(b, 0.0, 0.45, 150.0, 1.0, "sine", 48.0, 0.002, 4.5)
	tone(b, 0.0, 0.45, 640.0, 0.35, "saw", 110.0, 0.002, 5.0)
	noise(b, 0.0, 0.025, 0.7, 1.0, 5.0, true)
	return b


## Landing on a safe X square: a two-note sparkle.
func s_safe() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.7)
	bell(b, 0.0, E6, 0.7, 0.6, 5.0)
	bell(b, 0.09, B6, 0.55, 0.55, 5.0)
	bell(b, 0.18, E7, 0.35, 0.5, 6.0)
	return b


## A coin reaching the finish oval: a rising arpeggio.
func s_finish() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.9)
	var notes: Array = [C5, E5, G5, C6]
	for i in notes.size():
		tone(b, i * 0.085, 0.3, notes[i], 0.6, "tri", -1.0, 0.003, 4.5)
	bell(b, 0.34, C7, 0.6, 0.55, 4.5)
	bell(b, 0.34, G6, 0.35, 0.55, 4.5)
	return b


## 2, 3 or 4: a soft low tok, no bonus.
func s_roll_normal() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.18)
	tone(b, 0.0, 0.15, 270.0, 0.8, "sine", 190.0, 0.002, 6.0)
	return b


## 1: a single bright ding.
func s_roll_1() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.7)
	tone(b, 0.0, 0.06, 800.0, 0.35, "sine", 1568.0, 0.002, 3.0)
	bell(b, 0.04, G6, 0.9, 0.6, 5.0)
	return b


## 5: two rising notes, "ba-ding".
func s_roll_5() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.85)
	bell(b, 0.0, C6, 0.75, 0.4, 6.5)
	bell(b, 0.13, G6, 0.9, 0.65, 5.0)
	return b


## 6: three rising notes, an arpeggio.
func s_roll_6() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(1.0)
	bell(b, 0.0, C6, 0.7, 0.4, 6.5)
	bell(b, 0.1, E6, 0.8, 0.4, 6.0)
	bell(b, 0.2, G6, 0.9, 0.7, 4.5)
	return b


## 12: a big fanfare with shimmer: the jackpot.
func s_roll_12() -> PackedFloat32Array:
	seed(14)
	var b: PackedFloat32Array = buf(1.6)
	var notes: Array = [C5, E5, G5, C6, E6, G6]
	for i in notes.size():
		tone(b, i * 0.07, 0.35, notes[i], 0.55, "square", -1.0, 0.003, 5.5)
		bell(b, i * 0.07, notes[i] * 2.0, 0.35, 0.5, 5.0)
	var t0: float = 0.45
	bell(b, t0, C6, 0.9, 1.1, 3.0)
	bell(b, t0, E6, 0.8, 1.1, 3.0)
	bell(b, t0, G6, 0.8, 1.1, 3.0)
	bell(b, t0, C7, 0.9, 1.1, 3.0)
	noise(b, t0, 0.9, 0.18, 0.9, 3.0, true)
	tone(b, t0, 0.8, 130.0, 0.5, "sine", -1.0, 0.004, 3.0)
	return b


## Nothing happened (turn passes).
func s_fail() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.45)
	tone(b, 0.0, 0.18, 330.0, 0.9, "tri", 290.0, 0.003, 4.0)
	tone(b, 0.17, 0.28, 262.0, 0.9, "tri", 196.0, 0.003, 4.0)
	return b


## Victory jingle.
func s_win() -> PackedFloat32Array:
	seed(15)
	var b: PackedFloat32Array = buf(2.4)
	var notes: Array = [C5, E5, G5, C6]
	for i in notes.size():
		tone(b, i * 0.13, 0.4, notes[i], 0.6, "tri", -1.0, 0.004, 4.0)
		bell(b, i * 0.13, notes[i] * 2.0, 0.4, 0.5, 5.0)
	var t0: float = 0.6
	for f in [C6, E6, G6, C7, E7]:
		bell(b, t0, f, 0.7, 1.6, 2.2)
	bell(b, t0 + 0.35, G7, 0.5, 1.2, 2.5)
	noise(b, t0, 1.2, 0.12, 0.9, 2.5, true)
	tone(b, t0, 1.4, 131.0, 0.5, "sine", -1.0, 0.005, 2.5)
	return b


## Small UI tick.
func s_tick() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(0.06)
	tone(b, 0.0, 0.04, 1300.0, 0.8, "sine", -1.0, 0.001, 7.0)
	return b


# ------------------------------------------------------------------ background music

## A calm neon-synth loop in A minor, 100 BPM, 16 bars (about 38 seconds).
## Layers: soft pad, bass, plucky arpeggio with echo, light drums that join after 4 bars.
func music_loop() -> PackedFloat32Array:
	seed(77)
	var beat: float = 0.6
	var bar: float = beat * 4.0
	var bars: int = 16
	var loop_len: float = bar * bars
	var tail: float = 2.5
	var pad: PackedFloat32Array = buf(loop_len + tail)
	var bass: PackedFloat32Array = buf(loop_len + tail)
	var arp: PackedFloat32Array = buf(loop_len + tail)
	var drums: PackedFloat32Array = buf(loop_len + tail)

	# Am - F - C - G, two bars each, played twice
	var chords: Array = [
		[220.0, 261.63, 329.63, 110.0],
		[174.61, 220.0, 261.63, 87.31],
		[261.63, 329.63, 392.0, 130.81],
		[196.0, 246.94, 293.66, 98.0],
	]
	for c in 8:
		var ch: Array = chords[c % 4]
		var t0: float = c * 2.0 * bar
		# pad: three sustained notes, overlapping slightly with the next chord
		for k in 3:
			tone(pad, t0, 2.0 * bar + 0.5, ch[k], 0.16, "tri", -1.0, 0.7, 0.6, 0.5)
			tone(pad, t0, 2.0 * bar + 0.5, ch[k] * 2.0, 0.05, "sine", -1.0, 0.9, 0.6, 0.5)
		# bass from bar 5
		if c >= 2:
			for bi in 2:
				var tb: float = t0 + bi * bar
				for p in [0.0, 1.5, 2.0, 3.5]:
					tone(bass, tb + p * beat, 0.34, ch[3], 0.55, "sine", -1.0, 0.005, 4.0, 0.03)
		# arpeggio: 16th notes over the chord (an octave higher in the second half)
		var oct: float = 1.0 if c < 4 else 2.0
		var order: Array = [0, 1, 2, 1, 2, 1, 0, 1]
		for s in 32:
			var note: float = ch[order[s % 8]] * 2.0 * oct
			var ta: float = t0 + s * beat * 0.25
			tone(arp, ta, 0.22, note, 0.14, "tri", -1.0, 0.003, 7.0, 0.02)

	# drums from bar 5: kick on 1 and 3, soft clap on 2 and 4, hats on every 8th
	for br in range(4, bars):
		var tb2: float = br * bar
		for k in [0, 2]:
			tone(drums, tb2 + k * beat, 0.25, 140.0, 0.7, "sine", 45.0, 0.002, 6.0, 0.02)
		for k in [1, 3]:
			noise(drums, tb2 + k * beat, 0.12, 0.22, 0.9, 6.0, true)
		for e in 8:
			noise(drums, tb2 + e * beat * 0.5, 0.04, 0.09 if e % 2 == 1 else 0.06, 1.0, 6.0, true)

	echo(arp, beat * 0.75, 0.32)

	# mix, then fold the tail back onto the start so the loop has no seam
	var total: int = int(loop_len * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var mixed: PackedFloat32Array = PackedFloat32Array()
	mixed.resize(pad.size())
	for i in pad.size():
		mixed[i] = pad[i] + bass[i] + arp[i] + drums[i]
	for i in total:
		out[i] = mixed[i]
	for i in range(total, mixed.size()):
		out[i - total] += mixed[i]
	return out


# ------------------------------------------------------------------ intro sting options (3.6 s)

func landing(i: int) -> float:
	return 0.1 + i * 0.035 + 0.5   # when tile i locks into place


## A. Whoosh & Lock: tiles whoosh in and click into place, deep boom and shimmer on the logo.
func intro_a() -> PackedFloat32Array:
	seed(21)
	var b: PackedFloat32Array = buf(3.6)
	noise(b, 0.05, 1.6, 0.55, 0.03, 1.0, false, 0.5, true)
	for i in 25:
		tone(b, landing(i), 0.035, 1100.0 + (i % 5) * 90.0, 0.22, "tri", -1.0, 0.001, 8.0)
	tone(b, 1.72, 1.4, 75.0, 1.0, "sine", 38.0, 0.004, 2.8)
	noise(b, 1.72, 0.12, 0.5, 0.4, 5.0)
	bell(b, 1.75, E6, 0.55, 1.6, 2.4)
	bell(b, 1.80, B6, 0.45, 1.5, 2.4)
	bell(b, 1.85, E7, 0.3, 1.4, 2.6)
	tone(b, 2.1, 0.9, 300.0, 0.25, "sine", 700.0, 0.2, 2.0)
	bell(b, 2.45, C7, 0.35, 1.0, 3.5)
	return b


## B. Arcade Chime: a climbing 8-bit arpeggio as the tiles land, then a power chord and level-up blip.
func intro_b() -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(3.6)
	var scale: Array = [C5, D5, E5, G5, A5, C6, D6, E6, G6, A6, C7]
	for i in 25:
		var f: float = scale[mini(int(i * scale.size() / 25.0), scale.size() - 1)]
		tone(b, 0.1 + i * 0.035, 0.09, f, 0.32, "square", -1.0, 0.001, 5.0)
	for f in [262.0, 392.0, 523.25, 784.0]:
		tone(b, 1.75, 0.9, f, 0.28, "square", -1.0, 0.002, 3.2)
	tone(b, 1.75, 0.5, 65.0, 0.6, "sine", -1.0, 0.002, 4.0)
	tone(b, 2.15, 0.12, E6, 0.35, "square", -1.0, 0.002, 3.0)
	tone(b, 2.27, 0.45, A6, 0.35, "square", -1.0, 0.002, 4.0)
	bell(b, 2.45, C7, 0.3, 0.9, 3.5)
	return b


## C. Cinematic Boom: a rising drone and riser, a huge impact on the logo, long echoing tail.
func intro_c() -> PackedFloat32Array:
	seed(23)
	var b: PackedFloat32Array = buf(3.6)
	noise(b, 0.0, 1.75, 0.5, 0.02, 1.0, false, 0.55, true)
	for i in 40:
		var u: float = i / 40.0
		tone(b, u * 1.7, 0.1, 55.0 + 60.0 * u, 0.05 + 0.22 * u, "saw", -1.0, 0.01, 1.5)
	tone(b, 1.75, 1.6, 52.0, 1.2, "sine", 30.0, 0.003, 2.2)
	noise(b, 1.75, 0.35, 0.8, 0.5, 4.0)
	noise(b, 1.75, 1.3, 0.15, 1.0, 3.5, true)
	bell(b, 1.8, G6, 0.4, 1.7, 1.8)
	bell(b, 1.8, C7, 0.35, 1.7, 1.8)
	echo(b, 0.21, 0.38)
	return b


## D. Dice Rattle Reveal: wooden clacks build as the tiles fly, a coin ding on the logo, sticks clap on the name.
func intro_d() -> PackedFloat32Array:
	seed(24)
	var b: PackedFloat32Array = buf(3.6)
	noise(b, 0.1, 1.7, 0.10, 0.2, 1.2)
	for k in 46:
		var x: float = float(k) / 46.0
		knock(b, 0.1 + 1.7 * pow(x, 0.85) + randf() * 0.01, 0.35 + 0.65 * x, randf_range(0.8, 1.4))
	bell(b, 1.75, G6, 0.9, 1.2, 3.2)
	bell(b, 1.75, C7, 0.5, 1.2, 3.5)
	tone(b, 1.75, 0.3, 250.0, 0.5, "sine", 120.0, 0.002, 5.0)
	knock(b, 2.1, 1.0, 1.0)
	knock(b, 2.14, 1.0, 1.25)
	bell(b, 2.45, E6, 0.4, 1.2, 3.0)
	bell(b, 2.52, A6, 0.3, 1.2, 3.0)
	return b


## E. Soft Magic Bells: a gentle harp-like run as the tiles land, a warm bell chord, sparkles.
func intro_e() -> PackedFloat32Array:
	seed(25)
	var b: PackedFloat32Array = buf(3.6)
	var run: Array = [C5, D5, E5, G5, A5, C6, D6, E6, G6, A6, C7, D6 * 2.0]
	for i in run.size():
		bell(b, 0.1 + i * 0.14, run[i], 0.35, 0.9, 4.0)
	for f in [C6, E6, G6, B6]:
		bell(b, 1.8, f, 0.55, 1.8, 2.0)
	tone(b, 1.75, 1.7, 131.0, 0.35, "sine", -1.0, 0.25, 1.8)
	tone(b, 1.75, 1.7, 196.0, 0.2, "sine", -1.0, 0.25, 1.8)
	for i in 8:
		bell(b, 2.2 + i * 0.12, [E7, G7, C7, G6][i % 4] * 1.0, 0.18, 0.6, 5.0)
	return b
