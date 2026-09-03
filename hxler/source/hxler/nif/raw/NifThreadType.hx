package hxler.nif.raw;

/** enif_thread_type return. */
enum abstract NifThreadType(Int) {
	public inline static var UNDEFINED = 0;
	public inline static var NORMAL_SCHEDULER = 1;
	public inline static var DIRTY_CPU_SCHEDULER = 2;
	public inline static var DIRTY_IO_SCHEDULER = 3;

	inline public function new(v:Int)
		this = v;

	inline public static function isSchedulerThread(v:Int):Bool
		return v > 0;
}
