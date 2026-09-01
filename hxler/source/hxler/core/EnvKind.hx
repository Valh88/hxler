package hxler.core;

/**
 * Kind of the ErlNifEnv wrapped by Env (rustler's EnvKind analog). The kind
 * documents the lifetime contract; Term objects always carry their Env so
 * cross-env misuse requires an explicit copy.
 */
enum abstract EnvKind(Int) {
	/** NIF-call env owned by BEAM: valid only during the call. */
	var ProcessBound = 0;
	/** env passed to load/unload/resource-callback entry points. */
	var Callback = 1;
	/** load-callback env (resource type registration allowed). */
	var Init = 2;
	/** env we allocated with enif_alloc_env: lives until explicitly freed. */
	var ProcessIndependent = 3;

	public function toString():String {
		var i:Int = this;
		return switch (i) {
			case 0: "ProcessBound";
			case 1: "Callback";
			case 2: "Init";
			case 3: "ProcessIndependent";
			default: "EnvKind(" + i + ")";
		};
	}
}


