package hxler.core;

/**
 * Result type of NIF function bodies: Ok(value) or Error(NifError).
 * The generated glue (phase 4) converts it into the NIF return value via
 * NifReturn.apply; Haxe exceptions escaping the body become :nif_panicked.
 */
enum NifResult<T> {
	Ok(value:T);
	Error(error:NifError);
}
