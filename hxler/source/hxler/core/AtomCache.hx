package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.ErlNifEnv;
import hxler.nif.raw.NifCharEncoding;
import sys.thread.Mutex;

/**
 * Lazily-created shared context for atom interning.
 *
 * Holds one process-independent env that is intentionally never freed:
 * all cached atom terms live in it (envs are tiny; this happens at most
 * once per loaded NIF). Atom terms themselves are global immediates.
 * All access is mutex-guarded: first call may happen on any BEAM
 * scheduler thread.
 */
@:keep
class AtomCache {
	static var mutex:Mutex = new Mutex();
	static var env:ErlNifEnv = null;
	static var cache:Map<String, Atom> = new Map();

	/** The shared process-independent env (allocated on first use). */
	public static function sharedEnv():ErlNifEnv {
		if (env == null) {
			mutex.acquire();
			try {
				if (env == null) {
					env = Wrapper.allocEnv();
				}
			} catch (e:Dynamic) {
				mutex.release(); // finally-equivalent
				throw e;
			}
			mutex.release();
		}
		return env;
	}

	/** Interns an atom by text; returns null if the text is invalid. */
	public static function intern(name:String):Null<Atom> {
		var a = cache.get(name);
		if (a != null) {
			return a;
		}
		mutex.acquire();
		try {
			a = cache.get(name);
			if (a != null) {
				return a;
			}
			var t = Wrapper.makeAtom(sharedEnv(), name, NifCharEncoding.UTF8);
			if ((t : Int) == 0) {
				return null;
			}
			a = new Atom(t);
			cache.set(name, a);
			return a;
		} catch (e:Dynamic) {
			mutex.release(); // finally-equivalent
			throw e;
		}
		mutex.release();
	}
}



