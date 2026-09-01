package hxler.nif.raw;

/** ErlNifResourceFlags. */
enum abstract NifResourceFlags(Int) {
	public inline static var CREATE = (1) /* ERL_NIF_RT_CREATE */;
	public inline static var TAKEOVER = (2) /* ERL_NIF_RT_TAKEOVER */;

	inline public function new(v:Int)
		this = v;
}
