package hxler.nif.raw;

/** ErlNifCharEncoding. */
enum abstract NifCharEncoding(Int) {
	public inline static var LATIN1 = 1;
	public inline static var UTF8 = 2;

	inline public function new(v:Int)
		this = v;
}
