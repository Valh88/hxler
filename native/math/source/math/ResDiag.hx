package math;

/**
 * Phase-5 diagnostic NIFs: verify the resource frame round-trip.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
@:build(hxler.macros.NifBuilder.build())
class ResDiag {
	// create + push + read back through tryGetResource inside ONE call
	@:nif
	public static function diagRoundtrip(env:hxler.core.Env):hxler.core.NifResult<hxler.core.Term> {
		var arc = hxler.core.ResourceArc.make(new Accum());
		arc.get().push(42);
		var t = arc.toTerm(env);
		var arc2 = t.tryGetResource(Accum);
		if (arc2 == null) {
			return Error(hxler.core.NifError.Atom("arc2_null"));
		}
		if (arc2.get() == null) {
			return Error(hxler.core.NifError.Atom("obj_null"));
		}
		if (arc2.get().items.length != 1) {
			return Error(hxler.core.NifError.Term(env.int(arc2.get().items.length)));
		}
		return Ok(env.int(arc2.get().sum()));
	}

	// reads the stored obj back from a foreign arc (cross-call check)
	@:nif
	public static function diagObjNull(arc:hxler.core.ResourceArc<Accum>):Bool {
		return arc.get() == null;
	}

	@:nif
	public static function diagPushLocal(arc:hxler.core.ResourceArc<Accum>, v:Int):Void {
		arc.get().push(v);
	}

	@:nif
	public static function diagLen(arc:hxler.core.ResourceArc<Accum>):Int {
		return arc.get().items.length;
	}

	/** Primitive field (not a GC array): survives iff the object is the same. */
	@:nif
	public static function diagCount(arc:hxler.core.ResourceArc<Accum>):Int {
		return arc.get().count;
	}

	/** Identity of the BEAM resource block (stable across calls iff same resource). */
	@:nif
	public static function diagAddr(arc:hxler.core.ResourceArc<Accum>):Int {
		var a = arc.get();
		if (a == null) {
			return -1;
		}
		return untyped __cpp__("(int)(size_t)(void*){0}->raw", arc);
	}

	/** Reads the raw frame {root} back from the resource term. */
	@:nif(arity = 1)
	public static function diagFrame(env:hxler.nif.raw.ErlNifEnv, argc:Int, argv:cpp.Pointer<hxler.nif.raw.NifTerm>):hxler.nif.raw.NifTerm {
		var e = new hxler.core.Env(env, hxler.core.EnvKind.ProcessBound);
		var t = new hxler.core.Term(e, argv[0]);
		var obj = hxler.nif.Wrapper.getResource(t.env.raw, t.raw, hxler.core.ResourceCache.lookup(Accum));
		if (obj == null) {
			return e.atom("no_resource").raw;
		}
		var frame:cpp.Pointer<hxler.nif.raw.ErlNifResourceFrame> = cast obj;
		var rootAddr:Int = untyped __cpp__("(int)(size_t)(void*)*(hx::Object**)&({0}->ptr->root)", frame);
		var buf = 'root=0x' + StringTools.hex(rootAddr, 1);
		return e.binaryFromBytes(haxe.io.Bytes.ofString(buf)).raw;
	}
}
