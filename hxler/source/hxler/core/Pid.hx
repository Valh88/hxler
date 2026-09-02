package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.ErlNifPid;
import hxler.nif.raw.NifTerm;

/**
 * Message target / sender identity (a BEAM process). Holds its own
 * ErlNifPid storage (a single-word field owned by this object), so a Pid is
 * a stable value you can keep across calls and pass to whereis/send/isAlive.
 *
 * ErlNifPid is exactly { ERL_NIF_TERM pid; } (one machine word), so the
 * object owns the word as a NifTerm field and exposes a Pointer<ErlNifPid>
 * into it. The pointer's address is stable for the lifetime of this object.
 *
 * Build one from the calling process (Env.self / Pid.self), a pid term
 * (Pid.fromTerm), or a registered name (Env.whereis / Pid.whereis). A Pid is
 * not env-bound.
 */
@:keep
@:unreflective
@:headerCode('#include "erl_nif.h"')
class Pid {
	/** Storage of the ErlNifPid struct (one word; raw points at this field). */
	var pidWord:NifTerm;

	public var raw(default, null):cpp.Pointer<ErlNifPid>;

	function new() {
		pidWord = 0;
		raw = untyped __cpp__("(ErlNifPid*)&{0}->pidWord", this);
	}

	/** The calling process's pid (enif_self). */
	public static function self(env:Env):Pid {
		var p = new Pid();
		var r = Wrapper.self(env.raw, p.raw);
		return r == null ? null : p;
	}

	/** Decodes `t` (a pid term in an Env) into a Pid, or null. */
	public static function fromTerm(t:Term):Null<Pid> {
		var p = new Pid();
		if (!Wrapper.getLocalPid(t.env.raw, t.raw, p.raw)) {
			return null;
		}
		return p;
	}

	/** Looks up a registered (atom) name in env's node; null if no such pid. */
	public static function whereis(env:Env, name:Term):Null<Pid> {
		var p = new Pid();
		if (!Wrapper.whereisPid(env.raw, name.raw, p.raw)) {
			return null;
		}
		return p;
	}

	/** True if the referenced process is currently alive. */
	public inline function isAlive(env:Env):Bool
		return Wrapper.isProcessAlive(env.raw, raw);

	/**
	 * Sends msg to this pid. `msg` must live in a process-independent env
	 * (an OwnedEnv) when called on a scheduler thread - msg_env must not be
	 * the calling process's env, and this pid must not be the caller (BEAM
	 * rules). Returns false if the message could not be delivered.
	 */
	public inline function send(env:Env, msg:Term):Bool
		return Wrapper.send(env.raw, raw, msg.env.raw, msg.raw);

	/** Debug form. */
	public function toString():String {
		return "<Pid>";
	}

	/** Marks the wrapped ErlNifPid as undefined (no process). */
	public inline function setUndefined():Void
		Wrapper.setPidUndefined(raw);

	public inline function isUndefined():Bool
		return Wrapper.isPidUndefined(raw);
}