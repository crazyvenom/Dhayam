class_name Adpcm
extends RefCounted
## IMA ADPCM voice compression: 16-bit audio squeezed to 4 bits per sample (4 to 1).
## At 16 000 samples per second that is 64 kbps. Every packet starts with the encoder's state,
## so each one can be decoded on its own, even if a neighbour was lost.
##
## Packet: [predictor int16 (2 bytes)] [step index (1 byte)] [sequence (1 byte)] [4-bit codes ...]

static var STEP: PackedInt32Array = PackedInt32Array([
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80,
	88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544,
	598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749,
	3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635,
	13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767])
static var INDEX_ADJUST: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1, 2, 4, 6, 8])

var pred: int = 0
var index: int = 0
var seq: int = 0


## Compress one frame of samples (floats from -1 to 1; an even number of them).
func encode_frame(samples: PackedFloat32Array) -> PackedByteArray:
	var n: int = samples.size() & ~1
	var out: PackedByteArray = PackedByteArray()
	out.resize(4 + n / 2)
	out.encode_s16(0, pred)
	out[2] = index
	out[3] = seq & 255
	seq += 1
	var o: int = 4
	var low: int = 0
	for i in n:
		var s: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		var diff: int = s - pred
		var code: int = 0
		if diff < 0:
			code = 8
			diff = -diff
		var step: int = STEP[index]
		var vp: int = step >> 3
		if diff >= step:
			code |= 4
			diff -= step
			vp += step
		step >>= 1
		if diff >= step:
			code |= 2
			diff -= step
			vp += step
		step >>= 1
		if diff >= step:
			code |= 1
			vp += step
		if (code & 8) != 0:
			pred -= vp
		else:
			pred += vp
		pred = clampi(pred, -32768, 32767)
		index = clampi(index + INDEX_ADJUST[code & 7], 0, 88)
		if (i & 1) == 0:
			low = code
		else:
			out[o] = low | (code << 4)
			o += 1
	return out


## Turn a packet back into samples (floats from -1 to 1).
static func decode(data: PackedByteArray) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if data.size() < 5 or data.size() > 2000:
		return out
	var p: int = data.decode_s16(0)
	var idx: int = clampi(data[2], 0, 88)
	var n: int = (data.size() - 4) * 2
	out.resize(n)
	for i in n:
		var b: int = data[4 + (i >> 1)]
		var code: int = (b >> 4) if (i & 1) == 1 else (b & 15)
		var step: int = STEP[idx]
		var vp: int = step >> 3
		if (code & 4) != 0:
			vp += step
		if (code & 2) != 0:
			vp += step >> 1
		if (code & 1) != 0:
			vp += step >> 2
		if (code & 8) != 0:
			p -= vp
		else:
			p += vp
		p = clampi(p, -32768, 32767)
		idx = clampi(idx + INDEX_ADJUST[code & 7], 0, 88)
		out[i] = p / 32768.0
	return out
