package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;

/**
 * Env-bound binary view (rustler Binary analog). The data pointer points
 * into BEAM memory; it is valid only while the owning term lives in the
 * env. Never store a Binary beyond the NIF call - copy via toBytes().
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class Binary {
	public var env(default, null):Env;
	public var size(default, null):Int;
	public var data(default, null):cpp.Pointer<cpp.UInt8>;
	public var term(default, null):NifTerm;

	function new(env:Env, term:NifTerm, size:Int, data:cpp.Pointer<cpp.UInt8>) {
		this.env = env;
		this.term = term;
		this.size = size;
		this.data = data;
	}

	/** View of a binary term (env-bound). */
	public static function fromTerm(t:Term):Null<Binary> {
		var view = Wrapper.inspectBinary(t.env.raw, t.raw);
		return view == null ? null : new Binary(t.env, t.raw, view.size, view.data);
	}

	/**
	 * Flattens an iolist into a binary view; the data is pinned with a new
	 * binary term in the env (enif_make_binary), so it lives as long as
	 * the env.
	 */
	public static function fromIolist(t:Term):Null<Binary> {
		var view = Wrapper.inspectIolistAsBinary(t.env.raw, t.raw);
		return view == null ? null : new Binary(t.env, view.term, view.size, view.data);
	}
	public inline function getByte(i:Int):Int
		return data[i];

	/** Copies the bytes into Haxe-owned haxe.io.Bytes. */
	public function toBytes():haxe.io.Bytes {
		var out = haxe.io.Bytes.alloc(size);
		hxler.nif.Mem.toBytes(out, data, size);
		return out;
	}

	/** UTF-8 string view (copied). */
	public function getString():String {
		var b = toBytes();
		return b.getString(0, size, haxe.io.Encoding.UTF8);
	}

	/** enif_make_sub_binary over the owning term. */
	public function subTerm(offset:Int, len:Int):Term {
		return new Term(env, Raw.make_sub_binary(env.raw, term, offset, len));
	}

	/** The owning term (binary term itself for fromTerm views). */
	public inline function toTerm():Term
		return new Term(env, term);
}
