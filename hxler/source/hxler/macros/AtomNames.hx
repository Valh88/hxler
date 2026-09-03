package hxler.macros;

/**
 * Atom-name -> Haxe-identifier mapping for AtomBuilder. Plain string logic
 * kept in a normal class so it is unit-testable at runtime.
 */
class AtomNames {
	/** Haxe reserved words that cannot be used as identifiers. */
	public static var KEYWORDS(default, never):Array<String> = [
		"abstract", "as", "break", "case", "cast", "catch", "class", "continue", "default", "do", "dynamic", "else",
		"enum", "extends", "extern", "false", "final", "for", "from", "function", "if", "implements", "import", "in",
		"inline", "interface", "is", "macro", "never", "new", "null", "operator", "overload", "override", "package",
		"private", "public", "return", "static", "switch", "this", "throw", "to", "trace", "true", "try", "typedef",
		"untyped", "using", "var", "while"
	];

	/**
	 * Maps an atom text to a valid Haxe identifier:
	 *  - non-alphanumeric chars become "_",
	 *  - a leading digit gets a "_" prefix,
	 *  - reserved keywords get a "_" suffix ("true" -> "true_"),
	 *  - the result is guaranteed non-empty ("_" -> "__"? -> "_" + "_").
	 */
	public static function identifier(atomName:String):String {
		var out = new StringBuf();
		for (i in 0...atomName.length) {
			var c = atomName.charAt(i);
			var isAlnum = (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_";
			out.add(isAlnum ? c : "_");
		}
		var id = out.toString();
		if (id.length == 0 || !isAlphaOrUnderscore(id.charAt(0))) {
			id = "_" + id;
		}
		if (Lambda.has(KEYWORDS, id)) {
			id = id + "_";
		}
		return id;
	}

	static function isAlphaOrUnderscore(c:String):Bool {
		return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_";
	}
}
