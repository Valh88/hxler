package hxler.nif.raw;

/** ErlNifPid: {ERL_NIF_TERM pid;} */
@:stackOnly
@:structAccess
@:unreflective
@:native("ErlNifPid")
extern class ErlNifPid {
	var pid:NifTerm;

	@:native("ErlNifPid")
	static function make():ErlNifPid;
}
