package hxler.nif.raw;

/** ErlNifUniqueInteger. */
enum abstract NifUniqueInteger(Int) {
	public inline static var POSITIVE = (1 << 0);
	public inline static var MONOTONIC = (1 << 1);

	inline public function new(v:Int)
		this = v;
}
