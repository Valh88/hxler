package hxler.nif.raw;

/** ErlNifFunc: one entry of the exported NIF function table (phase 4 glue). */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifFunc")
extern class ErlNifFunc {
	var name:cpp.ConstCharStar;
	var arity:Int;
	// fptr: ERL_NIF_TERM (*)(ErlNifEnv*, int, const ERL_NIF_TERM[]);
	// assigned from generated C++ glue; never touched from Haxe.
	var fptr:cpp.Star<cpp.Void>;
	var flags:Int;

	@:native("ErlNifFunc")
	static function make():ErlNifFunc;
}
