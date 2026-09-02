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
 *
 * RULE (phase-5 handshake, see AGENTS.md "Modela pamiati"): the stored
 * Haxe object is NOT rooted via GCAddRoot on the BEAM-allocated frame
 * (hxcpp's Immix compactor does not relocate slots in foreign memory).
 * Instead the object lives in an immortal hxcpp root table (`holders`,
 * boot-rooted static array) and the frame carries only its integer SLOT
 * INDEX. The dtor (glue -> onResourceFree) clears the slot.
 */
@:keep
@:headerCode('#include "hxler/core/HxResourceFrame.h"')
class ResourceCache {
	static var mutex:Mutex = new Mutex();
	static var types:Map<String, ErlNifResourceType> = new Map();
	static var holders:Array<Dynamic> = [];
	static var freeSlots:Array<Int> = [];

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

	// ---------------------------------------------------- immortal holders --
	// Phase-5 handshake: the Haxe object for a BEAM resource is held here
	// (an hxcpp static array is a permanent GC root), NOT on the BEAM
	// frame. The frame stores only the slot index; decoding reads the
	// object back from this table. Slots are reusable (free list) so the
	// table does not grow without bound.

	/** Stores `obj`, returns its stable slot index to write into a frame. */
	@:keep
	public static function store(obj:Dynamic):Int {
		mutex.acquire();
		var idx:Int;
		if (freeSlots.length > 0) {
			idx = freeSlots.pop();
			holders[idx] = obj;
		} else {
			holders.push(obj);
			idx = holders.length - 1;
		}
		mutex.release();
		return idx;
	}

	/** Fetches the object held at `index`, or null if empty/out of range. */
	public static function fetch(index:Int):Dynamic {
		mutex.acquire();
		var v = (index >= 0 && index < holders.length) ? holders[index] : null;
		mutex.release();
		return v;
	}

	/** Releases the holder slot (called from the resource dtor exactly once). */
	@:keep
	public static function unhold(index:Int):Void {
		mutex.acquire();
		if (index >= 0 && index < holders.length && holders[index] != null) {
			holders[index] = null;
			freeSlots.push(index);
		}
		mutex.release();
	}

	/**
	 * Dtor hook invoked by the generated glue (hx_res_dtor): reads the
	 * slot index from the frame and releases it. `obj` is the BEAM-allocated
	 * resource block (== address of the hxler::HxResourceFrame).
	 */
	@:keep
	public static function onResourceFree(obj:cpp.Star<cpp.Void>):Void {
		var index:Int = untyped __cpp__("(int)(size_t)((hxler::HxResourceFrame*){0})->root", obj);
		unhold(index);
		untyped __cpp__("((hxler::HxResourceFrame*){0})->root = 0", obj);
	}
}
