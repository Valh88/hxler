package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.ErlNifEnv;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.NifCharEncoding;

/**
 * Wrapper over ErlNifEnv* (rustler Env analog). Created by the generated
 * glue (phase 4) for NIF calls/callbacks and by OwnedEnv for
 * process-independent envs; do not construct manually outside of glue.
 *
 * A Term always carries its Env: terms are only valid inside the env they
 * were created in (cross-env transfer goes through Term.copyTo).
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class Env {
	public var raw(default, null):ErlNifEnv;
	public var kind(default, null):EnvKind;

	public function new(raw:ErlNifEnv, kind:EnvKind) {
		this.raw = raw;
		this.kind = kind;
	}

	/** Wraps a raw term (glue / view helpers). */
	public inline function term(raw:NifTerm):Term
		return new Term(this, raw);

	// ------------------------------------------------------------- makers --

	public inline function int(v:Int):Term
		return new Term(this, Wrapper.makeInt(raw, v));

	public inline function uint(v:Int):Term
		return new Term(this, Wrapper.makeUInt(raw, v));

	public inline function int64(v:haxe.Int64):Term
		return new Term(this, Wrapper.makeInt64(raw, v));

	public inline function uint64(v:cpp.UInt64):Term
		return new Term(this, Wrapper.makeUInt64(raw, v));

	public inline function float(v:Float):Term
		return new Term(this, Wrapper.makeDouble(raw, v));

	public inline function bool(v:Bool):Term
		return AtomCache.intern(v ? "true" : "false").toTerm(this);

	/** Cached atom term (see AtomCache); atoms are global immediates. */
	public inline function atom(name:String):Term
		return AtomCache.intern(name).toTerm(this);

	/** Copies Haxe bytes into a fresh binary term living in this env. */
	public function binaryFromBytes(b:haxe.io.Bytes):Term {
		var size = b.length;
		var view = Wrapper.makeNewBinary(raw, size);
		if (view == null) {
			throw "Env.binaryFromBytes: enif_make_new_binary failed";
		}
		hxler.nif.Mem.fromBytes(view.data, 0, b, size);
		return new Term(this, view.term);
	}

	public function listFromArray(items:Array<Term>):Term {
		var raws = new Array<NifTerm>();
		for (t in items) {
			raws.push(t.raw);
		}
		return new Term(this, Raw.make_list_from_array(raw, cpp.Pointer.ofArray(raws), items.length));
	}

	public function tupleFromArray(items:Array<Term>):Term {
		var raws = new Array<NifTerm>();
		for (t in items) {
			raws.push(t.raw);
		}
		return new Term(this, Raw.make_tuple_from_array(raw, cpp.Pointer.ofArray(raws), items.length));
	}

	public inline function mapNew():Term
		return new Term(this, Raw.make_new_map(raw));

	/** Returns the updated map term, or null if the key already exists. */
	public function mapPut(map:Term, key:Term, value:Term):Null<Term> {
		var out:NifTerm = 0;
		if (Raw.make_map_put(raw, map.raw, key.raw, value.raw, cpp.Pointer.addressOf(out)) == 0) {
			return null;
		}
		return new Term(this, out);
	}

	public inline function makeRef():Term
		return new Term(this, Wrapper.makeRef(raw));

	/** {error, reason} tuple (common NIF error return). */
	public inline function errorTuple(reason:Term):Term
		return new Term(this, Wrapper.makeErrorTuple(raw, reason.raw));

	// -------------------------------------------------------------- misc --

	public inline function consumeTimeslice(percent:Int):Bool
		return Wrapper.consumeTimeslice(raw, percent);

	public inline function binaryToTerm(b:haxe.io.Bytes, opts:Int = 0):Null<Term> {
		var data = b.length == 0 ? null : hxler.nif.Mem.bytesBase(b);
		var out:NifTerm = 0;
		var consumed = Wrapper.binaryToTerm(raw, data, b.length, opts, cpp.Pointer.addressOf(out));
		return consumed > 0 ? new Term(this, out) : null;
	}
}

