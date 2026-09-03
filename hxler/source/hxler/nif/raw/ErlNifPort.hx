package hxler.nif.raw;

/** ErlNifPort: {ERL_NIF_TERM port_id;} */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifPort")
extern class ErlNifPort {
	var port_id:NifTerm;

	@:native("ErlNifPort")
	static function make():ErlNifPort;
}
