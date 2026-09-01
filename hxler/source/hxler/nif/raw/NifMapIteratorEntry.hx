package hxler.nif.raw;

/** ErlNifMapIteratorEntry. */
enum abstract NifMapIteratorEntry(Int) {
	public inline static var FIRST = 1;
	public inline static var LAST = 2;

	inline public function new(v:Int)
		this = v;
}
