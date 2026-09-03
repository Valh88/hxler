package hxler.nif;

import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.ErlNifEnv;
import hxler.nif.raw.ErlNifBinary;
import cpp.Pointer;

/**
 * Raw-level handle that OWNS BEAM binary storage (enif_alloc_binary).
 * Keeps the struct fields as Haxe values (size/data/ref_bin) and rebuilds
 * a local ErlNifBinary for the make/release calls - no struct retention,
 * no raw memory tricks (see Mem for the only untyped helpers).
 *
 * Either hand the storage to BEAM (releaseToTerm) or free it (free()).
 */
@:keep
@:unreflective
class BinaryBuf {
	public var size(default, null):Int;
	public var data(default, null):Pointer<cpp.UInt8>;
	public var refBin(default, null):cpp.Star<cpp.Void>;
	var alive:Bool;

	function new() {}

	/** Takes over an allocated binary (fields copied from a local struct). */
	public static function take(size:Int, data:Pointer<cpp.UInt8>, refBin:cpp.Star<cpp.Void>):BinaryBuf {
		var b = new BinaryBuf();
		b.size = size;
		b.data = data;
		b.refBin = refBin;
		b.alive = true;
		return b;
	}

	/** Allocates a BEAM binary of `size` bytes (caller fills the data). */
	public static function alloc(size:Int):Null<BinaryBuf> {
		var local:ErlNifBinary = ErlNifBinary.make();
		if (Raw.alloc_binary(size, Pointer.addressOf(local)) == 0) {
			return null;
		}
		return take(cast local.size, local.data, local.ref_bin);
	}

	public inline function getByte(i:Int):Int
		return data[i];

	public inline function setByte(i:Int, v:Int):Void
		data.setAt(i, v);

	/** Copies `src` into the binary storage at `offset`. */
	public function fillFrom(src:haxe.io.Bytes, offset:Int = 0):Void {
		if (offset < 0 || offset + src.length > size) {
			throw "BinaryBuf.fillFrom: out of bounds";
		}
		Mem.fromBytes(data, offset, src, src.length);
	}

	/** Rebuilds a local struct view for the make/release calls. */
	inline function local():ErlNifBinary {
		var b = ErlNifBinary.make();
		b.size = size;
		b.data = data;
		b.ref_bin = refBin;
		return b;
	}

	/** Transfers storage ownership to BEAM; returns the binary term. */
	public function releaseToTerm(env:ErlNifEnv):NifTerm {
		if (!alive) {
			throw "BinaryBuf.releaseToTerm: already released";
		}
		var local:ErlNifBinary = local();
		var term:NifTerm = Raw.make_binary(env, Pointer.addressOf(local));
		alive = false;
		return term;
	}

	/** Frees the binary storage. */
	public function free():Void {
		if (!alive) {
			return;
		}
		var local:ErlNifBinary = local();
		Raw.release_binary(Pointer.addressOf(local));
		alive = false;
	}
}
