package hxler.nif.raw;

/** ErlNifHash. */
enum abstract NifHash(Int) {
	public inline static var INTERNAL = 1;
	public inline static var PHASH2 = 2;

	inline public function new(v:Int)
		this = v;
}
