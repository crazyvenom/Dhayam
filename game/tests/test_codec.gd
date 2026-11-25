extends SceneTree
## Checks the voice compression: quality, size, speed, and that lost packets do not break later ones.
## Run:  Godot --headless --path game --script res://tests/test_codec.gd

const RATE: int = 16000
const FRAME: int = 640
var problems: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		problems += 1
		print("PROBLEM: ", msg)


## A speech-like test signal: a voice pitch that glides, with harmonics and a changing loudness.
func make_signal(seconds: float) -> PackedFloat32Array:
	var n: int = int(seconds * RATE)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var f0: float = 140.0 + 40.0 * sin(t * 2.3)
		ph += TAU * f0 / RATE
		var v: float = sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph) + 0.15 * sin(5.0 * ph)
		var env: float = 0.5 + 0.5 * sin(t * 3.1)
		s[i] = clampf(v * env * 0.35, -1.0, 1.0)
	return s


func _init() -> void:
	var sig: PackedFloat32Array = make_signal(3.0)
	var enc: Adpcm = Adpcm.new()
	var out: PackedFloat32Array = PackedFloat32Array()
	var bytes: int = 0
	var t0: int = Time.get_ticks_msec()
	for i in range(0, sig.size() - FRAME + 1, FRAME):
		var pkt: PackedByteArray = enc.encode_frame(sig.slice(i, i + FRAME))
		bytes += pkt.size()
		out.append_array(Adpcm.decode(pkt))
	var ms: int = Time.get_ticks_msec() - t0
	var sig_pow: float = 0.0
	var err_pow: float = 0.0
	for i in out.size():
		sig_pow += sig[i] * sig[i]
		var d: float = sig[i] - out[i]
		err_pow += d * d
	var snr: float = 10.0 * log(sig_pow / maxf(err_pow, 1e-12)) / log(10.0)
	var kbps: float = float(bytes) * 8.0 / 3.0 / 1000.0
	print("3 s of audio: SNR %.1f dB, %.1f kbps, encode+decode took %d ms (%.1f%% of real time)" % [snr, kbps, ms, ms / 30.0])
	check(snr > 25.0, "quality too low: %.1f dB" % snr)
	check(kbps < 70.0, "too many bits: %.1f kbps" % kbps)
	check(ms < 1500, "too slow for a phone: %d ms for 3 s" % ms)

	# Each packet must decode on its own: drop every 3rd packet, quality of the rest must stay fine
	var enc2: Adpcm = Adpcm.new()
	var err2: float = 0.0
	var pow2: float = 0.0
	var k: int = 0
	for i in range(0, sig.size() - FRAME + 1, FRAME):
		var pkt2: PackedByteArray = enc2.encode_frame(sig.slice(i, i + FRAME))
		k += 1
		if k % 3 == 0:
			continue                                  # "lost in the network"
		var dec: PackedFloat32Array = Adpcm.decode(pkt2)
		for j in dec.size():
			var s: float = sig[i + j]
			pow2 += s * s
			err2 += (s - dec[j]) * (s - dec[j])
	var snr2: float = 10.0 * log(pow2 / maxf(err2, 1e-12)) / log(10.0)
	print("with every 3rd packet lost: SNR of the rest %.1f dB" % snr2)
	check(snr2 > 25.0, "lost packets break the following ones: %.1f dB" % snr2)

	# Garbage must never crash the decoder
	check(Adpcm.decode(PackedByteArray()).size() == 0, "empty packet")
	check(Adpcm.decode(PackedByteArray([1, 2, 3])).size() == 0, "tiny packet")
	var junk: PackedByteArray = PackedByteArray()
	junk.resize(324)
	for i in junk.size():
		junk[i] = randi() % 256
	check(Adpcm.decode(junk).size() == 640, "random packet should still decode to 640 samples")
	print("PROBLEMS FOUND: ", problems)
	quit(1 if problems > 0 else 0)
