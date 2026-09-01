package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.NifTerm;

/**
 * Binary allocated directly in the env (enif_make_new_binary, rustler
 * NewBinary analog): the term exists immediately, the data buffer lives
 * in the env and is valid while the env lives. Fill, then hand out via
 * toTerm().
 */
@:keep
class NewBinary {
	public var env(default, null):Env;
	public var term(default, null):NifTerm;
	public var size(default, null):Int;
	public var data(default, null):cpp.Pointer<cpp.UInt8>;

	function new(env:Env, term:NifTerm, size:Int, data:cpp.Pointer<cpp.UInt8>) {
		this.env = env;
		this.term = term;
		this.size = size;
		this.data = data;
	}

	public static function make(env:Env, size:Int):Null<NewBinary> {
		var view = Wrapper.makeNewBinary(env.raw, size);
		return view == null ? null : new NewBinary(env, view.term, size, view.data);
	}

	public inline function getByte(i:Int):Int
		return data[i];

	public inline function setByte(i:Int, v:Int):Void
		data.setAt(i, v);

	/** Fills the buffer from Haxe bytes (length must fit). */
	public function fillFrom(b:haxe.io.Bytes, offset:Int = 0):Void {
		if (offset < 0 || offset + b.length > size) {
			throw "NewBinary.fillFrom: out of bounds";
		}
		if (b.length > 0) {
			untyped __cpp__("memcpy({0} + {1}, {2}->b->GetBase(), {3})", data, offset, b, b.length);
		}
	}

	public inline function toTerm():Term
		return new Term(env, term);
}
