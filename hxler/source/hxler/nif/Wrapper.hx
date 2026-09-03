package hxler.nif;

import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.ErlNifEnv;
import hxler.nif.raw.ErlNifResourceType;
import hxler.nif.raw.ErlNifResourceTypeInit;
import hxler.nif.raw.ErlNifPid;
import hxler.nif.raw.ErlNifBinary;
import hxler.nif.raw.NifCharEncoding;
import hxler.nif.ValueTypes.Cell;
import hxler.nif.ValueTypes.TupleView;
import hxler.nif.ValueTypes.BinaryView;
import hxler.nif.ValueTypes.NewBinaryView;
import cpp.Pointer;

/**
 * Safe layer over the raw enif_* bindings: hides out-parameters, returns
 * Haxe-friendly values (Null<T> where C returns 0, typed views where C
 * returns structs). This layer must stay "almost-C" per rustler's rule:
 * no opinions about the API, just Option-style results.
 *
 * Every class that calls into this layer must carry
 * @:headerCode('#include "erl_nif.h"') directly above its declaration.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class Wrapper {
	/**
	 * null-terminated char buffer view of a Haxe String (copy).
	 * The array must stay referenced while the raw call runs.
	 */
	inline static function charBuf(s:String, extra:Int = 0):cpp.Pointer<cpp.Char> {
		var buf = new Array<cpp.Char>();
		for (i in 0...s.length) {
			buf.push(s.charCodeAt(i));
		}
		for (_ in 0...extra) {
			buf.push(0);
		}
		return cpp.Pointer.ofArray(buf);
	}

	// ------------------------------------------------------------- numbers --

	public static inline function getInt(env:ErlNifEnv, term:NifTerm):Null<Int> {
		var v = 0;
		return Raw.get_int(env, term, Pointer.addressOf(v)) != 0 ? v : null;
	}

	public static inline function getUInt(env:ErlNifEnv, term:NifTerm):Null<Int> {
		var v:cpp.UInt32 = 0;
		return Raw.get_uint(env, term, Pointer.addressOf(v)) != 0 ? cast v : null;
	}

	public static inline function getInt64(env:ErlNifEnv, term:NifTerm):Null<cpp.Int64> {
		var v:cpp.Int64 = 0;
		return Raw.get_int64(env, term, Pointer.addressOf(v)) != 0 ? v : null;
	}

	public static inline function getUInt64(env:ErlNifEnv, term:NifTerm):Null<cpp.UInt64> {
		var v:cpp.UInt64 = 0;
		return Raw.get_uint64(env, term, Pointer.addressOf(v)) != 0 ? v : null;
	}

	public static inline function getDouble(env:ErlNifEnv, term:NifTerm):Null<Float> {
		var v = 0.0;
		return Raw.get_double(env, term, Pointer.addressOf(v)) != 0 ? v : null;
	}

	public static inline function makeInt(env:ErlNifEnv, v:Int):NifTerm
		return Raw.make_int(env, v);

	public static inline function makeUInt(env:ErlNifEnv, v:Int):NifTerm
		return Raw.make_uint(env, v);

	public static inline function makeInt64(env:ErlNifEnv, v:cpp.Int64):NifTerm
		return Raw.make_int64(env, v);

	public static inline function makeUInt64(env:ErlNifEnv, v:cpp.UInt64):NifTerm
		return Raw.make_uint64(env, v);

	public static inline function makeDouble(env:ErlNifEnv, v:Float):NifTerm
		return Raw.make_double(env, v);

	// --------------------------------------------------------------- atoms --

	/** Reads an atom into a Haxe String (temporary char buffer). */
	public static function getAtom(env:ErlNifEnv, atom:NifTerm, enc:Int):Null<String> {
		var len:cpp.UInt32 = 0;
		if (Raw.get_atom_length(env, atom, Pointer.addressOf(len), enc) == 0) {
			return null;
		}
		var n:Int = len;
		var buf = new Array<cpp.Char>();
		for (_ in 0...(n + 1)) {
			buf.push(0);
		}
		var cbuf = cpp.Pointer.ofArray(buf);
		if (Raw.get_atom(env, atom, cbuf, n + 1, enc) == 0) {
			return null;
		}
		return cpp.NativeString.fromPointer(cbuf);
	}

	/** Creates a new atom (UTF8 via enif_make_new_atom_len on NIF 2.17+). */
	public static inline function makeAtom(env:ErlNifEnv, name:String, enc:Int):NifTerm {
		if (enc == NifCharEncoding.UTF8) {
			var atom:NifTerm = 0;
			if (Raw.make_new_atom_len(env, charBuf(name), name.length, Pointer.addressOf(atom), enc) == 0) {
				return 0;
			}
			return atom;
		}
		return Raw.make_atom_len(env, charBuf(name), name.length);
	}

	/** Returns the existing atom, or null if not interned. */
	public static function makeExistingAtom(env:ErlNifEnv, name:String, enc:Int):Null<NifTerm> {
		var atom:NifTerm = 0;
		if (Raw.make_existing_atom_len(env, charBuf(name), name.length, Pointer.addressOf(atom), enc) == 0) {
			return null;
		}
		return atom;
	}

	// ----------------------------------------------------------------- env --

	public static inline function allocEnv():ErlNifEnv
		return Raw.alloc_env();

	public static inline function freeEnv(env:ErlNifEnv):Void
		Raw.free_env(env);

	public static inline function clearEnv(env:ErlNifEnv):Void
		Raw.clear_env(env);

	public static inline function makeCopy(dst:ErlNifEnv, term:NifTerm):NifTerm
		return Raw.make_copy(dst, term);

	public static inline function privData(env:ErlNifEnv):cpp.Star<cpp.Void>
		return Raw.priv_data(env);

	// ---------------------------------------------------------------- list --

	public static inline function getListCell(env:ErlNifEnv, term:NifTerm):Null<Cell> {
		var head:NifTerm = 0;
		var tail:NifTerm = 0;
		if (Raw.get_list_cell(env, term, Pointer.addressOf(head), Pointer.addressOf(tail)) == 0) {
			return null;
		}
		return new Cell(head, tail);
	}

	public static function getListLength(env:ErlNifEnv, term:NifTerm):Null<Int> {
		var len:cpp.UInt32 = 0;
		return Raw.get_list_length(env, term, Pointer.addressOf(len)) != 0 ? cast len : null;
	}

	// ---------------------------------------------------------------- tuple --

	public static function getTuple(env:ErlNifEnv, term:NifTerm):Null<TupleView> {
		var arity = 0;
		var arr:Pointer<NifTerm> = null;
		if (Raw.get_tuple(env, term, Pointer.addressOf(arity), Pointer.addressOf(arr)) == 0) {
			return null;
		}
		return new TupleView(arity, arr);
	}

	// ----------------------------------------------------------------- maps --

	public static function getMapSize(env:ErlNifEnv, map:NifTerm):Null<Int> {
		var size:cpp.UInt64 = 0;
		return Raw.get_map_size(env, map, Pointer.addressOf(size)) != 0 ? cast size : null;
	}

	public static function getMapValue(env:ErlNifEnv, map:NifTerm, key:NifTerm):Null<NifTerm> {
		var value:NifTerm = 0;
		return Raw.get_map_value(env, map, key, Pointer.addressOf(value)) != 0 ? value : null;
	}

	/** Iterates a map into {key, value} cells via the raw map iterator. */
	public static function mapPairs(env:ErlNifEnv, map:NifTerm):Null<Array<Cell>> {
		var it = hxler.nif.raw.ErlNifMapIterator.make();
		var itP = Pointer.addressOf(it);
		if (Raw.map_iterator_create(env, map, itP, hxler.nif.raw.NifMapIteratorEntry.FIRST) == 0) {
			return null;
		}
		var out = new Array<Cell>();
		var k:NifTerm = 0;
		var v:NifTerm = 0;
		var ok = Raw.map_iterator_get_pair(env, itP, Pointer.addressOf(k), Pointer.addressOf(v)) != 0;
		while (ok) {
			out.push(new Cell(k, v));
			ok = Raw.map_iterator_next(env, itP) != 0
				&& Raw.map_iterator_get_pair(env, itP, Pointer.addressOf(k), Pointer.addressOf(v)) != 0;
		}
		Raw.map_iterator_destroy(env, itP);
		return out;
	}

	// ------------------------------------------------------------ resources --

	public static function getResource(env:ErlNifEnv, term:NifTerm, type:ErlNifResourceType):Null<cpp.Star<cpp.Void>> {
		var obj:cpp.Star<cpp.Void> = null;
		if (untyped __cpp__("enif_get_resource({0}, {1}, {2}, &{3})", env, term, type, obj) == 0) {
			return null;
		}
		return obj;
	}

	/**
	 * enif_init_resource_type (NIF 2.16+, our minimum is 2.17). `init` is a
	 * stack struct; BEAM does not retain it. Name goes through charBuf.
	 * The ErlNifResourceFlags* out-param cannot be expressed in Haxe (C
	 * enum-pointer, no hxcpp conversion) - hence the one-line untyped with
	 * explicit casts, same rule as RawGen's enum wrappers.
	 */
	public static function initResourceType(env:ErlNifEnv, name:String, init:cpp.Pointer<ErlNifResourceTypeInit>,
			flags:Int):ErlNifResourceType {
		var nameBuf = charBuf(name);
		var tried:Int = 0;
		var type:ErlNifResourceType = untyped __cpp__("enif_init_resource_type({0}.ptr, {1}.ptr, {2}.ptr, (ErlNifResourceFlags){3}, (ErlNifResourceFlags*)&{4})", env, nameBuf, init, flags, tried);
		return type;
	}

	public static function initResourceTypeTried(env:ErlNifEnv, name:String, init:cpp.Pointer<ErlNifResourceTypeInit>,
			flags:Int, tried:Pointer<Int>):ErlNifResourceType {
		var nameBuf = charBuf(name);
		var type:ErlNifResourceType = untyped __cpp__("enif_init_resource_type({0}.ptr, {1}.ptr, {2}.ptr, (ErlNifResourceFlags){3}, (ErlNifResourceFlags*){4}.ptr)", env, nameBuf, init, flags, tried);
		return type;
	}

	public static inline function allocResource(type:ErlNifResourceType, size:Int):cpp.Star<cpp.Void>
		return Raw.alloc_resource(type, size);

	public static inline function releaseResource(obj:cpp.Star<cpp.Void>):Void
		Raw.release_resource(obj);

	public static inline function keepResource(obj:cpp.Star<cpp.Void>):Void
		Raw.keep_resource(obj);

	public static inline function makeResource(env:ErlNifEnv, obj:cpp.Star<cpp.Void>):NifTerm
		return Raw.make_resource(env, obj);

	public static inline function makeResourceBinary(env:ErlNifEnv, obj:cpp.Star<cpp.Void>, data:Pointer<cpp.UInt8>,
			size:Int):NifTerm
		return Raw.make_resource_binary(env, obj, cast data.raw, size);

	public static inline function sizeofResource(obj:cpp.Star<cpp.Void>):Int
		return Raw.sizeof_resource(obj);

	// ------------------------------------------------------------ pids/refs --

	public static inline function self(env:ErlNifEnv, pid:Pointer<ErlNifPid>):Pointer<ErlNifPid>
		return Raw.self(env, pid);

	public static inline function getLocalPid(env:ErlNifEnv, term:NifTerm, pid:Pointer<ErlNifPid>):Bool
		return Raw.get_local_pid(env, term, pid) != 0;

	public static inline function whereisPid(env:ErlNifEnv, name:NifTerm, pid:Pointer<ErlNifPid>):Bool
		return Raw.whereis_pid(env, name, pid) != 0;

	public static inline function send(env:ErlNifEnv, pid:Pointer<ErlNifPid>, msgEnv:ErlNifEnv, msg:NifTerm):Bool
		return Raw.send(env, pid, msgEnv, msg) != 0;

	public static inline function isProcessAlive(env:ErlNifEnv, pid:Pointer<ErlNifPid>):Bool
		return Raw.is_process_alive(env, pid) != 0;

	public static inline function isCurrentProcessAlive(env:ErlNifEnv):Bool
		return Raw.is_current_process_alive(env) != 0;

	public static inline function makeRef(env:ErlNifEnv):NifTerm
		return Raw.make_ref(env);

	public static inline function setPidUndefined(pid:Pointer<ErlNifPid>):Void
		Raw.set_pid_undefined(pid);

	public static inline function isPidUndefined(pid:Pointer<ErlNifPid>):Bool
		return Raw.is_pid_undefined(pid) != 0;

	// ------------------------------------------------------------- term ops --

	public static inline function isIdentical(a:NifTerm, b:NifTerm):Bool
		return Raw.is_identical(a, b) != 0;

	public static inline function compare(a:NifTerm, b:NifTerm):Int
		return Raw.compare(a, b);

	public static inline function termType(env:ErlNifEnv, term:NifTerm):Int
		return Raw.term_type(env, term);

	public static inline function isException(env:ErlNifEnv, term:NifTerm):Bool
		return Raw.is_exception(env, term) != 0;

	public static function hasPendingException(env:ErlNifEnv):Bool {
		var reason:NifTerm = 0;
		return Raw.has_pending_exception(env, Pointer.addressOf(reason)) != 0;
	}

	public static inline function raiseException(env:ErlNifEnv, reason:NifTerm):NifTerm
		return Raw.raise_exception(env, reason);

	public static inline function makeBadarg(env:ErlNifEnv):NifTerm
		return Raw.make_badarg(env);

	/** {error, reason} tuple (via the non-variadic _from_array variant). */
	public static function makeErrorTuple(env:ErlNifEnv, reason:NifTerm):NifTerm {
		var pair = new Array<NifTerm>();
		pair.push(Raw.make_atom_len(env, charBuf("error"), 5));
		pair.push(reason);
		return Raw.make_tuple_from_array(env, cpp.Pointer.ofArray(pair), 2);
	}

	public static inline function consumeTimeslice(env:ErlNifEnv, percent:Int):Bool
		return Raw.consume_timeslice(env, percent) != 0;

	/**
	 * Human-readable term via enif_snprintf("%T") (grows the buffer like
	 * rustler). snprintf is variadic C: there is no non-untyped way to call
	 * it from Haxe, so this is one of the two justified untyped sites
	 * (see Mem.hx for the other).
	 */
	public static function termToString(env:ErlNifEnv, term:NifTerm):String {
		var sz = 64;
		while (true) {
			var buf = new Array<cpp.Char>();
			for (_ in 0...sz) {
				buf.push(0);
			}
			var cbuf = cpp.Pointer.ofArray(buf);
			var n = untyped __cpp__("enif_snprintf({0}.ptr, {1}, \"%T\", {2})", cbuf, sz, term);
			if (n >= 0 && n < sz) {
				return cpp.NativeString.fromPointer(cbuf);
			}
			sz *= 2;
			if (sz > 1 << 20) {
				return "<term too large>";
			}
		}
	}

	// ------------------------------------------------------------- binaries --

	/** Inspects a binary term; the view is valid while the term lives in env. */
	public static function inspectBinary(env:ErlNifEnv, term:NifTerm):Null<BinaryView> {
		var bin:ErlNifBinary = ErlNifBinary.make();
		if (Raw.inspect_binary(env, term, Pointer.addressOf(bin)) == 0) {
			return null;
		}
		return new BinaryView(cast bin.size, bin.data);
	}

	/** Flattens an iolist and pins the data with a new binary term in env. */
	public static function inspectIolistAsBinary(env:ErlNifEnv, term:NifTerm):Null<NewBinaryView> {
		var bin:ErlNifBinary = ErlNifBinary.make();
		if (Raw.inspect_iolist_as_binary(env, term, Pointer.addressOf(bin)) == 0) {
			return null;
		}
		// pin the flattened data: create a binary term referencing it
		var pinned = Raw.make_binary(env, Pointer.addressOf(bin));
		return new NewBinaryView(pinned, cast bin.size, bin.data);
	}

	/** Allocates a caller-owned binary (storage + struct on the BEAM heap). */
	public static function allocBinary(size:Int):Null<BinaryBuf>
		return BinaryBuf.alloc(size);

	/** enif_term_to_binary (ETF); caller must releaseToTerm or free the buf. */
	public static function termToBinary(env:ErlNifEnv, term:NifTerm):Null<BinaryBuf> {
		var local:ErlNifBinary = ErlNifBinary.make();
		if (Raw.term_to_binary(env, term, Pointer.addressOf(local)) == 0) {
			return null;
		}
		return BinaryBuf.take(cast local.size, local.data, local.ref_bin);
	}

	/** enif_binary_to_term; returns the number of bytes consumed (0 on error). */
	public static function binaryToTerm(env:ErlNifEnv, data:Pointer<cpp.UInt8>, sz:Int, opts:Int, out:Pointer<NifTerm>):Int
		return Raw.binary_to_term(env, data, sz, out, opts);

	/** enif_make_new_binary: term + writable buffer living in the env. */
	public static function makeNewBinary(env:ErlNifEnv, size:Int):Null<NewBinaryView> {
		var term:NifTerm = 0;
		var data = Raw.make_new_binary(env, size, Pointer.addressOf(term));
		if (data == null) {
			return null;
		}
		return new NewBinaryView(term, size, data);
	}

	// ----------------------------------------------------------------- time --

	public static inline function monotonicTime(unit:Int):cpp.Int64
		return Raw.monotonic_time(unit);

	public static inline function timeOffset(unit:Int):cpp.Int64
		return Raw.time_offset(unit);

	public static inline function convertTimeUnit(t:cpp.Int64, from:Int, to:Int):cpp.Int64
		return Raw.convert_time_unit(t, from, to);

	public static inline function nowTime(env:ErlNifEnv):NifTerm
		return Raw.now_time(env);

	public static inline function cpuTime(env:ErlNifEnv):NifTerm
		return Raw.cpu_time(env);

	public static inline function makeUniqueInteger(env:ErlNifEnv, flags:Int):NifTerm
		return Raw.make_unique_integer(env, flags);

	// -------------------------------------------------------------- threads --

	public static inline function threadType():Int
		return Raw.thread_type();
}




