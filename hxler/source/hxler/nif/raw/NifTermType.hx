package hxler.nif.raw;

/** ErlNifTermType (enif_term_type return). */
enum abstract NifTermType(Int) {
	public inline static var ATOM = 1;
	public inline static var BITSTRING = 2;
	public inline static var FLOAT = 3;
	public inline static var FUN = 4;
	public inline static var INTEGER = 5;
	public inline static var LIST = 6;
	public inline static var MAP = 7;
	public inline static var PID = 8;
	public inline static var PORT = 9;
	public inline static var REFERENCE = 10;
	public inline static var TUPLE = 11;

	inline public function new(v:Int)
		this = v;
}
