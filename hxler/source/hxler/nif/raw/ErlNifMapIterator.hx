package hxler.nif.raw;

/** ErlNifMapIterator: opaque internals; only iterated via enif_map_iterator_*. */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifMapIterator")
extern class ErlNifMapIterator {
	// the `u` union and internals are intentionally not declared
	var map:NifTerm;
	var size:NifTerm;
	var idx:NifTerm;

	@:native("ErlNifMapIterator")
	static function make():ErlNifMapIterator;
}
