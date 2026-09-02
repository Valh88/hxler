package math;

/**
 * Haxe load callback for the math NIF: registers resource types.
 */
@:keep
class ResourceInit {
	public static function load(env:hxler.core.Env, _loadInfo:hxler.core.Term):Bool {
		var ok = env.registerResource(math.Accum);
		return ok;
	}
}
