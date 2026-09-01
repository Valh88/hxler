package hxler.nif.raw;

/** ErlNifOption (enif_set_option; set via glue - see RawGen exclusions). */
enum abstract NifOption(Int) {
	public inline static var DELAY_HALT = 1;
	public inline static var ON_HALT = 2;
	public inline static var ON_UNLOAD_THREAD = 3;

	inline public function new(v:Int)
		this = v;
}
