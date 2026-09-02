package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.ErlNifEnv;

/**
 * A process-independent env created with enif_alloc_env (rustler OwnedEnv
 * analog). Lives until dispose(); clear() wipes its terms and bumps a
 * generation counter so previously saved SavedTerms become stale.
 *
 * Terms built in an owned env carry EnvKind.ProcessIndependent. They are
 * message/option carriers: build them here (also from non-scheduler
 * threads), then send them to a process or copy them into a call env via
 * SavedTerm.load / Term.copyTo. DISPOSE OR CLEAR IS MANDATORY - an owned
 * env never frees itself.
 *
 * Thread-safety: an OwnedEnv must be used by ONE logical context at a time
 * (the thread that built its terms / owns its SavedTerms). Do not share it
 * unsynchronised; synchronise the recipients of its SavedTerms yourself.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class OwnedEnv {
	public var raw(default, null):ErlNifEnv;
	public var gen(default, null):Int;

	/** The Env view of this owned env (cached; one view for all terms). */
	public var env(default, null):Env;

	/** Set once dispose() runs; invalidates every SavedTerm of this env. */
	public var freed(default, null):Bool;

	public function new() {
		raw = Wrapper.allocEnv();
		if (raw == null) {
			throw "OwnedEnv: enif_alloc_env failed";
		}
		gen = 0;
		freed = false;
		env = new Env(raw, EnvKind.ProcessIndependent);
	}

	/**
	 * Frees the owned env. All terms built in it (and every SavedTerm from
	 * it) become invalid - even those already copied elsewhere are copies so
	 * they survive. Invalidates the cached Env view.
	 */
	public function dispose():Void {
		if (!freed) {
			freed = true;
			env = null;
			Wrapper.freeEnv(raw);
		}
	}

	/**
	 * Frees all terms inside the env and bumps gen(), invalidating any
	 * SavedTerm captured before the clear while keeping the env allocatable.
	 * Clearing does not free the env itself (see dispose).
	 */
	public function clear():Void {
		if (freed) {
			throw "OwnedEnv.clear: env already freed";
		}
		Wrapper.clearEnv(raw);
		gen++;
	}

	inline function guard():Env {
		if (freed) {
			throw "OwnedEnv: env already freed";
		}
		return env;
	}

	/** Captures `term` (must live in this owned env) as a SavedTerm. */
	public function save(t:Term):SavedTerm {
		if (t.env.raw != raw) {
			throw "OwnedEnv.save: term does not belong to this owned env";
		}
		return new SavedTerm(this, gen, t.raw);
	}

	// ------------------------------------------------------------ makers --

	/** A zero arity marker so an OwnedEnv can exist in the glue graph. */
	public static function unused():Void {}

	public inline function term(raw:hxler.nif.raw.NifTerm):Term
		return guard().term(raw);

	public inline function int(v:Int):Term
		return guard().int(v);

	public inline function int64(v:haxe.Int64):Term
		return guard().int64(v);

	public inline function uint64(v:cpp.UInt64):Term
		return guard().uint64(v);

	public inline function float(v:Float):Term
		return guard().float(v);

	public inline function bool(v:Bool):Term
		return guard().bool(v);

	public inline function atom(name:String):Term
		return guard().atom(name);

	public function binaryFromBytes(b:haxe.io.Bytes):Term
		return guard().binaryFromBytes(b);

	public function listFromArray(items:Array<Term>):Term
		return guard().listFromArray(items);

	public function tupleFromArray(items:Array<Term>):Term
		return guard().tupleFromArray(items);

	public inline function mapNew():Term
		return guard().mapNew();

	public function mapPut(map:Term, key:Term, value:Term):Null<Term>
		return guard().mapPut(map, key, value);

	public inline function makeRef():Term
		return guard().makeRef();

	public inline function errorTuple(reason:Term):Term
		return guard().errorTuple(reason);
}