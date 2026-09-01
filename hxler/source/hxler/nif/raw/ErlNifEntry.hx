package hxler.nif.raw;

/** ErlNifEntry: returned by nif_init (view only; glue generates it). */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifEntry")
extern class ErlNifEntry {
	var major:Int;
	var minor:Int;
	var name:cpp.ConstCharStar;
	var num_of_funcs:Int;
	var funcs:cpp.Pointer<ErlNifFunc>;
	// load/reload/upgrade/unload: C callbacks generated in glue; raw view only.
	var load:cpp.Star<cpp.Void>;
	var reload:cpp.Star<cpp.Void>;
	var upgrade:cpp.Star<cpp.Void>;
	var unload:cpp.Star<cpp.Void>;
	var vm_variant:cpp.ConstCharStar;
	var options:Int;
	var sizeof_ErlNifResourceTypeInit:cpp.UInt64;
	var min_erts:cpp.ConstCharStar;

	@:native("ErlNifEntry")
	static function make():ErlNifEntry;
}
