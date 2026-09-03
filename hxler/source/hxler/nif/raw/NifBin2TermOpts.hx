package hxler.nif.raw;

/** enif_binary_to_term options. */
enum abstract NifBin2TermOpts(Int) {
	/** ERL_NIF_BIN2TERM_SAFE */
	public inline static var SAFE = (0x20000000);

	inline public function new(v:Int)
		this = v;
}
