package hxler.nif;

import hxler.nif.raw.NifTerm;

/**
 * Small Haxe value types returned by the wrapper layer. Kept in a separate
 * module (no erl_nif.h dependency) so unit tests can run without ERTS.
 */

/** head/tail of a list cell. */
@:keep
class Cell {
	public var head(default, null):NifTerm;
	public var tail(default, null):NifTerm;

	public function new(head:NifTerm, tail:NifTerm) {
		this.head = head;
		this.tail = tail;
	}
}

/** arity + pointer to the item array of a tuple (borrowed from the env). */
@:keep
class TupleView {
	public var arity(default, null):Int;
	public var items(default, null):cpp.Pointer<NifTerm>;

	public function new(arity:Int, items:cpp.Pointer<NifTerm>) {
		this.arity = arity;
		this.items = items;
	}

	public inline function get(i:Int):NifTerm
		return items[i];
}

/**
 * Flattened binary view (size + data pointer). The data pointer points into
 * BEAM-owned memory (the inspected term or a pinned iolist); it is valid
 * only while the owning term is alive in its env - never store the view.
 */
@:keep
class BinaryView {
	public var size(default, null):Int;
	public var data(default, null):cpp.Pointer<cpp.UInt8>;

	public function new(size:Int, data:cpp.Pointer<cpp.UInt8>) {
		this.size = size;
		this.data = data;
	}

	public inline function getByte(i:Int):Int
		return data[i];
}

/** Result of enif_make_new_binary: a term plus its writable buffer. */
@:keep
class NewBinaryView {
	public var term(default, null):NifTerm;
	public var size(default, null):Int;
	public var data(default, null):cpp.Pointer<cpp.UInt8>;

	public function new(term:NifTerm, size:Int, data:cpp.Pointer<cpp.UInt8>) {
		this.term = term;
		this.size = size;
		this.data = data;
	}

	public inline function getByte(i:Int):Int
		return data[i];

	public inline function setByte(i:Int, v:Int):Void
		data.setAt(i, v);
}
