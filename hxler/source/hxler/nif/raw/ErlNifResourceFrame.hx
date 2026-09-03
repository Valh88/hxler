package hxler.nif.raw;

/**
 * Haxe view of the resource-payload frame that lives INSIDE a BEAM
 * resource (phase-5 handshake, see AGENTS.md "Memory model"). The C++
 * struct is defined in hxler/core/HxResourceFrame.h (shipped with the
 * package; hxcpp's own hxcpp.h is always in scope for .cpp files):
 *
 *   [ hx::Object* root ]  <- hxcpp root slot: GCAddRoot(&root) updates
 *                            this word as the object moves; GCRemoveRoot
 *                            in the dtor (exactly once).
 *
 * The frame is embedded at the START of the enif_alloc_resource block:
 *   alloc_resource(type, sizeof(HxResourceFrame) + userExtraBytes)
 * dtor receives the object pointer = address of the frame.
 */
@:unreflective
@:structAccess
@:headerCode('#include "hxler/core/HxResourceFrame.h"')
@:native("hxler::HxResourceFrame")
extern class ErlNifResourceFrame {
	/** hxcpp GC root slot holding the stored Haxe object (or null). */
	var root:cpp.Star<cpp.Void>;

	/** Total resource size in bytes (frame + user payload). */
	var size:Int;

	/** Haxe class-path string of the stored type (diagnostics/type check). */
	var kind:String;
}
