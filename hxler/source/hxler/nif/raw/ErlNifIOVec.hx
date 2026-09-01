package hxler.nif.raw;

/** ErlNifIOVec (raw-only surface; iov is SysIOVec*). */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifIOVec")
extern class ErlNifIOVec {
	var iovcnt:Int;
	var size:cpp.UInt64;
	var iov:cpp.Star<cpp.Void>;

	@:native("ErlNifIOVec")
	static function make():ErlNifIOVec;
}
