package hxler.nif.raw;

/** ErlNifBinary: {size_t size; unsigned char* data; internals}. */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifBinary")
extern class ErlNifBinary {
	var size:cpp.UInt64;
	var data:cpp.Pointer<cpp.UInt8>;
	var ref_bin:cpp.Star<cpp.Void>;

	/** stack value-init constructor (ErlNifBinary()). */
	@:native("ErlNifBinary")
	static function make():ErlNifBinary;
}
