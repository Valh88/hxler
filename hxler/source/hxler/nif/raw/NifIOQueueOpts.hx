package hxler.nif.raw;

/** ErlNifIOQueueOpts. */
enum abstract NifIOQueueOpts(Int) {
	public inline static var NORMAL = 1;

	inline public function new(v:Int)
		this = v;
}
