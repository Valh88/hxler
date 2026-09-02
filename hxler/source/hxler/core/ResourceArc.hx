package hxler.core;

import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.ErlNifResourceType;
import hxler.nif.raw.ErlNifResourceFrame;
import cpp.Pointer;

/**
 * Reference-counted handle to a Haxe object stored in a BEAM resource
 * (rustler ResourceArc analog).
 *
 * Memory layout: enif_alloc_resource block =
 *   [ hxler::HxResourceFrame {root, size, kind} ][user extra bytes]
 * The stored Haxe object hangs on the frame's root slot; hxcpp tracks it
 * (GCAddRoot/GCRemoveRoot) so Immix moves never invalidate it.
 *
 * ResourceArc is itself a regular hxcpp object: when the last Haxe-side
 * reference dies, the finalizer calls enif_release_resource; when the
 * BEAM drops the last term, the dtor runs the user destructor and
 * GCRemoveRoot. Exactly one release per arc (once-flag) and one
 * RemoveRoot per resource (dtor).
 *
 * RULE (phase-2 heritage): classes with raw Star fields get a
 * no-argument constructor + @:unreflective - Dynamic boxing of void*
 * constructor args generates broken __Create factories (C2664).
 *
 * PHASE-5 HANDSHAKE (see AGENTS.md "Modela pamiati"): the object is held
 * in ResourceCache's immortal holders table (a boot-rooted static array);
 * `root` in the BEAM frame carries only the integer SLOT INDEX, never a
 * raw hx::Object* (hxcpp's Immix compactor would not relocate that slot
 * in foreign BEAM memory, so GCAddRoot there was unreliable).
 */
@:keep
@:unreflective
@:headerCode('#include "erl_nif.h"
#include "hxler/core/HxResourceFrame.h"')
class ResourceArc<T:Resource> {
	public var raw(default, null):cpp.Star<cpp.Void>;

	var obj:T;
	var released:Bool;

	function new() {
		released = true; // stays "released" until properly initialized
	}

	// ------------------------------------------------------------- create --

	/**
	 * Allocates a BEAM resource of the registered type T and stores the
	 * object. extraBytes: optional user payload appended after the frame
	 * (for make_resource_binary views allocated together with the object).
	 */
	public static function make<T:Resource>(obj:T, extraBytes:Int = 0):Null<ResourceArc<T>> {
		var type = ResourceCache.typeOf(obj);
		if (type == null) {
			throw "ResourceArc: type " + ResourceCache.className(Type.getClass(cast obj)) + " not registered (call Env.registerResource from load)";
		}
		var total = FRAME_SIZE + extraBytes;
		var block = Wrapper.allocResource(type, total);
		if (block == null) {
			return null;
		}
		var frame:Pointer<ErlNifResourceFrame> = cast block;
		var frameRef = frame.at(0);
		var idx = ResourceCache.store(obj);
		untyped __cpp__("{0}.root = (hx::Object*)(size_t){1}", frameRef, idx);
		frameRef.size = total;
		frameRef.kind = ResourceCache.className(Type.getClass(cast obj));
		var arc = new ResourceArc<T>();
		untyped __cpp__("{0}->init({1}, {2})", arc, block, obj);
		ResourceCache.trackRelease(arc);
		return arc;
	}

	/** Byte offset of the user payload after the frame. */
	public static var FRAME_SIZE(get, never):Int;

	static inline function get_FRAME_SIZE():Int
		return untyped __cpp__("(int)sizeof(hxler::HxResourceFrame)");

	/** Access to the optional user payload region (frame-based allocs). */
	public inline function payload():Pointer<cpp.UInt8> {
		return untyped __cpp__("::cpp::Pointer<cpp::UInt8>((cpp::UInt8*){0} + {1})", raw, FRAME_SIZE);
	}

	// ---------------------------------------------------------- term link --

	/** The opaque resource term for `env` (BEAM refcount keeps obj alive). */
	public function toTerm(env:Env):Term {
		return new Term(env, Wrapper.makeResource(env.raw, raw));
	}

	/** enif_make_resource_binary over this resource. */
	public function makeResourceBinary(env:Env, data:Pointer<cpp.UInt8>, size:Int):Term {
		return new Term(env, Wrapper.makeResourceBinary(env.raw, raw, data, size));
	}

	/**
	 * Borrowed view of the object. The arc keeps it alive; the underlying
	 * object may be reclaimed earlier only if the resource died AND all
	 * arcs died (then this arc would be dead too). Do not store across
	 * NIF calls without keeping the arc.
	 */
	public inline function get():T
		return obj;

	/**
	 * Manual reference-count increment (e.g. before handing raw to
	 * another GC-managed owner).
	 */
	public inline function keep():Void
		Wrapper.keepResource(raw);

	// ----------------------------------------------------------- encode/decode --

	public static inline function encode<T:Resource>(env:Env, arc:ResourceArc<T>):Term
		return arc.toTerm(env);

	/** Decodes a resource term; BadArg if not this resource type. */
	public static function decode<T:Resource>(t:Term):NifResult<ResourceArc<T>> {
		return switch (tryGet(t)) {
			case null: Error(NifError.BadArg);
			case arc: Ok(arc);
		};
	}

	/**
	 * Wraps the resource object of `t` as a new arc (enif_keep_resource),
	 * or null if `t` is not a resource of type T. Verifies the frame kind
	 * (class-path name) before trusting the object.
	 */
	public static function tryGet<T:Resource>(t:Term):Null<ResourceArc<T>> {
		return tryGetRaw(t.env, t.raw, ResourceCache.lookup(Type.getClass(cast t)), ResourceCache.className(Type.getClass(cast t)));
	}

	@:allow(hxler.core)
	static function tryGetRaw<T:Resource>(env:Env, rawTerm:NifTerm, type:ErlNifResourceType, kindName:String):Null<ResourceArc<T>> {
		var obj = Wrapper.getResource(env.raw, rawTerm, type);
		if (obj == null) {
			return null;
		}
		var frame:Pointer<ErlNifResourceFrame> = cast obj;
		if (frame.at(0).kind != kindName) {
			return null; // different registered type - never hand out T
		}
		// read the immortal-holder slot index from the frame and fetch the
		// object from the (hxcpp-rooted) holder table
		var idx:Int = untyped __cpp__("(int)(size_t){0}.root", frame.at(0));
		var held:Dynamic = ResourceCache.fetch(idx);
		if (held == null) {
			return null; // object already freed - resource is dead
		}
		Wrapper.keepResource(obj);
		var arc = new ResourceArc<T>();
		untyped __cpp__("{0}->init({1}, {2})", arc, obj, held);
		ResourceCache.trackRelease(arc);
		return arc;
	}

	// ------------------------------------------------------------- release --

	/** Explicit release (normally the GC finalizer does this). */
	public function release():Void {
		if (!released && raw != null) {
			released = true;
			Wrapper.releaseResource(raw);
			raw = cast null;
			obj = null;
		}
	}

	/** hxcpp finalizer hook (registered via ResourceCache.trackRelease). */
	@:void
	static function __hx_nif_finalize_dyn(arcDyn:Dynamic):Void {
		cast(arcDyn, ResourceArc<Dynamic>).release();
	}

	// ----------------------------------------------------------- internals --

	function init(raw:cpp.Star<cpp.Void>, obj:T):Void {
		this.raw = raw;
		this.obj = obj;
		this.released = false;
	}
}
