package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.NifTerm;

/**
 * Converts NifResult<Term> into the raw NIF return value (the runtime part
 * of the generated glue, phase 4). Haxe exceptions never cross into BEAM:
 * they are caught by the glue trampoline -> :nif_panicked.
 */
@:keep
class NifReturn {
	/** Applies the result: Ok -> term, Error -> per-NifError behavior. */
	public static function apply(env:Env, r:NifResult<Term>):NifTerm {
		return switch (r) {
			case Ok(t):
				t.raw;
			case Error(e):
				errorTerm(env, e);
		};
	}

	/** Converts a bare NifError into the raw return value. */
	public static function errorTerm(env:Env, e:NifError):NifTerm {
		return switch (e) {
			case BadArg:
				Wrapper.makeBadarg(env.raw);
			case Atom(name):
				var a = AtomCache.intern(name);
				a == null ? Wrapper.makeBadarg(env.raw) : a.toTerm(env).raw;
			case RaiseAtom(name):
				var a = AtomCache.intern(name);
				Wrapper.raiseException(env.raw, a == null ? Wrapper.makeBadarg(env.raw) : a.toTerm(env).raw);
			case RaiseTerm(t):
				Wrapper.raiseException(env.raw, t.raw);
			case Term(reason):
				env.errorTuple(reason).raw;
		};
	}
}
