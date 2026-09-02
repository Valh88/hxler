package math;

import hxler.core.Env;
import hxler.core.Pid;
import hxler.core.Term;
import hxler.core.SavedTerm;
import hxler.core.OwnedEnv;
import hxler.core.NifError;
import hxler.core.NifResult;

/**
 * Phase 6 NIF module: owned env, SavedTerm, send/self/whereis, make_ref,
 * error_tuple. Pids are passed as plain terms and decoded inside the
 * function (the @:nif encoder does not know hxler.core.Pid).
 */
@:keep
@:headerCode('#include "erl_nif.h"')
@:build(hxler.macros.NifBuilder.build())
class Phase6Nif {
	/** Returns :pid if t is a pid term, else :not_pid. */
	@:nif
	public static function pidType(t:hxler.core.Term):hxler.core.Term {
		return t.toPid() == null ? t.env.atom("not_pid") : t.env.atom("pid");
	}

	/** True if the pid term t refers to a live process. */
	@:nif
	public static function pidAlive(t:hxler.core.Term):Bool {
		var pid = t.toPid();
		return pid != null && pid.isAlive(t.env);
	}

	/**
	 * Sends { :from_nif, payload } to the pid term `target` from a throwaway
	 * OwnedEnv (canonical scheduler-thread send). Returns :ok.
	 */
	@:nif
	public static function sendMsg(target:hxler.core.Term, payload:hxler.core.Term):hxler.core.NifResult<hxler.core.Term> {
		var pid = target.toPid();
		if (pid == null) {
			return Error(NifError.Term(target.env.atom("bad_pid")));
		}
		var owned = new OwnedEnv();
		var body = owned.tupleFromArray([owned.atom("from_nif"), payload.copyTo(owned.env)]);
		var ok = pid.send(target.env, body);
		owned.dispose();
		return ok ? Ok(target.env.atom("ok")) : Error(NifError.Term(target.env.atom("send_failed")));
	}

	/**
	 * OwnedEnv + SavedTerm generation test. Builds terms in one owned env,
	 * clears it halfway, and reports each SavedTerm's validity.
	 * Returns { :ok, A_valid_before, A_valid_after_clear, B_valid }.
	 */
	@:nif
	public static function savedTermGens(env:hxler.core.Env):hxler.core.NifResult<hxler.core.Term> {
		var owned = new OwnedEnv();
		var a = owned.int(111);
		var sa = owned.save(a);
		var okA0 = sa.isValid(); // true (gen 0)
		owned.clear(); // gen -> 1, invalidates sa
		var okA1 = sa.isValid(); // false (stale)
		var b = owned.int(222);
		var sb = owned.save(b);
		var okB = sb.isValid(); // true (gen 1)
		owned.dispose();
		return Ok(env.tupleFromArray([
			env.bool(okA0),
			env.bool(okA1),
			env.bool(okB)
		]));
	}

	/**
	 * Demonstrates SavedTerm.load: save a term in an owned env, keep the env
	 * alive, load it back into the call env (copy). Returns the loaded term
	 * as { :ok, Value } when the env is alive, or { :error, :stale } after a
	 * clear. This exercises SavedTerm.load -> enif_make_copy across envs.
	 */
	@:nif
	public static function savedTermLoad(env:hxler.core.Env):hxler.core.NifResult<hxler.core.Term> {
		var owned = new OwnedEnv();
		var inner = owned.int(777);
		var saved = owned.save(inner);
		var t = saved.load(env); // valid; copies 777 into the call env
		owned.dispose();
		if (t == null) {
			return Error(NifError.Term(env.atom("stale")));
		}
		return Ok(env.tupleFromArray([env.atom("ok"), t]));
	}

	/**
	 * make_ref from the call env (exercises Env.makeRef / Wrapper.makeRef).
	 * Returns { :ok, ref }.
	 */
	@:nif
	public static function makeRefNif(env:hxler.core.Env):hxler.core.NifResult<hxler.core.Term> {
		return Ok(env.tupleFromArray([env.atom("ok"), env.makeRef()]));
	}

	/**
	 * True if `name` is registered and the registered process is alive
	 * (exercises Pid.whereis -> whereis_pid -> is_process_alive).
	 */
	@:nif
	public static function whereisAlive(env:hxler.core.Env, name:hxler.core.Atom):Bool {
		var pid = Pid.whereis(env, name.toTerm(env));
		return pid != null && pid.isAlive(env);
	}
}