package hxler.nif.raw;

/** ErlNifFunc.flags (ErlNifDirtyTaskFlags; 0 = normal). */
enum abstract NifFuncFlags(Int) {
	public inline static var NORMAL = 0;
	public inline static var DIRTY_CPU = 1 /* ERL_NIF_DIRTY_JOB_CPU_BOUND */;
	public inline static var DIRTY_IO = 2 /* ERL_NIF_DIRTY_JOB_IO_BOUND */;

	inline public function new(v:Int)
		this = v;
}
