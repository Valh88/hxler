package my_nif;

import my_nif.Entry;

/**
 * Dummy main (DLL build needs a valid -main; the NIF entrypoint lives in
 * the generated glue of my_nif.Entry).
 */
@:keep
class Main {
	public static function main() {}
}
