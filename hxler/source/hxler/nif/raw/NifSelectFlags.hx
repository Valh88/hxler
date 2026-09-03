package hxler.nif.raw;

/** enif_select flags (ERL_NIF_SELECT_*). */
enum abstract NifSelectFlags(Int) {
	public inline static var READ = (1 << 0);
	public inline static var WRITE = (1 << 1);
	public inline static var STOP = (1 << 2);
	public inline static var CANCEL = (1 << 3);
	public inline static var CUSTOM_MSG = (1 << 4);
	public inline static var ERROR = (1 << 5);

	inline public function new(v:Int)
		this = v;
}
