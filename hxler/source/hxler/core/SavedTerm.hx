package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.NifTerm;

/**
 * A term captured from an OwnedEnv at a specific generation, safe to carry
 * across NIF calls / threads until the owning env changes generation.
 *
 * OwnedEnv terms are only alive while the env is not cleared/freed, and only
 * inside that env's process-independent memory. load(dst) checks that the
 * owning env still lives and that its generation has not advanced (i.e. the
 * captured term was not invalidated by a clear), then copies the term into
 * dst via enif_make_copy. A stale/invalid SavedTerm loads to null.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class SavedTerm {
	public var env(default, null):OwnedEnv;
	public var gen(default, null):Int;
	public var raw(default, null):NifTerm;

	@:allow(hxler.core.OwnedEnv)
	function new(env:OwnedEnv, gen:Int, raw:NifTerm) {
		this.env = env;
		this.gen = gen;
		this.raw = raw;
	}

	/**
	 * True while the term can still be loaded: the owning env has not been
	 * freed and its generation has not incremented past this capture.
	 */
	public inline function isValid():Bool
		return !env.freed && env.gen == gen;

	/**
	 * Copies this term into dst, or null if the SavedTerm is stale (env
	 * freed/cleared). The returned Term lives in dst's env.
	 */
	public function load(dst:Env):Null<Term> {
		if (!isValid()) {
			return null;
		}
		return new Term(dst, Wrapper.makeCopy(dst.raw, raw));
	}

	/** The raw term, if still valid, else null (see load). */
	public inline function rawOrNull():Null<NifTerm>
		return isValid() ? raw : null;

	/** Human-readable view of the stored term (only if still valid). */
	public function toString():String
		return isValid() ? Wrapper.termToString(env.raw, raw) : "<stale SavedTerm>";
}