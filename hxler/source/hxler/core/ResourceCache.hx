package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.ErlNifResourceType;
import sys.thread.Mutex;

/**
 * Maps Haxe classes (by full dotted name) to their registered
 * ErlNifResourceType handles, and registers the once-only
 * enif_release_resource finalizer on every ResourceArc the SDK hands out.
 *
 * Registration happens from the load callback (Env.registerResource);
 * lookups are mutex-guarded reads. No TypeId: the class path string
 * doubles as identity and as the frame `kind` tag for decode-time
 * verification.
 */
@:keep
class ResourceCache {
	static var mutex:Mutex = new Mutex();
	static var types:Map<String, ErlNifResourceType> = new Map();

	/** Full dotted name of T (used both as cache key and frame tag). */
	public static inline function className(cls:Class<Dynamic>):String {
		return Type.getClassName(cls);
	}

	public static function nameOf<T:Resource>(cls:Class<T>):String {
		return Type.getClassName(cls);
	}

	/** Registered handle for an instance, or null (unregistered). */
	public static function typeOf<T:Resource>(obj:T):Null<ErlNifResourceType> {
		var name = className(Type.getClass(cast obj));
		mutex.acquire();
		var t = types.get(name);
		mutex.release();
		return t;
	}

	/** Lookup by class object. */
	public static function lookup<T:Resource>(cls:Class<T>):Null<ErlNifResourceType> {
		var name = Type.getClassName(cls);
		mutex.acquire();
		var t = types.get(name);
		mutex.release();
		return t;
	}

	/** Registers the handle produced by the load-callback glue. */
	@:allow(hxler.core.Env)
	static function register(name:String, type:ErlNifResourceType):Void {
		mutex.acquire();
		types.set(name, type);
		mutex.release();
	}

	/**
	 * Attaches the hxcpp finalizer that releases the BEAM refcount when
	 * the ResourceArc object itself is collected. Runs at most once per
	 * arc (arc.release has a once-flag too; the finalizer fires exactly
	 * once per object). `_hx_set_finalizer` is the correctly typed entry
	 * (Dynamic, void(*)(Dynamic)) - same one cpp.vm.Gc.setFinalizer uses.
	 */
	public static function trackRelease(arc:hxler.core.ResourceArc<Dynamic>):Void {
		untyped __cpp__("_hx_set_finalizer((Dynamic){0}, (void(*)(Dynamic))&hxler::core::ResourceArc_obj::__hx_nif_finalize_dyn)", arc);
	}

	/** Test/inspection helper. */
	public static function registeredNames():Array<String> {
		mutex.acquire();
		var out = [for (k in types.keys()) k];
		mutex.release();
		return out;
	}
}
