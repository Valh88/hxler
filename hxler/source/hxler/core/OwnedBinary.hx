package hxler.core;

import hxler.nif.BinaryBuf;
import hxler.nif.Wrapper;
import hxler.nif.raw.NifTerm;

/**
 * Caller-owned binary (rustler OwnedBinary analog): the storage is BEAM
 * memory owned by the handle until releaseToTerm transfers it to BEAM or
 * free() releases it. Fill the data, then hand it over.
 */
@:keep
class OwnedBinary {
	var buf:BinaryBuf;

	public function new(buf:BinaryBuf) {
		this.buf = buf;
	}

	/** Allocates `size` bytes (uninitialized). */
	public static function alloc(size:Int):Null<OwnedBinary> {
		var b = BinaryBuf.alloc(size);
		return b == null ? null : new OwnedBinary(b);
	}

	/** Allocates and fills from Haxe bytes. */
	public static function fromBytes(b:haxe.io.Bytes):Null<OwnedBinary> {
		var o = alloc(b.length);
		if (o != null && b.length > 0) {
			o.buf.fillFrom(b, 0);
		}
		return o;
	}

	public var size(get, never):Int;

	inline function get_size():Int
		return buf.size;

	public inline function getByte(i:Int):Int
		return buf.getByte(i);

	public inline function setByte(i:Int, v:Int):Void
		buf.setByte(i, v);

	/** Copies the bytes into Haxe-owned haxe.io.Bytes. */
	public function toBytes():haxe.io.Bytes {
		var out = haxe.io.Bytes.alloc(buf.size);
		hxler.nif.Mem.toBytes(out, buf.data, buf.size);
		return out;
	}

	/** Transfers ownership to BEAM; returns the binary term in env. */
	public function releaseToTerm(env:Env):Term {
		var term = buf.releaseToTerm(env.raw);
		buf = null;
		return new Term(env, term);
	}

	/** Frees the storage without creating a term. */
	public function free():Void {
		if (buf != null) {
			buf.free();
			buf = null;
		}
	}
}

