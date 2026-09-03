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

/** C fn-pointer typedefs from erl_nif.h, so assignments type-check on MSVC. */
@:structAccess
@:include("erl_nif.h")
@:native("ErlNifResourceDtor")
extern class ErlNifResourceDtor {}

@:structAccess
@:include("erl_nif.h")
@:native("ErlNifResourceDown")
extern class ErlNifResourceDown {}
