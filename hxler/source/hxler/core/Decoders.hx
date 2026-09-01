package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.NifMapIteratorEntry;

/**
 * Static Term -> Haxe-value decoders (phase-4 @:nif dispatch targets).
 * Decode failures return Error(BadArg) unless noted.
 */
@:keep
class Decoders {
	public static inline function int(t:Term):NifResult<Int> {
		var v = t.getInt();
		return v == null ? Error(BadArg) : Ok(v);
	}

	public static inline function uint(t:Term):NifResult<Int> {
		var v = t.getUInt();
		return v == null ? Error(BadArg) : Ok(v);
	}

	public static inline function int64(t:Term):NifResult<haxe.Int64> {
		var v = t.getInt64();
		return v == null ? Error(BadArg) : Ok(v);
	}

	public static inline function uint64(t:Term):NifResult<cpp.UInt64> {
		var v = t.getUInt64();
		return v == null ? Error(BadArg) : Ok(v);
	}

	/** Float decodes from float OR integer (rustler f64 behavior). */
	public static function float(t:Term):NifResult<Float> {
		var v = t.getFloat();
		if (v != null) {
			return Ok(v);
		}
		var i = t.getInt();
		return i == null ? Error(BadArg) : Ok(cast i);
	}

	public static function bool(t:Term):NifResult<Bool> {
		var a = t.asAtom();
		if (a == null) {
			return Error(BadArg);
		}
		if (a.equals(AtomCache.intern("true"))) {
			return Ok(true);
		}
		if (a.equals(AtomCache.intern("false"))) {
			return Ok(false);
		}
		return Error(BadArg);
	}

	/** Strings decode from UTF-8 binaries. */
	public static function string(t:Term):NifResult<String> {
		var b = t.asBinary();
		return b == null ? Error(BadArg) : Ok(b.getString());
	}

	public static inline function atom(t:Term):NifResult<Atom> {
		var a = t.asAtom();
		return a == null ? Error(BadArg) : Ok(a);
	}

	public static inline function term(t:Term):NifResult<Term>
		return Ok(t);

	// -------------------------------------------------------- containers --

	/** nil -> Ok(null), otherwise decode the term with `dec`. */
	public static function option<T>(t:Term, dec:Term->NifResult<T>):NifResult<Null<T>> {
		var nil = AtomCache.intern("nil");
		if (nil != null && t.isAtom() && t.asAtom().equals(nil)) {
			return Ok(null);
		}
		return dec(t);
	}

	public static function list<T>(t:Term, dec:Term->NifResult<T>):NifResult<Array<T>> {
		var items = t.toList();
		if (items == null) {
			return Error(BadArg);
		}
		var out = new Array<T>();
		for (item in items) {
			switch (dec(item)) {
				case Ok(v):
					out.push(v);
				case Error(e):
					return Error(e);
			}
		}
		return Ok(out);
	}

	/**
	 * Erlang map -> key/value pairs. Returns pairs (not Map<K,V>) because
	 * hxcpp cannot instantiate a generic-keyed Map at runtime; build the
	 * concrete map you need from the pairs.
	 */
	public static function map<K, V>(t:Term, decK:Term->NifResult<K>, decV:Term->NifResult<V>):NifResult<Array<{k:K, v:V}>> {
		if (!t.isMap()) {
			return Error(BadArg);
		}
		var cells = Wrapper.mapPairs(t.env.raw, t.raw);
		if (cells == null) {
			return Error(BadArg);
		}
		var out = new Array<{k:K, v:V}>();
		for (cell in cells) {
			switch (decK(new Term(t.env, cell.head))) {
				case Ok(k):
					switch (decV(new Term(t.env, cell.tail))) {
						case Ok(v):
							out.push({k: k, v: v});
						case Error(e):
							return Error(e);
					}
				case Error(e):
					return Error(e);
			}
		}
		return Ok(out);
	}

	/** {:ok, V} -> Ok(Left(v)) | {:error, E} -> Ok(Right(e)) | else BadArg. */
	public static function result<T, E>(t:Term, decT:Term->NifResult<T>, decE:Term->NifResult<E>):NifResult<haxe.ds.Either<T, E>> {
		if (!t.isTuple()) {
			return Error(BadArg);
		}
		var view = t.tupleView();
		if (view == null || view.arity != 2) {
			return Error(BadArg);
		}
		var tag = new Term(t.env, view.get(0));
		var okAtom = AtomCache.intern("ok");
		var errAtom = AtomCache.intern("error");
		if (okAtom != null && tag.isAtom() && tag.asAtom().equals(okAtom)) {
			return switch (decT(new Term(t.env, view.get(1)))) {
				case Ok(v): Ok(Left(v));
				case Error(e): Error(e);
			};
		}
		if (errAtom != null && tag.isAtom() && tag.asAtom().equals(errAtom)) {
			return switch (decE(new Term(t.env, view.get(1)))) {
				case Ok(e): Ok(Right(e));
				case Error(e2): Error(e2);
			};
		}
		return Error(BadArg);
	}
}

