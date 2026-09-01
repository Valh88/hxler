package hxler.core;

/**
 * Implemented by user types that know how to decode themselves from a term
 * (rustler Decoder analog).
 */
interface Decoder<T> {
	function decode(term:Term):NifResult<T>;
}
