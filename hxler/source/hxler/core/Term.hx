package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.NifTermType;
import hxler.nif.raw.NifHash;
import hxler.nif.ValueTypes.TupleView;

/**
 * Term = ERL_NIF_TERM + the Env it belongs to (rustler Term analog). The
 * raw word is stored as a primitive (hxcpp GC does not scan BEAM words).
 * Terms are valid only while their env lives: use copyTo to move a term
 * into another env.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class Term {
	public var env(default, null):Env;
	public var raw(default, null):NifTerm;

	public function new(env:Env, raw:NifTerm) {
		this.env = env;
		this.raw = raw;
	}

	// ---------------------------------------------------------- type tests --

	public inline function isAtom():Bool
		return Raw.is_atom(env.raw, raw) != 0;

	public inline function isBinary():Bool
		return Raw.is_binary(env.raw, raw) != 0;

	public inline function isList():Bool
		return Raw.is_list(env.raw, raw) != 0;

	public inline function isEmptyList():Bool
		return Raw.is_empty_list(env.raw, raw) != 0;

	public inline function isMap():Bool
		return Raw.is_map(env.raw, raw) != 0;

	public inline function isTuple():Bool
		return Raw.is_tuple(env.raw, raw) != 0;

	public inline function isNumber():Bool
		return Raw.is_number(env.raw, raw) != 0;

	public inline function isPid():Bool
		return Raw.is_pid(env.raw, raw) != 0;

	/** Decodes this pid term into a Pid, or null if not a pid. */
	public inline function toPid():Null<Pid>
		return Pid.fromTerm(this);

	public inline function isRef():Bool
		return Raw.is_ref(env.raw, raw) != 0;

	public inline function isFun():Bool
		return Raw.is_fun(env.raw, raw) != 0;

	public inline function isPort():Bool
		return Raw.is_port(env.raw, raw) != 0;

	public inline function isException():Bool
		return Raw.is_exception(env.raw, raw) != 0;

	public inline function termType():NifTermType
		return cast Raw.term_type(env.raw, raw);

	// ----------------------------------------------------------- compare --

	/** Structural/term-order comparison (<0, 0, >0). Same-env discipline. */
	public inline function compare(other:Term):Int
		return Raw.compare(raw, other.raw);

	/** True if the two terms are identical words. Same-env discipline. */
	public inline function isIdentical(other:Term):Bool
		return Raw.is_identical(raw, other.raw) != 0;

	// ----------------------------------------------------------- decode --

	public inline function getInt():Null<Int>
		return Wrapper.getInt(env.raw, raw);

	public inline function getUInt():Null<Int>
		return Wrapper.getUInt(env.raw, raw);

	public inline function getInt64():Null<haxe.Int64> {
		var v = Wrapper.getInt64(env.raw, raw);
		return v == null ? null : cast v;
	}

	public inline function getUInt64():Null<cpp.UInt64>
		return Wrapper.getUInt64(env.raw, raw);

	public inline function getFloat():Null<Float>
		return Wrapper.getDouble(env.raw, raw);

	/** Atom view of this term, or null if not an atom. */
	public inline function asAtom():Null<Atom>
		return Atom.fromTerm(this);

	/** Binary view of this term (env-bound), or null if not a binary. */
	public inline function asBinary():Null<Binary>
		return Binary.fromTerm(this);

	/** Walks a proper list into Haxe terms, or null if not a list. */
	public function toList():Null<Array<Term>> {
		if (!isList()) {
			return null;
		}
		var out = new Array<Term>();
		var cur = raw;
		while (Raw.is_empty_list(env.raw, cur) == 0) {
			var cell = Wrapper.getListCell(env.raw, cur);
			if (cell == null) {
				return null; // improper list
			}
			out.push(new Term(env, cell.head));
			cur = cell.tail;
		}
		return out;
	}

	public inline function mapGet(key:Term):Null<Term> {
		var v = Wrapper.getMapValue(env.raw, raw, key.raw);
		return v == null ? null : new Term(env, v);
	}

	/** Tuple contents (borrowed view), or null if not a tuple. */
	public inline function tupleView():Null<TupleView> {
		return Wrapper.getTuple(env.raw, raw);
	}

	// -------------------------------------------------------- resources --

	/**
	 * Wraps the resource object of this term as a ResourceArc<T> (rustler
	 * term.try_get_resource analog), or null if the term is not a resource
	 * of type T. Increments the BEAM refcount.
	 */
	public function tryGetResource<T:Resource>(cls:Class<T>):Null<ResourceArc<T>> {
		var type = ResourceCache.lookup(cls);
		if (type == null) {
			return null;
		}
		return ResourceArc.tryGetRaw(env, raw, type, ResourceCache.nameOf(cls));
	}

	// ------------------------------------------------------ cross-env/ETF --

	/** Copies this term into another env (enif_make_copy). */
	public inline function copyTo(dst:Env):Term
		return new Term(dst, Raw.make_copy(dst.raw, raw));

	/** Serializes to external term format (caller owns the buffer). */
	public function termToBinary():Null<OwnedBinary> {
		var buf = Wrapper.termToBinary(env.raw, raw);
		return buf == null ? null : new OwnedBinary(buf);
	}

	public inline function hash(type:Int = NifHash.PHASH2, salt:cpp.UInt64 = 0):cpp.UInt64
		return Raw.hash(type, raw, salt);

	/** Debug representation via enif_snprintf("%T"). */
	public inline function toString():String
		return Wrapper.termToString(env.raw, raw);
}
