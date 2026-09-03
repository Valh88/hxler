package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.NifCharEncoding;

/**
 * Atom wrapper. Atoms are global immediates: the raw term is valid in any
 * env, forever (BEAM keeps the atom table). Use AtomCache for interned
 * atoms instead of creating the same atom repeatedly.
 */
@:keep
class Atom {
	public var raw(default, null):NifTerm;

	public function new(raw:NifTerm) {
		this.raw = raw;
	}

	/** Creates (or returns) an atom by text; null if encoding failed. */
	public static function make(env:Env, name:String, enc:Int = NifCharEncoding.UTF8):Null<Atom> {
		var t = Wrapper.makeAtom(env.raw, name, enc);
		return (t : Int) == 0 ? null : new Atom(t);
	}

	/** Returns the interned atom, or null if it does not exist yet. */
	public static function existing(env:Env, name:String, enc:Int = NifCharEncoding.UTF8):Null<Atom> {
		var t = Wrapper.makeExistingAtom(env.raw, name, enc);
		return t == null ? null : new Atom(t);
	}

	/** Atom view of a term, or null if the term is not an atom. */
	public static function fromTerm(t:Term):Null<Atom>
		return t.isAtom() ? new Atom(t.raw) : null;

	/**
	 * The atom term wrapped for `env`. No copy is needed: atoms are
	 * immediates valid in every env, but Term must carry its env.
	 */
	public inline function toTerm(env:Env):Term
		return new Term(env, raw);

	/** Atom text (UTF-8) read through the shared cache env. */
	public function toString():Null<String> {
		return Wrapper.getAtom(AtomCache.sharedEnv(), raw, NifCharEncoding.UTF8);
	}

	/** Identity compare (same as Term.isIdentical on the raw words). */
	public inline function equals(other:Atom):Bool
		return Raw.is_identical(raw, other.raw) != 0;
}




