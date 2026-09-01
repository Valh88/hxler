package hxler.nif.raw;

/** ErlNifResourceTypeInit: dtor/stop/down/dyncall callbacks (set from glue). */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifResourceTypeInit")
extern class ErlNifResourceTypeInit {
	var dtor:cpp.Star<cpp.Void>;
	var stop:cpp.Star<cpp.Void>;
	var down:cpp.Star<cpp.Void>;
	var members:Int;
	var dyncall:cpp.Star<cpp.Void>;

	@:native("ErlNifResourceTypeInit")
	static function make():ErlNifResourceTypeInit;
}
