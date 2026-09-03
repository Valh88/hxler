package hxler.core;

/**
 * Implemented by user types that know how to encode themselves into a term
 * (rustler Encoder analog). The @:nif macro (phase 4) uses it for
 * parameters/returns whose type implements this interface.
 */
interface Encoder {
	function encode(env:Env):Term;
}
