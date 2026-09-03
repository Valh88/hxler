package hxler.core;

import hxler.nif.raw.NifTerm;
import hxler.nif.raw.NifHash;

/**
 * Static Haxe-value -> Term encoders (the phase-4 @:nif macro dispatches
 * to these by parameter/return type; user classes implement the Encoder
 * interface instead).
 */
@:keep
class Encoders {
	public static inline function int(env:Env, v:Int):Term
		return env.int(v);

	public static inline function int64(env:Env, v:haxe.Int64):Term
		return env.int64(v);

	public static inline function uint(env:Env, v:Int):Term
		return env.uint(v);

	public static inline function uint64(env:Env, v:cpp.UInt64):Term
		return env.uint64(v);

	public static inline function float(env:Env, v:Float):Term
		return env.float(v);

	public static inline function bool(env:Env, v:Bool):Term
		return env.bool(v);

	/** Strings encode as UTF-8 binaries. */
	public static inline function string(env:Env, v:String):Term
		return env.binaryFromBytes(haxe.io.Bytes.ofString(v));

	public static inline function atom(env:Env, a:Atom):Term
		return a.toTerm(env);

	public static inline function term(env:Env, v:Term):Term
		return v;

	// -------------------------------------------------------- containers --

	public static inline function option<T>(env:Env, v:Null<T>, enc:T->Term):Term {
		return v == null ? AtomCache.intern("nil").toTerm(env) : enc(v);
	}

	public static function list<T>(env:Env, items:Array<T>, enc:T->Term):Term {
		var terms = new Array<Term>();
		for (x in items) {
			terms.push(enc(x));
		}
		return env.listFromArray(terms);
	}

	/** Haxe Map<K,V> -> Erlang map (fresh keys: put cannot fail). */
	public static function map<K, V>(env:Env, m:Map<K, V>, encK:K->Term, encV:V->Term):Term {
		var map = env.mapNew();
		for (k in m.keys()) {
			var next = env.mapPut(map, encK(k), encV(m.get(k)));
			if (next == null) {
				throw "Encoders.map: put failed (duplicate key?)";
			}
			map = next;
		}
		return map;
	}

	public static function tuple2(env:Env, a:Term, b:Term):Term
		return env.tupleFromArray([a, b]);

	/** ResourceArc -> opaque resource term. */
	public static inline function resource<T:hxler.core.Resource>(env:Env, arc:hxler.core.ResourceArc<T>):Term
		return arc.toTerm(env);

	public static function tuple3(env:Env, a:Term, b:Term, c:Term):Term
		return env.tupleFromArray([a, b, c]);

	// ------------------------------------------------------ result sugar --

	public static inline function ok(env:Env, v:Term):Term
		return tuple2(env, AtomCache.intern("ok").toTerm(env), v);

	public static inline function error(env:Env, v:Term):Term
		return tuple2(env, AtomCache.intern("error").toTerm(env), v);

	/** Internal hash helper exposed for tests/tools. */
	public static inline function hashTerm(t:Term, salt:cpp.UInt64 = 0):cpp.UInt64
		return t.hash(NifHash.PHASH2, salt);
}
